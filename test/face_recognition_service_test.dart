import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_next/data/services/face_recognition_service.dart';

void main() {
  group('FaceRecognitionService', () {
    test('compareFaceEmbeddings should return 0.0 when one embedding is all zeros', () {
      final embedding1 = '1.0,2.0,3.0';
      final embedding2 = '0.0,0.0,0.0';
      final similarity = FaceRecognitionService.compareFaceEmbeddings(embedding1, embedding2);
      expect(similarity, 0.0);
    });
  });
}
