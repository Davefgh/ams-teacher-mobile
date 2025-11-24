import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // Platform-aware base URL
  // Automatically selects the correct URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      // For Web: use localhost
      return 'http://localhost:8080';
    } else {
      // For Mobile: Check if running on emulator or physical device
      // You can manually switch between these two options:

      // OPTION A: For Android Emulator (10.0.2.2 is the special IP for host machine)
      return 'http://10.0.2.2:8080';

      // OPTION B: For Physical Device (uncomment and use your computer's IP)
      // return 'http://192.168.254.106:8080';
    }
  }

  // Auth endpoints
  static const String loginEndpoint = '/api/account/login';
  static const String registerEndpoint = '/api/account/register';
  static const String refreshEndpoint = '/api/account/refresh';
  static const String logoutEndpoint = '/api/account/logout';

  // Section endpoints
  static const String sectionsEndpoint = '/api/sections';
  static String sectionDetailsEndpoint(int id) => '/api/sections/$id';
  static String sectionStudentsEndpoint(int id) =>
      '/api/sections/$id/active-students';

  // Attendance endpoints
  static const String attendanceEndpoint = '/api/attendance';
  static String attendanceByIdEndpoint(int id) => '/api/attendance/$id';
  static String attendanceByStudentEndpoint(int studentId) =>
      '/api/attendance/student/$studentId';
  static String attendanceBySessionEndpoint(int sessionId) =>
      '/api/attendance/session/$sessionId';
  static const String attendanceSummaryEndpoint = '/api/attendance/summary';

  // Session endpoints
  static const String sessionsEndpoint = '/api/sessions';
  static String sessionByIdEndpoint(int id) => '/api/sessions/$id';

  // Timeout durations
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
