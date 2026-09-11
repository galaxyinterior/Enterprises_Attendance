import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class MLService {
  // Singleton pattern to prevent massive RAM leaks by reloading the model
  MLService._privateConstructor();
  static final MLService _instance = MLService._privateConstructor();
  factory MLService() => _instance;

  Interpreter? _interpreter;
  bool _isInitialized = false;
  bool _isInferenceRunning = false;

  // The size expected by MobileFaceNet
  static const int inputSize = 112;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset('assets/mobile_facenet.tflite', options: options);
      _isInitialized = true;
      debugPrint("[MLService] TFLite Model Loaded Successfully.");
    } catch (e) {
      debugPrint("[MLService] Failed to load TFLite model: $e");
    }
  }

  /// Convert a 112x112 resized image directly into a flat Float32List normalized for MobileFaceNet
  static Float32List imageToFloat32Buffer(img.Image resizedImage) {
    final buffer = Float32List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        buffer[pixelIndex++] = (pixel.r - 127.5) / 128.0;
        buffer[pixelIndex++] = (pixel.g - 127.5) / 128.0;
        buffer[pixelIndex++] = (pixel.b - 127.5) / 128.0;
      }
    }
    return buffer;
  }

  /// Extracts face embedding directly from an in-memory pre-cropped and resized face image (112x112).
  /// This bypasses all disk I/O, isolate message-passing, and nested list allocations.
  Future<List<double>?> getEmbeddingFromFaceCrop(img.Image faceCrop) async {
    if (!_isInitialized || _interpreter == null) {
      await initialize();
      if (_interpreter == null) return null;
    }

    if (_isInferenceRunning) return null;
    _isInferenceRunning = true;

    try {
      final img.Image resized = (faceCrop.width == inputSize && faceCrop.height == inputSize)
          ? faceCrop
          : img.copyResize(faceCrop, width: inputSize, height: inputSize);

      final Float32List floatBuffer = imageToFloat32Buffer(resized);
      final reshapedInput = floatBuffer.reshape([1, inputSize, inputSize, 3]);

      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final int outputLength = outputShape[1];
      final output = List.generate(1, (_) => List.filled(outputLength, 0.0));

      _interpreter!.run(reshapedInput, output);
      return List<double>.from(output[0]);
    } catch (e) {
      debugPrint("[MLService] Error extracting embedding from crop: $e");
      return null;
    } finally {
      _isInferenceRunning = false;
    }
  }

  /// Extracts face embedding from an in-memory decoded image and bounding box.
  Future<List<double>?> getEmbeddingFromImage(img.Image decodedImage, Map<String, dynamic> boundingBox) async {
    final int x = (boundingBox['x'] as num).toInt();
    final int y = (boundingBox['y'] as num).toInt();
    final int w = (boundingBox['width'] as num).toInt();
    final int h = (boundingBox['height'] as num).toInt();

    final img.Image faceCrop = img.copyCrop(
      decodedImage,
      x: max(0, x),
      y: max(0, y),
      width: min(w, decodedImage.width - max(0, x)),
      height: min(h, decodedImage.height - max(0, y)),
    );

    return getEmbeddingFromFaceCrop(faceCrop);
  }

  /// Legacy/Fallback: Extracts face embedding from an image file (used by FaceDataScreen).
  Future<List<double>?> getEmbedding(File imageFile, Map<String, dynamic> boundingBox) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return null;
      return getEmbeddingFromImage(decodedImage, boundingBox);
    } catch (e) {
      debugPrint("[MLService] Error in getEmbedding from file: $e");
      return null;
    }
  }

  /// Calculates Euclidean distance between two embeddings
  double calculateEuclideanDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 999.0;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      final double diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _isInferenceRunning = false;
  }
}
