class SessionState {
  static final SessionState _instance = SessionState._internal();
  static SessionState get instance => _instance;

  SessionState._internal();

  bool isActive = false;
  DateTime? startTime;
  Map<String, dynamic>? currentSchedule;
  DateTime? cutoffTime;

  String? qrHash;

  void startSession(
    Map<String, dynamic> schedule,
    DateTime start, {
    String? hash,
  }) {
    isActive = true;
    currentSchedule = schedule;
    startTime = start;
    cutoffTime = null; // Reset or set if passed
    qrHash = hash;
  }

  void endSession() {
    isActive = false;
    currentSchedule = null;
    startTime = null;
    cutoffTime = null;
    qrHash = null;
  }
}
