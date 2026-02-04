import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static Future<void> init() async {
    // No initialization needed for FlutterSecureStorage
  }

  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'accessToken', value: accessToken);
    await _storage.write(key: 'refreshToken', value: refreshToken);
  }

  static Future<void> saveInstructorId(String instructorId) async {
    await _storage.write(key: 'instructorId', value: instructorId);
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'accessToken');
  }

  // Alias for getAccessToken() - used by ApiService
  static Future<String?> getToken() async {
    return getAccessToken();
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refreshToken');
  }

  static Future<String?> getInstructorId() async {
    return await _storage.read(key: 'instructorId');
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: 'accessToken');
    await _storage.delete(key: 'refreshToken');
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
