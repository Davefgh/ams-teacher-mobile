import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // Loaded from .env file
  static String get baseUrl =>
      dotenv.get('API_URL', fallback: 'http://192.168.254.106:8080');

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
