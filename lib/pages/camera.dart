import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class CameraPage extends StatefulWidget {
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late List<CameraDescription> cameras;
  bool isCamerasInitialized = false;
  bool isRecording = false; // To track if video recording is in progress

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    cameras = await availableCameras();
    setState(() {
      isCamerasInitialized = true;
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.jpeg,
      ); // Initialize the controller here
    });
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  void _startStopImageStream() {
    print("button pressed");
    // if (isCamerasInitialized) {
    //   if (_controller.value.isStreamingImages) {
    //     _controller.stopImageStream();
    //   } else {
    //     _controller.startImageStream((CameraImage image) {
    //       // Process the camera frame with your TFLite model here
    //       _runModel(image);
    //     });
    //   }
    // }
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
            double aspectRatio = constraints.maxWidth / constraints.maxHeight;
            return AspectRatio(
              aspectRatio: aspectRatio,
              child: CameraPreview(_controller),
            );
          },
        ),
        Positioned(
          bottom: 20.0,
          left: 20.0,
          right: 20.0,
          child: ElevatedButton(
            onPressed: _startStopImageStream,
            child: Text(_controller.value.isStreamingImages ? 'Stop Image Stream' : 'Start Image Stream'),
        ),
        ),
      ]),
    );
  }
}
