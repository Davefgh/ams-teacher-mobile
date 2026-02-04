import 'package:flutter/material.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  static SettingsService get instance => _instance;

  SettingsService._internal();

  bool _isDarkMode = false;
  bool _isEyeProtectionMode = false;

  bool get isDarkMode => _isDarkMode;
  bool get isEyeProtectionMode => _isEyeProtectionMode;

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void toggleEyeProtection() {
    _isEyeProtectionMode = !_isEyeProtectionMode;
    notifyListeners();
  }
}
