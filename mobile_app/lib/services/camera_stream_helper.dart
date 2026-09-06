import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class CameraStreamHelper {
  /// Converts CameraImage into InputImage for Google ML Kit face detection
  static InputImage? inputImageFromCameraImage({
    required CameraImage image,
    required CameraDescription camera,
  }) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Check if planes are available
    if (image.planes.isEmpty) return null;

    // Android YUV_420_888 plane concatenation
    if (Platform.isAndroid) {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    } else {
      // iOS / macOS / other BGRA
      return InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );
    }
  }

  /// Converts Android YUV420 CameraImage to an in-memory img.Image and rotates it to match sensor orientation
  static img.Image convertYuv420ToRotatedImage(CameraImage cameraImage, int sensorOrientation) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final int uvRowStride = uPlane.bytesPerRow;
    final int uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final img.Image rgbImage = img.Image(width: width, height: height);

    for (int h = 0; h < height; h++) {
      final int yRowOffset = h * width;
      final int uvRowOffset = (h >> 1) * uvRowStride;
      for (int w = 0; w < width; w++) {
        final int y = yPlane.bytes[yRowOffset + w];
        final int uvIndex = uvRowOffset + ((w >> 1) * uvPixelStride);
        final int u = uPlane.bytes[uvIndex];
        final int v = vPlane.bytes[uvIndex];

        // Standard YUV to RGB integer conversion
        final int r = (y + 1.402 * (v - 128)).toInt().clamp(0, 255);
        final int g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128)).toInt().clamp(0, 255);
        final int b = (y + 1.772 * (u - 128)).toInt().clamp(0, 255);

        rgbImage.setPixelRgb(w, h, r, g, b);
      }
    }

    if (sensorOrientation == 90) {
      return img.copyRotate(rgbImage, angle: 90);
    } else if (sensorOrientation == 180) {
      return img.copyRotate(rgbImage, angle: 180);
    } else if (sensorOrientation == 270) {
      return img.copyRotate(rgbImage, angle: 270);
    }

    return rgbImage;
  }
}
