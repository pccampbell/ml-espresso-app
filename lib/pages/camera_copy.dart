import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ml_espresso_app/util/ocr_service.dart';
import 'package:ml_espresso_app/models/weight_reading.dart';
import 'package:ml_espresso_app/widgets/weight_chart.dart';

class CameraPage extends StatefulWidget {
  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late CameraController _controller;
  late List<CameraDescription> cameras;
  bool isCamerasInitialized = false;
  
  // OCR and data tracking
  double? _currentWeight;
  ExtractionSession? _currentSession;
  bool _isRecording = false;
  String _statusMessage = 'Ready';

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
        ResolutionPreset.medium,
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

  void _startStopRecording() {
    if (isCamerasInitialized) {
      if (_isRecording) {
        _stopRecording();
      } else {
        _startRecording();
      }
    }
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _currentSession = ExtractionSession(startTime: DateTime.now());
      _statusMessage = 'Recording...';
    });

    int frameSkipCount = 0;
    _controller.startImageStream((CameraImage image) async {
      frameSkipCount++;
      if (frameSkipCount >= 10) { // Process every 10th frame (~3 fps)
        frameSkipCount = 0;
        
        if (!_isRecording) return;
        
        try {
          final stopwatch = Stopwatch()..start();
          double? weight = await OcrService.extractWeightFromImage(image);
          stopwatch.stop();
          
          if (weight != null && mounted) {
            setState(() {
              _currentWeight = weight;
              _currentSession?.addReading(weight);
              _statusMessage = 'OCR: ${stopwatch.elapsedMilliseconds}ms';
            });
            print('Weight detected: ${weight}g (${stopwatch.elapsedMilliseconds}ms)');
          }
        } catch (e) {
          print('Error processing frame: $e');
        }
      }
    });
  }

  void _stopRecording() {
    if (_controller.value.isStreamingImages) {
      _controller.stopImageStream();
    }
    
    setState(() {
      _isRecording = false;
      _currentSession?.endSession();
      _statusMessage = 'Stopped';
    });
  }

  void _resetSession() {
    setState(() {
      _currentSession = null;
      _currentWeight = null;
      _statusMessage = 'Ready';
    });
  }

  @override
  void dispose() {
    if (_controller.value.isStreamingImages) {
      _controller.stopImageStream();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isCamerasInitialized || !_controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Column(
        children: [
          // Camera preview section (top half)
          Expanded(
            flex: 1,
            child: Stack(
              children: [
                // Camera preview
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: CameraPreview(_controller),
                  ),
                ),
                // Current weight overlay
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _currentWeight != null
                              ? '${_currentWeight!.toStringAsFixed(1)} g'
                              : '--.-',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Chart section (bottom half)
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[900],
              child: _currentSession != null && _currentSession!.readings.isNotEmpty
                  ? WeightChart(session: _currentSession!)
                  : const Center(
                      child: Text(
                        'Start recording to see the chart',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ),
            ),
          ),
          
          // Control buttons at the bottom
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[850],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _startStopRecording,
                  icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                  label: Text(_isRecording ? 'Stop' : 'Start'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isRecording ? null : _resetSession,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
