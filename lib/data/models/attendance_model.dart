class AttendanceModel {
  final DateTime checkIn;
  final DateTime? checkOut;
  final String status;
  final String location;
  final String userId;
  final String userName;

  AttendanceModel({
    required this.checkIn,
    this.checkOut,
    required this.status,
    required this.location,
    required this.userId,
    required this.userName,
  });
}
