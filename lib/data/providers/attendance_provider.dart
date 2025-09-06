import 'dart:io';
import 'package:flutter/material.dart';
import '../models/attendance_model.dart';

class AttendanceProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<AttendanceModel> _attendanceHistory = [];
  List<AttendanceModel> get attendanceHistory => _attendanceHistory;

  AttendanceModel? get todayAttendance {
    final now = DateTime.now();
    try {
      return _attendanceHistory.firstWhere(
        (record) =>
            record.checkIn.year == now.year &&
            record.checkIn.month == now.month &&
            record.checkIn.day == now.day,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> loadAttendanceHistory(String userId) async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1));

    // Mock data
    _attendanceHistory = [
      AttendanceModel(
        userId: userId,
        userName: 'Jules Verne',
        checkIn: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
        checkOut: DateTime.now().subtract(const Duration(days: 1)),
        status: 'present',
        location: 'Office A',
      ),
      AttendanceModel(
        userId: userId,
        userName: 'Jules Verne',
        checkIn: DateTime.now().subtract(const Duration(days: 2, minutes: 30)),
        checkOut: DateTime.now().subtract(const Duration(days: 2)),
        status: 'late',
        location: 'Office B',
      ),
    ];

    _setLoading(false);
    notifyListeners();
  }

  Future<bool> checkIn({
    required String userId,
    required String userName,
    required File faceImage,
  }) async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 2));

    final newAttendance = AttendanceModel(
      userId: userId,
      userName: userName,
      checkIn: DateTime.now(),
      status: DateTime.now().hour < 9 ? 'present' : 'late',
      location: 'Mock Location - Office',
    );

    _attendanceHistory.insert(0, newAttendance);

    _setLoading(false);
    notifyListeners();
    return true;
  }

  Future<bool> checkOut(String userId) async {
    _setLoading(true);
    await Future.delayed(const Duration(seconds: 1));

    final today = todayAttendance;
    if (today != null) {
      final updatedRecord = AttendanceModel(
        userId: today.userId,
        userName: today.userName,
        checkIn: today.checkIn,
        checkOut: DateTime.now(),
        status: today.status,
        location: today.location,
      );

      final index = _attendanceHistory.indexWhere((record) => record.checkIn == today.checkIn);
      if (index != -1) {
        _attendanceHistory[index] = updatedRecord;
      }

      _setLoading(false);
      notifyListeners();
      return true;
    }

    _setLoading(false);
    return false;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
