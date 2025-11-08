// lib/utils/constants.dart
class ApiConstants {
  // OPTION 1: Try HTTPS first (matches what Scalar is using)
  static const String baseUrl = 'https://localhost:8081';
  
  // OPTION 2: If HTTPS doesn't work, try HTTP on port 5142
  // static const String baseUrl = 'http://localhost:5142';
  
  // OPTION 3: For Physical Device (update IP if needed)
  // static const String baseUrl = 'http://192.168.254.106:5142';
  
  // Auth endpoints
  static const String loginEndpoint = '/api/account/login';
  static const String registerEndpoint = '/api/account/register';
  static const String refreshEndpoint = '/api/account/refresh';
  static const String logoutEndpoint = '/api/account/logout';
  
  // Section endpoints
  static const String sectionsEndpoint = '/api/sections';
  static String sectionDetailsEndpoint(int id) => '/api/sections/$id';
  static String sectionStudentsEndpoint(int id) => '/api/sections/$id/active-students';
  
  // Attendance endpoints
  static const String attendanceEndpoint = '/api/attendance';
  static String attendanceByIdEndpoint(int id) => '/api/attendance/$id';
  static String attendanceByStudentEndpoint(int studentId) => '/api/attendance/student/$studentId';
  static String attendanceBySessionEndpoint(int sessionId) => '/api/attendance/session/$sessionId';
  static const String attendanceSummaryEndpoint = '/api/attendance/summary';
  
  // Session endpoints
  static const String sessionsEndpoint = '/api/sessions';
  static String sessionByIdEndpoint(int id) => '/api/sessions/$id';
  
  // Timeout durations
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}