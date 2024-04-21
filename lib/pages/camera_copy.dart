import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ml_espresso_app/util/model.dart';
import 'package:ml_espresso_app/util/box_ui.dart';



class CameraPage extends StatefulWidget {
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late List<CameraDescription> cameras;
  bool isCamerasInitialized = false;
  List<Rect> _detectedBoxes = [];

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    // Load the model before initializing the camera
    await loadModel();  // Ensure this is awaited
    
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
        _controller.startImageStream((CameraImage image) async {
          // Process each camera frame
          List<Rect> detectedTextRectangles = await detectText(image);
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
        CustomPaint(
          size: Size.infinite, // Use this to cover the camera preview
          painter: CustomBoxPainter(_detectedBoxes), // Pass the list of boxes here
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