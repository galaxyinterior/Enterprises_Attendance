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

  // The size expected by MobileFaceNet
  static const int inputSize = 112;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final options = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset('assets/mobile_facenet.tflite', options: options);
      _isInitialized = true;
      debugPrint("TFLite Model Loaded Successfully.");
    } catch (e) {
      debugPrint("Failed to load TFLite model: $e");
    }
  }

  static List<List<List<List<double>>>>? _preprocessImage(Map<String, dynamic> args) {
    final bytes = args['bytes'] as List<int>;
    final boundingBox = args['bbox'] as Map<String, dynamic>;
    final inputSize = args['inputSize'] as int;

    img.Image? decodedImage = img.decodeImage(bytes as Uint8List);
    if (decodedImage == null) return null;

    final int x = boundingBox['x'].toInt();
    final int y = boundingBox['y'].toInt();
    final int w = boundingBox['width'].toInt();
    final int h = boundingBox['height'].toInt();

    img.Image faceCrop = img.copyCrop(
      decodedImage,
      x: max(0, x),
      y: max(0, y),
      width: min(w, decodedImage.width - x),
      height: min(h, decodedImage.height - y),
    );

    img.Image resizedImage = img.copyResize(faceCrop, width: inputSize, height: inputSize);

    return List.generate(
      1,
      (i) => List.generate(
        inputSize,
        (y) => List.generate(
          inputSize,
          (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              (pixel.r - 127.5) / 128.0,
              (pixel.g - 127.5) / 128.0,
              (pixel.b - 127.5) / 128.0,
            ];
          },
        ),
      ),
    );
  }

  /// Extracts face embedding from a pre-cropped image
  Future<List<double>?> getEmbedding(File imageFile, Map<String, dynamic> boundingBox) async {
    if (!_isInitialized || _interpreter == null) {
      debugPrint("Model not initialized");
      return null;
    }

    try {
      final bytes = await imageFile.readAsBytes();
      
      final input = await compute(_preprocessImage, {
        'bytes': bytes,
        'bbox': boundingBox,
        'inputSize': inputSize,
      });

      if (input == null) return null;

      var outputShape = _interpreter!.getOutputTensor(0).shape;
      int outputLength = outputShape[1];
      var output = List.generate(1, (i) => List.filled(outputLength, 0.0));

      _interpreter!.run(input, output);
      return output[0];
    } catch (e) {
      debugPrint("Error extracting embedding: $e");
      return null;
    }
  }

  /// Calculates Euclidean distance between two embeddings
  double calculateEuclideanDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 999.0;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      double diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
