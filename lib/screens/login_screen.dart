import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../utils/responsive_utils.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      // Response is a Map<String, dynamic>
      if (response['success'] == true && response['accessToken'] != null) {
        // Save tokens securely
        await StorageService.saveTokens(
          response['accessToken'] as String,
          response['refreshToken'] as String? ?? '',
        );
        
        // Save instructor ID from login response
        if (response['user'] != null) {
          await StorageService.saveInstructorId(response['user'].toString());
        }
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const DashboardScreen(),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = response['message'] as String? ?? 'Login failed';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to connect to server. Please check your internet connection. Error: $e';
      });
      print('Login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF60A5FA),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF3B82F6),
              Color(0xFF60A5FA),
            ],
          ),
        ),
        child: SafeArea(
          child: ResponsiveWidget(
            mobile: _buildMobileLayout(context),
            tablet: _buildTabletLayout(context),
            desktop: _buildDesktopLayout(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/aclc_logo.png',
                width: ResponsiveUtils.getResponsiveImageSize(
                  context,
                  mobile: 200,
                  tablet: 250,
                  desktop: 300,
                ),
                height: ResponsiveUtils.getResponsiveImageSize(
                  context,
                  mobile: 120,
                  tablet: 150,
                  desktop: 180,
                ),
                fit: BoxFit.contain,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 24,
                tablet: 32,
                desktop: 40,
              )),
              Text(
                'Attendance Monitoring',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 24,
                    tablet: 28,
                    desktop: 32,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            margin: ResponsiveUtils.getResponsiveMargin(context),
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: ResponsiveUtils.getResponsivePadding(context),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign In',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 20,
                                  tablet: 24,
                                  desktop: 28,
                                ),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: 24,
                              tablet: 32,
                              desktop: 40,
                            )),
                            _buildUsernameField(context),
                            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: 20,
                              tablet: 24,
                              desktop: 28,
                            )),
                            _buildPasswordField(context),
                            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: 24,
                              tablet: 32,
                              desktop: 40,
                            )),
                            _buildErrorMessage(context),
                            _buildLoginButton(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Row(
      children: [
        // Left side - Logo and title
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/aclc_logo.png',
                width: ResponsiveUtils.getResponsiveImageSize(
                  context,
                  mobile: 200,
                  tablet: 250,
                  desktop: 300,
                ),
                height: ResponsiveUtils.getResponsiveImageSize(
                  context,
                  mobile: 120,
                  tablet: 150,
                  desktop: 180,
                ),
                fit: BoxFit.contain,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 24,
                tablet: 32,
                desktop: 40,
              )),
              Text(
                'Attendance Monitoring',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 24,
                    tablet: 28,
                    desktop: 32,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // Right side - Login form
        Expanded(
          flex: 1,
          child: Container(
            margin: ResponsiveUtils.getResponsiveMargin(context),
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: ResponsiveUtils.getResponsivePadding(context),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Sign In',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 20,
                                  tablet: 24,
                                  desktop: 28,
                                ),
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: 24,
                              tablet: 32,
                              desktop: 40,
                            )),
                            _buildUsernameField(context),
                            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: 20,
                              tablet: 24,
                              desktop: 28,
                            )),
                            _buildPasswordField(context),
                            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: 24,
                              tablet: 32,
                              desktop: 40,
                            )),
                            _buildErrorMessage(context),
                            _buildLoginButton(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Row(
          children: [
            // Left side - Logo and title
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                      'assets/images/aclc_logo.png',
                    width: ResponsiveUtils.getResponsiveImageSize(
                      context,
                      mobile: 200,
                      tablet: 250,
                      desktop: 300,
                    ),
                    height: ResponsiveUtils.getResponsiveImageSize(
                      context,
                      mobile: 120,
                      tablet: 150,
                      desktop: 180,
                    ),
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 24,
                    tablet: 32,
                    desktop: 40,
                  )),
                  Text(
                    'Attendance Monitoring',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 24,
                        tablet: 28,
                        desktop: 32,
                      ),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            // Right side - Login form
            Expanded(
              flex: 1,
              child: Container(
                margin: ResponsiveUtils.getResponsiveMargin(context),
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                          child: Container(
                            padding: ResponsiveUtils.getResponsivePadding(context),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Sign In',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                                      context,
                                      mobile: 20,
                                      tablet: 24,
                                      desktop: 28,
                                    ),
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        offset: const Offset(0, 2),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 24,
                                  tablet: 32,
                                  desktop: 40,
                                )),
                                _buildUsernameField(context),
                                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 20,
                                  tablet: 24,
                                  desktop: 28,
                                )),
                                _buildPasswordField(context),
                                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 24,
                                  tablet: 32,
                                  desktop: 40,
                                )),
                                _buildErrorMessage(context),
                                _buildLoginButton(context),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameField(BuildContext context) {
    return TextFormField(
      controller: _usernameController,
      keyboardType: TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Username or Email',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        hintText: 'Enter your username or email',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: const Icon(Icons.person_outline, color: Colors.white),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.6), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.6)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.8), width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24),
          vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your username or email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
        hintText: 'Enter your password',
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
        prefixIcon: const Icon(Icons.lock_outlined, color: Colors.white),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.6), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.6)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red.withOpacity(0.8), width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24),
          vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        }
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildErrorMessage(BuildContext context) {
    if (_errorMessage == null) return const SizedBox.shrink();
    
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context),
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[300], size: 20),
          SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 12, desktop: 16)),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red[200], 
                fontWeight: FontWeight.w500,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 12, tablet: 14, desktop: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Container(
          height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 48, tablet: 56, desktop: 64),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.white.withOpacity(0.1),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28),
                    width: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16, tablet: 18, desktop: 20),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}