import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/attendance_screen.dart';
import '../screens/qr_screen.dart';
import '../screens/sections_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/students_screen.dart';

/// Centralized navigation helper
class AppRouter {
  // Prevent instantiation
  AppRouter._();

  // Navigate to login
  static void toLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // Navigate to dashboard
  static void toDashboard(BuildContext context, {bool replace = false}) {
    if (replace) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  // Navigate to attendance
  static void toAttendance(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AttendanceScreen()),
    );
  }

  // Navigate to QR screen
  static void toQrScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScreen()),
    );
  }

  // Navigate to sections
  static void toSections(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SectionsScreen()),
    );
  }

  // Navigate to profile
  static void toProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  // Navigate to students with section ID
  static void toStudents(
    BuildContext context, {
    required int sectionId,
    required String subjectName,
    required String subjectCode,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentsScreen(
          sectionId: sectionId,
          subjectName: subjectName,
          subjectCode: subjectCode,
        ),
      ),
    );
  }

  // Go back
  static void goBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  // Navigate with replacement (for bottom nav)
  static void navigateBottomNav(BuildContext context, int index) {
    switch (index) {
      case 0:
        AppRouter.toDashboard(context, replace: true);
        break;
      case 1:
        AppRouter.toAttendance(context);
        break;
      case 2:
        AppRouter.toQrScreen(context);
        break;
      case 3:
        AppRouter.toSections(context);
        break;
      case 4:
        AppRouter.toProfile(context);
        break;
    }
  }
}

