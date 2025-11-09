import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as image_lib;

Future<image_lib.Image?> convertCameraImageToImage(
    CameraImage cameraImage) async {
  image_lib.Image image;

  if (cameraImage.format.group == ImageFormatGroup.yuv420) {
    print('converting from yuv420');
    image = convertYUV420ToImage(cameraImage);
  } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
    image = convertBGRA8888ToImage(cameraImage);
  } else if (cameraImage.format.group == ImageFormatGroup.jpeg) {
    image = convertJPEGToImage(cameraImage);
  } else if (cameraImage.format.group == ImageFormatGroup.nv21) {
    image = convertNV21ToImage(cameraImage);
  } else {
    print("error in convert image no format detecetd");
    return null;
  }

  return image;
}

image_lib.Image convertYUV420ToImage(CameraImage cameraImage) {
  final width = cameraImage.width;
  final height = cameraImage.height;

  final yPlane = cameraImage.planes[0].bytes;
  final uPlane = cameraImage.planes[1].bytes;
  final vPlane = cameraImage.planes[2].bytes;
  
  final uvRowStride = cameraImage.planes[1].bytesPerRow;
  final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;
  final yRowStride = cameraImage.planes[0].bytesPerRow;

  final image = image_lib.Image(width: width, height: height);

  for (var h = 0; h < height; h++) {
    for (var w = 0; w < width; w++) {
      // Y plane - straightforward indexing with row stride
      final yIndex = h * yRowStride + w;
      final yValue = yPlane[yIndex];
      
      // UV planes are subsampled by 2 in both dimensions (4:2:0)
      final uvRow = h ~/ 2;
      final uvCol = w ~/ 2;
      final uvIndex = uvRow * uvRowStride + uvCol * uvPixelStride;

      final uValue = uPlane[uvIndex];
      final vValue = vPlane[uvIndex];

      // Convert YUV to RGB using ITU-R BT.601 conversion
      final y = yValue.toDouble();
      final u = uValue.toDouble() - 128.0;
      final v = vValue.toDouble() - 128.0;
      
      final r = (y + 1.402 * v).clamp(0, 255);
      final g = (y - 0.344136 * u - 0.714136 * v).clamp(0, 255);
      final b = (y + 1.772 * u).clamp(0, 255);

      image.setPixelRgba(w, h, r.toInt(), g.toInt(), b.toInt(), 255);
    }
  }
  return image;
}

// image_lib.Image convertYUV420ToImage(CameraImage cameraImage) {
//   final width = cameraImage.width;
//   final height = cameraImage.height;

//   final uvRowStride = cameraImage.planes[1].bytesPerRow;
//   final uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

//   final yPlane = cameraImage.planes[0].bytes;
//   final uPlane = cameraImage.planes[1].bytes;
//   final vPlane = cameraImage.planes[2].bytes;

//   var image = image_lib.Image(width: width, height: height);  // Create an empty image buffer with specified dimensions

//   // Correctly calculate UV plane starting indices for each row
//   for (var y = 0; y < height; y++) {
//     final yIndex = y * width;
//     final uvIndex = (y ~/ 2) * uvRowStride;  // UV rows are half as frequent as Y rows

//     for (var x = 0; x < width; x++) {
//       final uvOffset = (x ~/ 2) * uvPixelStride;  // UV columns are half as frequent as Y columns

//       final yValue = yPlane[yIndex + x] & 0xFF;
//       final uValue = uPlane[uvIndex + uvOffset] & 0xFF;
//       final vValue = vPlane[uvIndex + uvOffset] & 0xFF;

//       // Convert YUV to RGB
//       var r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
//       var g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
//       var b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

//       image.setPixelRgba(x, y, r, g, b, 255);
//     }
//   }
//   return image;
// }

image_lib.Image convertBGRA8888ToImage(CameraImage cameraImage) {
  // Extract the bytes from the CameraImage
  final bytes = cameraImage.planes[0].bytes;

  // Create a new Image instance
  final image = image_lib.Image.fromBytes(
    width: cameraImage.width,
    height: cameraImage.height,
    bytes: bytes.buffer,
    order: image_lib.ChannelOrder.rgba,
  );

  return image;
}

image_lib.Image convertJPEGToImage(CameraImage cameraImage) {
  // Extract the bytes from the CameraImage
  final bytes = cameraImage.planes[0].bytes;

  // Create a new Image instance from the JPEG bytes
  final image = image_lib.decodeImage(bytes);

  return image!;
}

image_lib.Image convertNV21ToImage(CameraImage cameraImage) {
  // Extract the bytes from the CameraImage
  final yuvBytes = cameraImage.planes[0].bytes;
  final vuBytes = cameraImage.planes[1].bytes;

  // Create a new Image instance
  final image = image_lib.Image(
    width: cameraImage.width,
    height: cameraImage.height,
  );

  // Convert NV21 to RGB
  convertNV21ToRGB(
    yuvBytes,
    vuBytes,
    cameraImage.width,
    cameraImage.height,
    image,
  );

  return image;
}

void convertNV21ToRGB(Uint8List yuvBytes, Uint8List vuBytes, int width,
    int height, image_lib.Image image) {
  // Conversion logic from NV21 to RGB
  // ...

  // Example conversion logic using the `imageLib` package
  // This is just a placeholder and may not be the most efficient method
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final yIndex = y * width + x;
      final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

      final yValue = yuvBytes[yIndex];
      final uValue = vuBytes[uvIndex * 2];
      final vValue = vuBytes[uvIndex * 2 + 1];

      // Convert YUV to RGB
      final r = yValue + 1.402 * (vValue - 128);
      final g = yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128);
      final b = yValue + 1.772 * (uValue - 128);

      // Set the RGB pixel values in the Image instance
      image.setPixelRgba(x, y, r.toInt(), g.toInt(), b.toInt(), 255);
    }
  }
}

/// ROTATION changes - not working as need to be from the Exif (which is empty)

Future<int> getExifRotation(CameraImage cameraImage) async {
  final exifData = await readExifFromBytes(cameraImage.planes[0].bytes);
  final ifd = exifData['Image Orientation'];

  if (ifd != null) {
    return ifd.values.toList()[0];
  }
  return 1;
}

image_lib.Image applyExifRotation(image_lib.Image image, int exifRotation) {
  if (exifRotation == 1) {
    return image_lib.copyRotate(image, angle: 0);
  } else if (exifRotation == 3) {
    return image_lib.copyRotate(image, angle: 180);
  } else if (exifRotation == 6) {
    return image_lib.copyRotate(image, angle: 90);
  } else if (exifRotation == 8) {
    return image_lib.copyRotate(image, angle: 270);
  }

  return image;
}

Future<void> saveImage(
  image_lib.Image image,
  String path,
  String name,
) async {
  Uint8List bytes = image_lib.encodeJpg(image);
  final fileOnDevice = File('$path/$name.jpg');
  await fileOnDevice.writeAsBytes(bytes, flush: true);
}
