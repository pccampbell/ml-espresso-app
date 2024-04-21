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
        ResolutionPreset.low,
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
        int frameSkipCount = 0;
        _controller.startImageStream((CameraImage image) async {
          frameSkipCount++;
          if (frameSkipCount >= 5) { // Skip every 4 frames
            final stopwatch = Stopwatch()..start();
            List<Rect> detectedTextRectangles = await detectText(image);
            stopwatch.stop();  // Stop the stopwatch after inference is done
            print("Inference took: ${stopwatch.elapsedMilliseconds} ms");
            
            // Update the state with new boxes to trigger a repaint
            setState(() {
              _detectedBoxes = detectedTextRectangles;
            });
            
            frameSkipCount = 0;
          }
          // // Process each camera frame
          // List<Rect> detectedTextRectangles = await detectText(image);
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

    final size = MediaQuery.of(context).size;  // Get the screen size
    final camera = _controller.value;
    final scale = size.aspectRatio * camera.aspectRatio;

    // To ensure the aspect ratio is preserved
    final width = scale < 1 ? size.width : size.height * camera.aspectRatio;
    final height = scale < 1 ? size.width / camera.aspectRatio : size.height;

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
          // size: Size.infinite, // Use this to cover the camera preview
          size: Size(width, height),
          painter: OverlayPainter(_detectedBoxes, Size(camera.previewSize!.width, camera.previewSize!.height), Size(width, height)),
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