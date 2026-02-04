import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../utils/app_router.dart';

/// Navigation guard for protected routes
class AuthGuard {
  static Future<bool> canActivate(BuildContext context) async {
    final isAuthenticated = await StorageService.isAuthenticated();
    
    if (!isAuthenticated) {
      // Redirect to login if not authenticated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AppRouter.toLogin(context);
      });
      return false;
    }
    
    return true;
  }

  static Future<void> checkAuthAndRedirect(BuildContext context) async {
    final isAuthenticated = await StorageService.isAuthenticated();
    
    if (!isAuthenticated) {
      AppRouter.toLogin(context);
    }
  }
}

