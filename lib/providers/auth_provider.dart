import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../providers/services_provider.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? error;
  final String? instructorId;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
    this.instructorId,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
    String? instructorId,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      instructorId: instructorId ?? this.instructorId,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;

  AuthNotifier({required ApiService apiService})
    : _apiService = apiService,
      super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isAuthenticated = await StorageService.isAuthenticated();
    final instructorId = await StorageService.getInstructorId();

    state = state.copyWith(
      isAuthenticated: isAuthenticated,
      instructorId: instructorId,
    );
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _apiService.login(username, password);

      print('🔍 Auth Provider - Processing login response...');
      print('🔍 Response data: $response');
      print('🔍 Checking success field: ${response['success']}');
      print('🔍 Checking accessToken field: ${response['accessToken']}');

      if (response['success'] == true && response['accessToken'] != null) {
        print('✅ Login successful - saving tokens...');

        await StorageService.saveTokens(
          response['accessToken'] as String,
          response['refreshToken'] as String? ?? '',
        );

        print('✅ Tokens saved - fetching profile...');

        // Fetch instructor profile to get ID
        try {
          final profileResponse = await _apiService.getInstructorProfile();

          if (profileResponse['success'] == true &&
              profileResponse['data'] != null) {
            final profileData = profileResponse['data'] as Map<String, dynamic>;
            String? instructorId;

            if (profileData['instructorProfile'] != null) {
              final instructorProfile = profileData['instructorProfile'];
              if (instructorProfile['id'] != null) {
                instructorId = instructorProfile['id'].toString();
              }
            } else if (profileData['id'] != null) {
              instructorId = profileData['id'].toString();
            } else if (profileData['Id'] != null) {
              instructorId = profileData['Id'].toString();
            }

            if (instructorId != null) {
              await StorageService.saveInstructorId(instructorId);
              print('✅ Instructor ID saved: $instructorId');
            } else {
              print('⚠️ Instructor ID not found in profile data');
              print('Profile Data Keys: ${profileData.keys.toList()}');
            }
          }
        } catch (profileError) {
          print('⚠️ Profile fetch error (continuing anyway): $profileError');
          // Continue anyway, sections will load via JWT token
        }

        print('✅ Setting authenticated state...');
        state = state.copyWith(isAuthenticated: true, isLoading: false);
      } else {
        print('❌ Login failed - success or accessToken missing');
        print('   → success: ${response['success']}');
        print('   → accessToken: ${response['accessToken']}');

        state = state.copyWith(
          isLoading: false,
          error: response['message'] as String? ?? 'Login failed',
        );
      }
    } catch (e) {
      String errorMsg = 'Unable to connect to server.';

      // Provide more specific error messages
      final errorString = e.toString();
      print('🔴 Login error details: $errorString');

      if (errorString.contains('timeout') ||
          errorString.contains('TimeoutException')) {
        errorMsg =
            'Connection timeout.\n\n'
            'Please check:\n'
            '• Backend server is running\n'
            '• IP: 192.168.254.106:8081\n'
            '• Both devices on same WiFi\n'
            '• Windows Firewall allows port 8081';
      } else if (errorString.contains('Failed host lookup') ||
          errorString.contains('SocketException') ||
          errorString.contains('Network is unreachable')) {
        errorMsg =
            'Cannot reach server.\n\n'
            'Please check:\n'
            '• Backend is running on port 8081\n'
            '• Backend listens on 0.0.0.0 (not localhost)\n'
            '• Windows Firewall allows port 8081\n'
            '• Both devices on same WiFi network\n'
            '• Try: http://192.168.254.106:8081 in phone browser';
      } else if (errorString.contains('Certificate') ||
          errorString.contains('TLS')) {
        errorMsg =
            'SSL/Certificate error.\n\n'
            'Using HTTP instead of HTTPS.\n'
            'If backend requires HTTPS, update constants.dart';
      } else if (errorString.contains('Connection closed before full header')) {
        errorMsg =
            'Connection closed by server.\n\n'
            'This usually means:\n'
            '• Backend expects HTTPS (not HTTP)\n'
            '• Backend rejects HTTP connections\n'
            '• Protocol mismatch\n\n'
            'Try:\n'
            '1. Check if backend uses HTTPS\n'
            '2. Test: http://192.168.254.106:8081 in phone browser\n'
            '3. Check backend logs for rejection reason';
      } else {
        errorMsg =
            'Connection error:\n${errorString}\n\n'
            'Server: http://192.168.254.106:8081\n'
            'Check backend is running and accessible.';
      }

      state = state.copyWith(isLoading: false, error: errorMsg);
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    try {
      final token = await StorageService.getAccessToken();
      if (token != null) {
        await _apiService.logout(token);
      }
    } catch (e) {
      // Continue with logout even if API call fails
    }

    await StorageService.clearAll();
    state = const AuthState();
  }

  Future<void> checkAuth() async {
    await _checkAuthStatus();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(apiService: ref.watch(apiServiceProvider));
});
