import 'dart:ui';
import 'dart:typed_data';
import 'package:image/image.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:camera/camera.dart';
// import 'package:image/image.dart' as image_lib;
import 'package:ml_espresso_app/util/image_utils.dart';

Interpreter? _interpreter;
IsolateInterpreter? _isolateInterpreter;

Future<void> loadModel() async {
  // Load the model and create the interpreter
  _interpreter = await Interpreter.fromAsset('assets/lite-model_east-text-detector_fp16_1.tflite');

  // Create an IsolateInterpreter from the main interpreter's address
  if (_interpreter != null) {
    _isolateInterpreter = await IsolateInterpreter.create(address: _interpreter!.address);
  }
}

// Function to convert an image to a Uint8List with a specified channel order
Float32List prepareImageForModel(Image image) {
  int inputSize = 320; // Example size, adjust according to your model
  Image resizedImg = copyResize(image, width: inputSize, height: inputSize);

  // Get the bytes of the image with the specified channel order
  // Uint8List imageBytes = resizedImg.toUint8List();
  Uint8List imageBytes = resizedImg.getBytes(order: ChannelOrder.rgba);

  // Prepare the buffer for the Float32List conversion
  int numPixels = inputSize * inputSize;
  var buffer = Float32List(numPixels * 3); // 3 channels for RGB
  var imgBuffer = imageBytes.buffer.asUint8List();

  // Assuming the image is in RGBA format, skip the alpha channel
  for (int i = 0, j = 0; i < imgBuffer.length; i += 4, j += 3) {
    buffer[j] = (imgBuffer[i] / 255.0); // Red
    buffer[j + 1] = (imgBuffer[i + 1] / 255.0); // Green
    buffer[j + 2] = (imgBuffer[i + 2] / 255.0); // Blue
  }

  return buffer;
}

List<Rect> parseBoundingBoxes(Float32List boundingBoxes, Float32List scores, int numCells, int elementsPerBox, double threshold) {
  // const int numGridCells = 80; // From the model output dimension
  // const int elementsPerBox = 5; // x, y, width, height, and confidence
  // List<Rect> boxes = [];
  // for (int y = 0; y < numGridCells; y++) {
  //   for (int x = 0; x < numGridCells; x++) {
  //     int idx = (y * numGridCells + x) * elementsPerBox;
      
  //     // Normalize coordinates and size by the grid size and image size
  //     double cx = (boundingBoxes[idx] / numGridCells) * width;
  //     double cy = (boundingBoxes[idx + 1] / numGridCells) * height;
  //     double w = (boundingBoxes[idx + 2] / numGridCells) * width;
  //     double h = (boundingBoxes[idx + 3] / numGridCells) * height;

  //     // The fifth element is typically used for the confidence score
  //     double score = scores[idx + 4];

  //     // Filter out low confidence detections
  //     if (score > 0.5) { // Threshold can be adjusted
  //       // Create a rectangle from the bounding box
  //       boxes.add(Rect.fromLTWH(cx - w / 2, cy - h / 2, w, h));
  //     }
  //   }
  // }

  List<Rect> boxes = [];
  for (int i = 0; i < numCells; i++) {
      for (int j = 0; j < numCells; j++) {
          int index = (i * numCells + j) * elementsPerBox;
          double score = scores[index + 4]; // Assuming score is the fifth element
          if (score > threshold) {
              double x = boundingBoxes[index];
              double y = boundingBoxes[index + 1];
              double width = boundingBoxes[index + 2];
              double height = boundingBoxes[index + 3];
              Rect box = Rect.fromLTWH(x, y, width, height);
              boxes.add(box);
              print("Box at [$i, $j]: ${box.toString()} with score: $score");
          }
      }
  }

  return boxes;
}

void printTensorData(Float32List tensor, int depth, int height, int width, int channels) {
    for (int d = 0; d < depth; d++) {
        print("Depth $d:");
        for (int h = 0; h < height; h++) {
            for (int w = 0; w < width; w++) {
                int index = d * height * width * channels + h * width * channels + w * channels;
                List<double> values = List.generate(channels, (i) => tensor[index + i]);
                print("[$h, $w]: ${values.join(", ")}");
            }
        }
    }
}

Future<List<Rect>> detectText(CameraImage cameraImage) async {
  // Preprocessing the camera image
  Image? image = await convertCameraImageToImage(cameraImage);

  // Converting image for model input
  Float32List inputTensor = prepareImageForModel(image!);

   // Assuming the interpreter is correctly initialized
  var outputBoundingBoxes = Float32List(1 * 80 * 80 * 5); // Placeholder for bounding boxes
  var outputScores = Float32List(1 * 80 * 80 * 5); // Placeholder for scores

  // Prepare inputs and outputs for the model
  List<Object> inputs = [inputTensor.buffer.asFloat32List()];
    Map<int, Object> outputs = {
    0: outputBoundingBoxes,
    1: outputScores
  };

  // Run inference
  _isolateInterpreter?.runForMultipleInputs(inputs, outputs);

  // printTensorData(outputBoundingBoxes, 1, 80, 80, 5);  // Print bounding boxes
  // printTensorData(outputScores, 1, 80, 80, 5);   

  // Parse outputs to create a list of bounding boxes
  List<Rect> boxes = parseBoundingBoxes(outputBoundingBoxes, outputScores, 80, 5, 0.1);

  return boxes;
}



//   // Running the model inference
//   List<dynamic> output =
//       List.filled(1 * 4, 0).reshape([1, 4]); // Example output size
//   _interpreter?.run(input, output);

//   // Converting output to Rect
//   List<Rect> boxes = output.map((result) {
//     return Rect.fromLTWH(result[0], result[1], result[2], result[3]);
//   }).toList();

//   return boxes;
// }