import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class LoginState {
  final bool isLoading;
  final String? errorMessage;
  final bool isPasswordVisible;

  const LoginState({
    this.isLoading = false,
    this.errorMessage,
    this.isPasswordVisible = false,
  });

  LoginState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isPasswordVisible,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isPasswordVisible: isPasswordVisible ?? this.isPasswordVisible,
    );
  }
}

class LoginNotifier extends StateNotifier<LoginState> {
  final Ref _ref;

  LoginNotifier({
    required Ref ref,
  })  : _ref = ref,
        super(const LoginState());

  void togglePasswordVisibility() {
    state = state.copyWith(
      isPasswordVisible: !state.isPasswordVisible,
    );
  }

  Future<void> login(String username, String password) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );

    try {
      await _ref.read(authProvider.notifier).login(username, password);
      
      final authState = _ref.read(authProvider);
      
      if (!authState.isAuthenticated) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: authState.error ?? 'Login failed',
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      String errorMsg = 'Unable to connect to server.';
      
      // Provide more specific error messages
      if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        errorMsg = 'Connection timeout. Please check:\n'
            '1. Backend server is running\n'
            '2. Correct IP address: 192.168.254.106\n'
            '3. Correct port: 8081\n'
            '4. Both devices on same WiFi';
      } else if (e.toString().contains('Failed host lookup') || e.toString().contains('SocketException')) {
        errorMsg = 'Cannot reach server at 192.168.254.106:8081\n'
            'Please check:\n'
            '1. Backend is running\n'
            '2. Backend listens on 0.0.0.0 (not just localhost)\n'
            '3. Windows Firewall allows port 8081\n'
            '4. Both devices on same WiFi network';
      } else {
        errorMsg = 'Error: ${e.toString()}';
      }
      
      state = state.copyWith(
        isLoading: false,
        errorMessage: errorMsg,
      );
    }
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  return LoginNotifier(ref: ref);
});

