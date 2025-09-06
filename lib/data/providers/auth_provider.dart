import 'package:flutter/material.dart';
import '../models/user_model.dart';

// Mock User class from Firebase Auth
class User {
  final String uid;
  User({required this.uid});
}

class AuthProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? _user;
  User? get user => _user;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  AuthProvider() {
    // Mock a logged-in user for development
    _user = User(uid: 'mock_user_id_123');
    _userModel = UserModel(
      uid: 'mock_user_id_123',
      name: 'Jules Verne',
      email: 'jules.verne@example.com',
      department: 'Engineering',
      position: 'Lead Developer',
      faceEmbedding: '', // Initially no face embedding
    );
  }

  Future<bool> registerUser({
    required String email,
    required String password,
    required String name,
    required String department,
    required String position,
  }) async {
    _setLoading(true);
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Mock registration logic
    _user = User(uid: 'new_mock_user_id');
    _userModel = UserModel(
      uid: 'new_mock_user_id',
      name: name,
      email: email,
      department: department,
      position: position,
    );

    _setLoading(false);
    notifyListeners();
    return true; // Simulate success
  }

  Future<bool> updateFaceEmbedding(String embedding) async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1));

    if (_userModel != null) {
      _userModel = UserModel(
        uid: _userModel!.uid,
        name: _userModel!.name,
        email: _userModel!.email,
        department: _userModel!.department,
        position: _userModel!.position,
        faceEmbedding: embedding,
      );
      _setLoading(false);
      notifyListeners();
      return true;
    }

    _setLoading(false);
    return false;
  }

  Future<void> signOut() async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1));
    _user = null;
    _userModel = null;
    _setLoading(false);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
