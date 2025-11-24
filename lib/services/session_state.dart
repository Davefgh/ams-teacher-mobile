class SessionState {
  static final SessionState _instance = SessionState._internal();
  static SessionState get instance => _instance;

  SessionState._internal();

  bool isActive = false;
  DateTime? startTime;
  Map<String, dynamic>? currentSchedule;
  DateTime? cutoffTime;

  void startSession(Map<String, dynamic> schedule, DateTime start) {
    isActive = true;
    currentSchedule = schedule;
    startTime = start;
    cutoffTime = null; // Reset or set if passed
  }

  void endSession() {
    isActive = false;
    currentSchedule = null;
    startTime = null;
    cutoffTime = null;
  }
}
