import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:path_provider/path_provider.dart';
import 'package:ml_espresso_app/util/image_utils.dart';
import 'package:image/image.dart' as image_lib;

/// Helper class to track number candidates with confidence scores
class NumberCandidate {
  final double value;
  final double confidence;
  
  NumberCandidate(this.value, this.confidence);
}

class OcrService {
  static final TextRecognizer _textRecognizer = TextRecognizer();
  static bool _debugMode = false;
  static int _debugImageCounter = 0;
  
  /// Enable or disable debug mode for saving images
  static void setDebugMode(bool enabled) {
    _debugMode = enabled;
    if (enabled) {
      _debugImageCounter = 0;
      debugPrint('OCR Debug mode enabled');
    }
  }
  
  /// Extract numeric value from camera image
  /// Returns the weight in grams as a double, or null if no valid number found
  static Future<double?> extractWeightFromImage(CameraImage image) async {
    try {
      // Save debug image periodically when in debug mode
      if (_debugMode && _debugImageCounter % 30 == 0) { // Every 30 frames to avoid filling storage
        await _saveDebugImage(image, _debugImageCounter);
        debugPrint('🖼️ Frame ${_debugImageCounter}: size=${image.width}x${image.height}, format=${image.format.group}');
      }
      _debugImageCounter++;
      
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        debugPrint('❌ Failed to create InputImage');
        return null;
      }

      // Perform text recognition
      final stopwatch = Stopwatch()..start();
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      stopwatch.stop();
      
      // Debug: print all recognized text
      if (_debugMode) {
        debugPrint('⏱️  OCR took ${stopwatch.elapsedMilliseconds}ms');
        if (recognizedText.text.isNotEmpty) {
          debugPrint('📝 OCR detected text: "${recognizedText.text}"');
          debugPrint('   Text blocks: ${recognizedText.blocks.length}');
          for (var block in recognizedText.blocks) {
            for (var line in block.lines) {
              debugPrint('   Line: "${line.text}"');
            }
          }
        } else {
          debugPrint('⚠️ OCR detected NO text (image size: ${image.width}x${image.height})');
        }
      }
      
      // Extract numeric values from recognized text
      double? weight = _extractNumericValue(recognizedText);
      
      if (_debugMode && weight == null && recognizedText.text.isNotEmpty) {
        debugPrint('⚠️ Text detected but no valid weight extracted');
      }
      
      return weight;
    } catch (e) {
      debugPrint('❌ Error in OCR: $e');
      debugPrint('Stack: ${StackTrace.current}');
      return null;
    }
  }
  
  /// Save debug image for inspection
  static Future<void> _saveDebugImage(CameraImage cameraImage, int counter) async {
    try {
      // Convert camera image to image_lib.Image
      final image = await convertCameraImageToImage(cameraImage);
      if (image == null) {
        debugPrint('Failed to convert camera image for debug');
        return;
      }
      
      // Rotate for Android
      image_lib.Image rotatedImage = image;
      if (Platform.isAndroid) {
        rotatedImage = image_lib.copyRotate(image, angle: 90);
      }
      
      // Determine save location
      Directory directory;
      String folderName = 'MLEspresso';
      
      if (Platform.isAndroid) {
        // Try multiple possible paths for Android external storage
        List<String> possiblePaths = [
          '/storage/emulated/0/Pictures/$folderName',
          '/storage/emulated/0/DCIM/$folderName',
          '/sdcard/Pictures/$folderName',
          '/sdcard/DCIM/$folderName',
        ];
        
        Directory? workingDir;
        for (String path in possiblePaths) {
          try {
            final dir = Directory(path);
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
            // Test if we can write to this directory
            workingDir = dir;
            debugPrint('✅ Using directory: $path');
            break;
          } catch (e) {
            debugPrint('⚠️ Cannot use $path: $e');
            continue;
          }
        }
        
        if (workingDir == null) {
          // Fallback to app documents directory if external storage fails
          debugPrint('⚠️ External storage not accessible, using app documents directory');
          final docDir = await getApplicationDocumentsDirectory();
          workingDir = Directory('${docDir.path}/$folderName');
          if (!await workingDir.exists()) {
            await workingDir.create(recursive: true);
          }
        }
        
        directory = workingDir;
      } else {
        // Fallback to app documents directory for non-Android platforms
        final docDir = await getApplicationDocumentsDirectory();
        directory = Directory('${docDir.path}/$folderName');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
      }
      
      final path = directory.path;
      
      // Save the image with timestamp
      final timestamp = DateTime.now().toString().replaceAll(':', '-').replaceAll(' ', '_').substring(0, 19);
      final fileName = 'debug_ocr_${counter ~/ 30}_$timestamp';
      await saveImage(rotatedImage, path, fileName);
      
      debugPrint('✅ Debug image saved: $path/$fileName.jpg');
      
      // Provide user-friendly message based on where file was saved
      if (path.contains('/Pictures/') || path.contains('/DCIM/')) {
        debugPrint('📁 Check your Gallery app or Files → Pictures → MLEspresso');
      } else {
        debugPrint('📁 Saved to app directory. Path: $path');
      }
    } catch (e) {
      debugPrint('❌ Error saving debug image: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  /// Convert CameraImage to InputImage for ML Kit
  /// Process entirely in memory for better performance
  static InputImage? _inputImageFromCameraImage(CameraImage cameraImage) {
    try {
      // For YUV420 format on Android, we need to properly structure the data for ML Kit
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        if (_debugMode) {
          debugPrint('🔄 Converting YUV420 → NV21 for ML Kit');
        }
        
        // Extract plane data
        final yPlane = cameraImage.planes[0];
        final uPlane = cameraImage.planes[1];
        final vPlane = cameraImage.planes[2];
        
        final int width = cameraImage.width;
        final int height = cameraImage.height;
        
        if (_debugMode) {
          debugPrint('   Y plane: ${yPlane.bytes.length} bytes, stride: ${yPlane.bytesPerRow}');
          debugPrint('   U plane: ${uPlane.bytes.length} bytes, stride: ${uPlane.bytesPerRow}, pixelStride: ${uPlane.bytesPerPixel}');
          debugPrint('   V plane: ${vPlane.bytes.length} bytes, stride: ${vPlane.bytesPerRow}, pixelStride: ${vPlane.bytesPerPixel}');
        }
        
        // NV21 format: Y plane followed by interleaved VU plane
        // Y plane size: width * height
        // UV plane size: (width/2) * (height/2) * 2 = width * height / 2
        final int ySize = width * height;
        final int uvSize = width * height ~/ 2;
        
        final Uint8List nv21Bytes = Uint8List(ySize + uvSize);
        
        // Copy Y plane (might have padding, so copy row by row)
        int yDestIndex = 0;
        for (int row = 0; row < height; row++) {
          int ySourceIndex = row * yPlane.bytesPerRow;
          for (int col = 0; col < width; col++) {
            nv21Bytes[yDestIndex++] = yPlane.bytes[ySourceIndex + col];
          }
        }
        
        // Interleave V and U planes for NV21 (VUVUVU...)
        int uvDestIndex = ySize;
        final uvRowStride = uPlane.bytesPerRow;
        final uvPixelStride = uPlane.bytesPerPixel ?? 1;
        
        for (int row = 0; row < height ~/ 2; row++) {
          for (int col = 0; col < width ~/ 2; col++) {
            final uvIndex = row * uvRowStride + col * uvPixelStride;
            nv21Bytes[uvDestIndex++] = vPlane.bytes[uvIndex]; // V first
            nv21Bytes[uvDestIndex++] = uPlane.bytes[uvIndex]; // then U
          }
        }
        
        final InputImageRotation rotation = Platform.isAndroid
            ? InputImageRotation.rotation90deg
            : InputImageRotation.rotation0deg;
        
        final metadata = InputImageMetadata(
          size: Size(width.toDouble(), height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: width, // NV21 has no padding
        );
        
        if (_debugMode) {
          debugPrint('   ✅ Created NV21: ${nv21Bytes.length} bytes (expected: ${ySize + uvSize})');
          debugPrint('   Rotation: $rotation');
        }
        
        return InputImage.fromBytes(bytes: nv21Bytes, metadata: metadata);
      }
      
      // Fallback for other formats - shouldn't normally reach here
      debugPrint('❌ Unsupported camera image format: ${cameraImage.format.group}');
      return null;
    } catch (e) {
      debugPrint('❌ Error converting camera image for OCR: $e');
      debugPrint('Stack: ${StackTrace.current}');
      return null;
    }
  }

  /// Extract numeric value from recognized text
  /// Looks for patterns like "123.45" or "12.3" that represent weight in grams
  /// Optimized for espresso scale displays (typically 0-60g range)
  static double? _extractNumericValue(RecognizedText recognizedText) {
    // More permissive regular expression to match decimal numbers
    final RegExp numberPattern = RegExp(r'(\d+\.?\d*)');
    
    List<NumberCandidate> candidates = [];
    
    // Search through all text blocks
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String text = line.text.trim();
        
        if (_debugMode) {
          debugPrint('   Analyzing line: "$text"');
        }
        
        // Find all numbers in the line
        Iterable<Match> matches = numberPattern.allMatches(text);
        for (Match match in matches) {
          String? numberStr = match.group(1);
          if (numberStr != null && numberStr.isNotEmpty) {
            double? number = double.tryParse(numberStr);
            if (number != null) {
              // Allow 0-1000g to accommodate untared scales
              // (portafilter + coffee can be 200-500g)
              if (number >= 0.0 && number <= 1000.0) {
                // Calculate confidence score based on position and format
                double confidence = _calculateConfidence(number, text, line);
                candidates.add(NumberCandidate(number, confidence));
                
                if (_debugMode) {
                  debugPrint('      Found number: $number (confidence: ${confidence.toStringAsFixed(2)})');
                }
              } else if (_debugMode && number > 1000.0) {
                debugPrint('      Rejected: $number (out of reasonable range 0-1000g)');
              }
            }
          }
        }
      }
    }
    
    if (candidates.isEmpty) {
      if (_debugMode) {
        debugPrint('   No valid number candidates found');
      }
      return null;
    }
    
    // Sort by confidence and return the best candidate
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    double bestValue = candidates.first.value;
    
    // Post-process: Handle missing decimal points
    // If we detect a 3-digit whole number (100-999), it might be missing decimal
    // Example: "234" might actually be "23.4" for an espresso scale
    if (bestValue >= 100.0 && bestValue <= 999.0 && bestValue % 1 == 0) {
      // Check if dividing by 10 would make more sense
      double withDecimal = bestValue / 10.0;
      
      // If the decimal version is in tared espresso range (0-100g), prefer it
      if (withDecimal >= 0.0 && withDecimal <= 100.0) {
        if (_debugMode) {
          debugPrint('   🔧 Corrected missing decimal: $bestValue → $withDecimal');
        }
        bestValue = withDecimal;
      }
    }
    
    if (_debugMode) {
      debugPrint('   ✅ Best candidate: ${bestValue}g (confidence: ${candidates.first.confidence.toStringAsFixed(2)})');
      if (candidates.length > 1) {
        debugPrint('   Other candidates: ${candidates.skip(1).take(3).map((c) => '${c.value}g(${c.confidence.toStringAsFixed(1)})').join(', ')}');
      }
    }
    
    return bestValue;
  }
  
  /// Calculate confidence score for a number candidate
  /// Higher scores for numbers that look like scale displays
  static double _calculateConfidence(double number, String lineText, TextLine line) {
    double confidence = 1.0;
    
    // Strongly prefer numbers with one decimal place (typical for scales)
    String numStr = number.toString();
    if (numStr.contains('.')) {
      int decimalPlaces = numStr.split('.')[1].length;
      if (decimalPlaces == 1) {
        confidence += 3.0; // STRONG preference for X.X format (OCR found decimal!)
      } else if (decimalPlaces == 2) {
        confidence += 2.0; // Also good for X.XX format
      }
    } else {
      confidence += 0.3; // Whole numbers less common (might be missing decimal)
    }
    
    // Prefer numbers in reasonable ranges
    // Typical espresso: 10-40g (tared)
    // Untared with portafilter: 200-500g
    if (number >= 10.0 && number <= 40.0) {
      confidence += 1.5; // Tared espresso range
    } else if ((number >= 0.0 && number <= 100.0) || (number >= 200.0 && number <= 600.0)) {
      confidence += 0.5; // Also reasonable
    }
    
    // Prefer cleaner text (fewer extra characters)
    int extraChars = lineText.replaceAll(RegExp(r'[\d.]'), '').length;
    if (extraChars == 0) {
      confidence += 1.0; // Pure number
    } else if (extraChars <= 2) {
      confidence += 0.5; // Mostly clean
    }
    
    // Prefer numbers that appear isolated (surrounded by whitespace or units like 'g')
    if (RegExp(r'^\d+\.?\d*\s*g?$').hasMatch(lineText.trim())) {
      confidence += 1.5; // Looks like "23.4" or "23.4g"
    }
    
    return confidence;
  }

  /// Clean up resources
  static Future<void> dispose() async {
    await _textRecognizer.close();
  }
}

