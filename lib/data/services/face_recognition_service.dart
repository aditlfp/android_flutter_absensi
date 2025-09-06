import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math';

class FaceRecognitionService {
  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  static Future<List<Face>> detectFacesFromXFile(XFile imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    return await _faceDetector.processImage(inputImage);
  }

  static Future<List<Face>> detectFacesFromImage(InputImage image) async {
    return await _faceDetector.processImage(image);
  }

  static Future<String> generateFaceEmbedding(XFile imageFile) async {
    try {
      final faces = await detectFacesFromXFile(imageFile);

      if (faces.isEmpty) {
        throw Exception('No face detected');
      }

      if (faces.length > 1) {
        throw Exception('Multiple faces detected. Please ensure only one person is in the frame.');
      }

      final face = faces.first;

      String embedding = _createSimpleEmbedding(face);

      return embedding;
    } catch (e) {
      throw Exception('Face processing failed: $e');
    }
  }

  static String _createSimpleEmbedding(Face face) {
    List<double> features = [];
    features.add(face.boundingBox.width / face.boundingBox.height);

    if (face.landmarks.isNotEmpty) {
      for (var landmark in face.landmarks.values) {
        if (landmark != null) {
          features.add(landmark.position.x.toDouble());
          features.add(landmark.position.y.toDouble());
        }
      }
    }

    if (face.headEulerAngleX != null) features.add(face.headEulerAngleX!);
    if (face.headEulerAngleY != null) features.add(face.headEulerAngleY!);
    if (face.headEulerAngleZ != null) features.add(face.headEulerAngleZ!);

    return features.map((f) => f.toStringAsFixed(4)).join(',');
  }

  static double compareFaceEmbeddings(String embedding1, String embedding2) {
    try {
      List<double> features1 = embedding1.split(',').map(double.parse).toList();
      List<double> features2 = embedding2.split(',').map(double.parse).toList();

      if (features1.length != features2.length) {
        return 0.0;
      }

      double dotProduct = 0.0;
      double norm1 = 0.0;
      double norm2 = 0.0;

      for (int i = 0; i < features1.length; i++) {
        dotProduct += features1[i] * features2[i];
        norm1 += features1[i] * features1[i];
        norm2 += features2[i] * features2[i];
      }

      return dotProduct / (sqrt(norm1) * sqrt(norm2));
    } catch (e) {
      return 0.0;
    }
  }

  static bool isSamePerson(String embedding1, String embedding2, {double threshold = 0.8}) {
    double similarity = compareFaceEmbeddings(embedding1, embedding2);
    return similarity >= threshold;
  }

  static bool checkLiveness(Face face) {
    final bool isBlinking = (face.leftEyeOpenProbability ?? 1.0) < 0.1 &&
                            (face.rightEyeOpenProbability ?? 1.0) < 0.1;
    final bool isFrontFacing = (face.headEulerAngleY?.abs() ?? 90) < 15;
    final bool isNotTilted = (face.headEulerAngleZ?.abs() ?? 90) < 15;
    final bool isSmiling = (face.smilingProbability ?? 0.0) > 0.7;

    return (isBlinking || isSmiling) && isFrontFacing && isNotTilted;
  }

  static void dispose() {
    _faceDetector.close();
  }
}
