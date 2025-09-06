import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  CameraDescription? _camera;
  bool _isInitialized = false;
  bool _isProcessing = false;

  Face? _detectedFace;
  LivenessState _livenessState = LivenessState.idle;
  String _statusMessage = "Position your face in the frame";
  Color _statusColor = Colors.blue;

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      _camera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );

      _controller = CameraController(
        _camera!,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await _controller!.initialize();
      setState(() => _isInitialized = true);

      _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      _updateStatus('Camera initialization failed', Colors.red);
    }
  }

  void _processCameraImage(CameraImage image) {
    if (_isProcessing || !_isInitialized || _controller == null) return;
    _isProcessing = true;

    final sensorOrientation = _camera!.sensorOrientation;
    var rotationCompensation = _orientations[_controller!.value.deviceOrientation];
    if (rotationCompensation == null) {
      _isProcessing = false;
      return;
    }

    if (_camera!.lensDirection == CameraLensDirection.front) {
      rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    final rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    if (rotation == null) {
      _isProcessing = false;
      return;
    }

    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
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
    }).whenComplete(() => _isProcessing = false);
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

    // Check if the face is mostly forward-facing before proceeding
    final headEulerAngleY = face.headEulerAngleY;
    if (headEulerAngleY == null || headEulerAngleY.abs() > 15) {
      _updateStatus("Please look straight at the camera", Colors.orange);
      return;
    }

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
        // Do nothing, already processing
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
      // Restart stream if not navigated away
      if (mounted && _controller != null) {
        _controller!.startImageStream(_processCameraImage);
        _livenessState = LivenessState.idle;
      }
    }
  }

  Future<void> _registerFace(String embedding) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success = await authProvider.updateFaceEmbedding(embedding);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Face registered successfully!'), backgroundColor: Colors.green));
      Navigator.of(context).pop(true);
    } else {
      _updateStatus('Face registration failed. Please try again.', Colors.red);
      setState(() => _isProcessing = false);
      if (mounted && _controller != null) {
        _controller!.startImageStream(_processCameraImage);
        _livenessState = LivenessState.idle;
      }
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
      if (mounted && _controller != null) {
        _controller!.startImageStream(_processCameraImage);
        _livenessState = LivenessState.idle;
      }
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
      if (mounted && _controller != null) {
        _controller!.startImageStream(_processCameraImage);
        _livenessState = LivenessState.idle;
      }
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
    final double scaleX = widgetSize.width / imageSize.width;
    final double scaleY = widgetSize.height / imageSize.height;

    final double scaledLeft = rect.left * scaleX;
    final double scaledTop = rect.top * scaleY;
    final double scaledRight = rect.right * scaleX;
    final double scaledBottom = rect.bottom * scaleY;

    // For front camera, the image is mirrored, so we need to adjust the horizontal coordinates
    return Rect.fromLTRB(
      widgetSize.width - scaledRight,
      scaledTop,
      widgetSize.width - scaledLeft,
      scaledBottom,
    );
  }
}
