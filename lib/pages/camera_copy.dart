import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPageNew extends StatefulWidget {
  @override
  State<CameraPageNew> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPageNew> {
  late CameraController _controller;
  late List<CameraDescription> cameras;
  bool isCamerasInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    cameras = await availableCameras();
    setState(() {
      isCamerasInitialized = true;
      _controller = CameraController(cameras[0], ResolutionPreset.max); // Initialize the controller here
    });
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
    });
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
      body: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: CameraPreview(_controller),
          )
      ]),
    );
  }
}