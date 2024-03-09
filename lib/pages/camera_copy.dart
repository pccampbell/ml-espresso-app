import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:isolate';

class CameraPage extends StatefulWidget {
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late List<CameraDescription> cameras;
  bool isCamerasInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
    _loadModel();
  }

  Future<void> _initializeCameras() async {
    cameras = await availableCameras();
    setState(() {
      isCamerasInitialized = true;
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
    });
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  Future<void> _loadModel() async {
    // Load your TFLite model here
    // String res = await Tflite.loadModel(
    //   model: 'assets/model.tflite',
    //   labels: 'assets/labels.txt',
    // );
  }

 void _startStopImageStream() {
    if (isCamerasInitialized) {
      if (_controller.value.isStreamingImages) {
        _controller.stopImageStream().then((_) {
          // Ensure the button state is updated to reflect the stream has stopped
          if (mounted) {
            setState(() {});
          }
        });
      } else {
        _controller.startImageStream((CameraImage image) {
          // This is where you would process the image with your TFLite model
          // For now, we're simulating a non-blocking operation
          print("Processing image stream...");
        }).then((_) {
          // Ensure the UI is updated to reflect the stream has started
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }

  // Future<void> _runModel(CameraImage image) async {
  //   // Convert CameraImage to a format your model expects, typically Uint8List
  //   // This is a placeholder function, implement according to your model's need
  //   var modelInput = _convertCameraImageToModelInput(image);

  //   // Run your TFLite model here asynchronously
  //   // var recognitionResults = await Tflite.runModelOnBinary(binary: modelInput);
  // }

  Uint8List _convertCameraImageToModelInput(CameraImage image) {
    // Conversion logic here
    // This is highly dependent on your model's input requirements
    return Uint8List(0); // Placeholder, implement your conversion logic
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isCamerasInitialized || !_controller.value.isInitialized) {
      return Container();
    }
    return Scaffold(
      body: Stack(children: [
        LayoutBuilder(
          builder: (context, constraints) {
            // Maintain the aspect ratio of camera preview
            double aspectRatio = constraints.maxWidth / constraints.maxHeight;
            return AspectRatio(
              aspectRatio: aspectRatio,
              child: CameraPreview(_controller),
            );
          },
        ),
        Positioned(
          bottom: 10.0,
          left: 80.0,
          right: 80.0,
          child: ElevatedButton(
            onPressed: _startStopImageStream,
            child: Text(_controller.value.isStreamingImages ? 'Stop Image Stream' : 'Start Image Stream'),
          ),
        ),
        if (_controller.value.isStreamingImages)
          Center(
            child: Text(
              'Processing Image Stream...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
      ]),
    );
  }
}