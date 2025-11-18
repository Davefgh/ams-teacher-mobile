// lib/utils/constants.dart
class ApiConstants {
  // IMPORTANT: For physical device on same WiFi network, use your computer's local IP address
  // Find your IP: 
  //   Windows: ipconfig (look for IPv4 Address)
  //   Mac/Linux: ifconfig or ip addr (look for inet)
  //   Example: http://192.168.1.100:8081
  
  // OPTION 1: For Physical Device on Same WiFi with HTTPS (Your backend uses HTTPS!)
  static const String baseUrl = 'https://192.168.254.106:8081'; // ✅ HTTPS - Your computer's IP address
  
  // OPTION 2: For Physical Device with HTTP (if backend doesn't use HTTPS)
  // static const String baseUrl = 'http://192.168.254.106:8081';
  
  // OPTION 3: For Emulator/Simulator (localhost works)
  // static const String baseUrl = 'http://localhost:8081';
  
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