import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // Platform-aware base URL
  // Automatically selects the correct URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    } else {
      // Deployed Backend URL
      return 'http://attendance.eba-8g72z7wh.ap-southeast-1.elasticbeanstalk.com';
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
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
