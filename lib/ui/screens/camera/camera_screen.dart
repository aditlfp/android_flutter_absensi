import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/attendance_provider.dart';
import '../../../data/services/face_recognition_service.dart';
import '../home/home_screen.dart';

enum LivenessState { idle, eyesOpen, eyesClosed, complete }

class CameraScreen extends StatefulWidget {
  final bool isRegistration;
  const CameraScreen({super.key, this.isRegistration = false});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;

  Face? _detectedFace;
  LivenessState _livenessState = LivenessState.idle;
  String _statusMessage = "Position your face in the frame";
  Color _statusColor = Colors.blue;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      final frontCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(frontCamera, ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      setState(() => _isInitialized = true);

      _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      _updateStatus('Camera initialization failed', Colors.red);
    }
  }

  void _processCameraImage(CameraImage image) {
    if (_isProcessing) return;

    final inputImage = InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation270deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );

    FaceRecognitionService.detectFacesFromImage(inputImage).then((faces) {
      if (faces.isNotEmpty) {
        if(mounted) setState(() => _detectedFace = faces.first);
        _handleLivenessCheck(faces.first);
      } else {
        if(mounted) {
          setState(() => _detectedFace = null);
          _updateStatus("Position your face in the frame", Colors.blue);
          _livenessState = LivenessState.idle;
        }
      }
    }).catchError((_) {
      // Handle error, maybe log it
    });
  }

  void _handleLivenessCheck(Face face) {
    final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;

    switch (_livenessState) {
      case LivenessState.idle:
        _updateStatus("Face detected. Now, please blink.", Colors.green);
        if (leftEyeOpen > 0.8 && rightEyeOpen > 0.8) {
          _livenessState = LivenessState.eyesOpen;
        }
        break;
      case LivenessState.eyesOpen:
        if (leftEyeOpen < 0.2 && rightEyeOpen < 0.2) {
          _livenessState = LivenessState.eyesClosed;
        }
        break;
      case LivenessState.eyesClosed:
        if (leftEyeOpen > 0.8 && rightEyeOpen > 0.8) {
          _updateStatus("Blink detected! Capturing...", Colors.green);
          _livenessState = LivenessState.complete;
          _captureAndProcess();
        }
        break;
      case LivenessState.complete:
        break;
    }
  }

  Future<void> _captureAndProcess() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await _controller?.stopImageStream();

    try {
      final image = await _controller!.takePicture();
      String embedding = await FaceRecognitionService.generateFaceEmbedding(image);

      if (widget.isRegistration) {
        await _registerFace(embedding);
      } else {
        await _verifyFaceForAttendance(image, embedding);
      }
    } catch (e) {
      _updateStatus(e.toString().replaceAll('Exception: ', ''), Colors.red);
      setState(() => _isProcessing = false);
      if (_controller != null) _controller!.startImageStream(_processCameraImage);
    }
  }

  // ... (rest of the helper methods _registerFace, _verifyFaceForAttendance remain similar)
  Future<void> _registerFace(String embedding) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = await authProvider.updateFaceEmbedding(embedding);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Face registered successfully!'), backgroundColor: Colors.green));
      Navigator.of(context).pop(true);
    } else {
      _updateStatus('Face registration failed', Colors.red);
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _verifyFaceForAttendance(XFile image, String embedding) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);

    if (authProvider.userModel?.faceEmbedding.isEmpty ?? true) {
      _updateStatus('Face not registered. Please register first.', Colors.red);
      setState(() => _isProcessing = false);
      return;
    }

    bool isSamePerson = FaceRecognitionService.isSamePerson(authProvider.userModel!.faceEmbedding, embedding);
    if (!isSamePerson) {
      _updateStatus('Face verification failed. Try again.', Colors.red);
      setState(() => _isProcessing = false);
      return;
    }

    bool success = await attendanceProvider.checkIn(
      userId: authProvider.user!.uid,
      userName: authProvider.userModel!.name,
      faceImage: File(image.path),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance recorded successfully!'), backgroundColor: Colors.green));
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    } else {
      _updateStatus('Attendance recording failed', Colors.red);
      setState(() => _isProcessing = false);
    }
  }

  void _updateStatus(String message, Color color) {
    if (mounted) setState(() {
      _statusMessage = message;
      _statusColor = color;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isRegistration ? 'Register Face' : 'Face Verification')),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: _buildCameraPreview(),
          ),
          Expanded(
            flex: 2,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_controller!),
            if (_detectedFace != null)
              CustomPaint(painter: FacePainter(_controller!, _detectedFace!)),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _statusMessage,
              key: ValueKey<String>(_statusMessage),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_isProcessing) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ]
        ],
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final CameraController controller;
  final Face face;

  FacePainter(this.controller, this.face);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    final Rect faceRect = _scaleRect(
      rect: face.boundingBox,
      imageSize: controller.value.previewSize!,
      widgetSize: size,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(faceRect, const Radius.circular(16)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  Rect _scaleRect({required Rect rect, required Size imageSize, required Size widgetSize}) {
    final double scaleX = widgetSize.width / imageSize.height;
    final double scaleY = widgetSize.height / imageSize.width;

    return Rect.fromLTRB(
      widgetSize.width - rect.right * scaleX,
      rect.top * scaleY,
      widgetSize.width - rect.left * scaleX,
      rect.bottom * scaleY,
    );
  }
}
