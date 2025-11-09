import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:ml_espresso_app/util/ocr_service.dart';
import 'package:ml_espresso_app/models/weight_reading.dart';
import 'package:ml_espresso_app/widgets/weight_chart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ml_espresso_app/services/session_storage.dart';
import 'dart:io';

class CameraPageMain extends StatefulWidget {
  @override
  State<CameraPageMain> createState() => _CameraPageMainState();
}

class _CameraPageMainState extends State<CameraPageMain> with WidgetsBindingObserver {
  late CameraController _controller;
  late List<CameraDescription> cameras;
  bool isCamerasInitialized = false;
  
  // OCR and data tracking
  double? _currentWeight;
  ExtractionSession? _currentSession;
  bool _isRecording = false;
  String _statusMessage = 'Ready';
  bool _debugMode = false;
  
  // Value stabilization for smoother readings
  final List<double> _recentReadings = [];
  static const int _stabilizationWindowSize = 3;
  
  // Processing lock to prevent buffer overflow
  bool _isProcessingFrame = false;
  
  // Track if session was already saved to prevent duplicates
  bool _sessionSaved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCameras();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop camera stream when app is backgrounded or widget is inactive
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_controller.value.isStreamingImages) {
        _controller.stopImageStream();
        print('📷 Camera paused (app lifecycle)');
      }
    }
  }

  Future<void> _initializeCameras() async {
    cameras = await availableCameras();
    setState(() {
      isCamerasInitialized = true;
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        imageFormatGroup: ImageFormatGroup.yuv420,
        enableAudio: false, // Disable audio to reduce overhead
      );
    });
    // Set max images to prevent buffer overflow
    _controller.setFocusMode(FocusMode.auto); // Enable autofocus
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  Future<void> _toggleDebugMode() async {
    if (!_debugMode) {
      // Turning debug mode ON
      if (Platform.isAndroid) {
        // Check Android version - Android 10+ uses scoped storage
        // For Pictures folder, we typically don't need explicit permission on Android 10+
        // But some devices may still require it, so we try to request if available
        
        try {
          // Try to request storage permission (will work on Android 12 and below)
          final storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted && !storageStatus.isPermanentlyDenied) {
            final result = await Permission.storage.request();
            if (!result.isGranted && !result.isPermanentlyDenied) {
              // Permission denied, but we can still try to save to Pictures on Android 10+
              // This is fine - scoped storage allows it
              print('Storage permission not granted, but continuing with scoped storage');
            }
          }
        } catch (e) {
          // This is expected on Android 13+ where storage permission is deprecated
          // We can still write to Pictures folder using scoped storage
          print('Storage permission not available (Android 13+): $e');
        }
        
        // On Android 13+, check for media permissions instead
        try {
          final photosStatus = await Permission.photos.status;
          if (!photosStatus.isGranted && !photosStatus.isPermanentlyDenied) {
            final result = await Permission.photos.request();
            if (!result.isGranted && !result.isPermanentlyDenied) {
              print('Photos permission not granted, but continuing with scoped storage');
            }
          }
        } catch (e) {
          // Photos permission might not be available on older Android
          print('Photos permission not available: $e');
        }
      }
      
      setState(() {
        _debugMode = true;
        OcrService.setDebugMode(true);
        _statusMessage = 'Debug mode ON - Saving to Pictures/MLEspresso';
      });
      
      // Show instructions
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debug images will be saved to Pictures/MLEspresso folder\nCheck your Gallery app!'),
            duration: Duration(seconds: 5),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      // Turning debug mode OFF
      setState(() {
        _debugMode = false;
        OcrService.setDebugMode(false);
        _statusMessage = 'Debug mode OFF';
      });
    }
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
      _sessionSaved = false; // Reset save flag for new session
      _statusMessage = 'Recording...';
    });

    int frameSkipCount = 0;
    _controller.startImageStream((CameraImage image) async {
      // IMMEDIATE early exit if not recording or already processing
      if (!_isRecording || _isProcessingFrame || !mounted) {
        return;
      }
      
      frameSkipCount++;
      if (frameSkipCount >= 15) { // Process every 15th frame (~2 fps) to reduce buffer pressure
        frameSkipCount = 0;
        
        // Double-check before acquiring lock
        if (!_isRecording || !mounted) {
          return;
        }
        
        _isProcessingFrame = true; // Lock
        
        try {
          final stopwatch = Stopwatch()..start();
          double? weight = await OcrService.extractWeightFromImage(image);
          stopwatch.stop();
          
          if (weight != null && mounted) {
            // Apply stabilization filter
            double stabilizedWeight = _stabilizeReading(weight);
            
            setState(() {
              _currentWeight = stabilizedWeight;
              _currentSession?.addReading(stabilizedWeight);
              _statusMessage = 'OCR: ${stopwatch.elapsedMilliseconds}ms (raw: ${weight.toStringAsFixed(1)}g)';
            });
            print('Weight detected: ${stabilizedWeight}g (raw: ${weight}g, ${stopwatch.elapsedMilliseconds}ms)');
          } else if (mounted) {
            setState(() {
              _statusMessage = 'No weight detected (${stopwatch.elapsedMilliseconds}ms)';
            });
          }
        } catch (e) {
          print('Error processing frame: $e');
          if (mounted) {
            setState(() {
              _statusMessage = 'Error: $e';
            });
          }
        } finally {
          _isProcessingFrame = false; // Unlock
        }
      }
    });
  }

  void _stopRecording() {
    // Set flags immediately to stop processing
    _isRecording = false;
    _isProcessingFrame = false;
    
    // Stop image stream immediately
    if (_controller.value.isInitialized && _controller.value.isStreamingImages) {
      _controller.stopImageStream().catchError((e) {
        print('Warning: Error stopping image stream: $e');
        return null;
      });
    }
    
    // Save session if needed
    if (mounted) {
      setState(() {
        // Save session if it has data AND hasn't been saved yet
        if (_currentSession != null && 
            _currentSession!.readings.isNotEmpty && 
            !_sessionSaved) {
          SessionStorage().addSession(_currentSession!);
          _sessionSaved = true; // Mark as saved
          _statusMessage = 'Stopped - ${_currentSession!.readings.length} readings saved';
          print('✅ Session saved with ${_currentSession!.readings.length} readings');
        } else {
          _statusMessage = 'Stopped';
        }
      });
    }
  }

  void _resetSession() {
    setState(() {
      _currentSession = null;
      _currentWeight = null;
      _statusMessage = 'Ready';
      _recentReadings.clear();
      _isProcessingFrame = false; // Reset lock
    });
  }
  
  /// Stabilize readings using a moving average filter
  /// This helps smooth out OCR fluctuations
  double _stabilizeReading(double newReading) {
    _recentReadings.add(newReading);
    
    // Keep only the most recent readings
    if (_recentReadings.length > _stabilizationWindowSize) {
      _recentReadings.removeAt(0);
    }
    
    // Return moving average
    double sum = _recentReadings.reduce((a, b) => a + b);
    return sum / _recentReadings.length;
  }

  @override
  void deactivate() {
    // Called when widget is removed from tree (e.g., switching tabs)
    // Stop camera immediately to prevent buffer overflow
    if (_controller.value.isStreamingImages) {
      _controller.stopImageStream().catchError((e) {
        print('Error stopping stream in deactivate: $e');
      });
      _isProcessingFrame = false;
      print('📷 Camera stream stopped (deactivate)');
    }
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop recording if active
    if (_isRecording) {
      _stopRecording();
    }
    // Stop any remaining stream
    if (_controller.value.isStreamingImages) {
      _controller.stopImageStream().catchError((e) {
        print('Error stopping stream in dispose: $e');
      });
    }
    if (_controller.value.isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }
  
  @override
  void reassemble() {
    super.reassemble();
    // Called during hot reload - reset state
    _isProcessingFrame = false;
    if (_controller.value.isStreamingImages) {
      _controller.stopImageStream().then((_) {
        // Stream stopped, ready for restart
        print('🔄 Hot reload: Camera stream cleaned up');
      });
    }
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
                // Camera preview - full width and height
                SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.previewSize?.height ?? 1,
                      height: _controller.value.previewSize?.width ?? 1,
                      child: CameraPreview(_controller),
                    ),
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
                        if (_debugMode)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DEBUG MODE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Debug mode toggle button
                Positioned(
                  top: 20,
                  right: 20,
                  child: IconButton(
                    icon: Icon(
                      _debugMode ? Icons.bug_report : Icons.bug_report_outlined,
                      color: _debugMode ? Colors.orange : Colors.white,
                      size: 32,
                    ),
                    onPressed: _toggleDebugMode,
                    tooltip: 'Toggle Debug Mode',
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

