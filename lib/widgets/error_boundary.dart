import 'package:flutter/material.dart';
import '../utils/app_router.dart';

/// Error boundary widget for catching and displaying errors
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? errorWidget;
  final VoidCallback? onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorWidget,
    this.onError,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool hasError = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    // Catch Flutter errors
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleError(details.exception, details.stack);
    };
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    setState(() {
      hasError = true;
      errorMessage = error.toString();
    });

    widget.onError?.call();

    // Log error
    debugPrint('ErrorBoundary caught error: $error');
    debugPrint('Stack trace: $stackTrace');
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return widget.errorWidget ??
          _DefaultErrorWidget(
            errorMessage: errorMessage,
            onRetry: () {
              setState(() {
                hasError = false;
                errorMessage = null;
              });
            },
          );
    }

    return widget.child;
  }
}

class _DefaultErrorWidget extends StatelessWidget {
  final String? errorMessage;
  final VoidCallback onRetry;

  const _DefaultErrorWidget({
    this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF3B82F6),
              Color(0xFF60A5FA),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3A8A),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => AppRouter.toLogin(context),
                    child: const Text(
                      'Go to Login',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

