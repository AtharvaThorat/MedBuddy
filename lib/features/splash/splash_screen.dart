import 'package:flutter/material.dart';
import 'package:medbuddy/core/constants/asset_paths.dart';
import 'package:medbuddy/core/services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService.instance;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Show splash screen for at least 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      _authenticateUser();
    }
  }

  Future<void> _authenticateUser() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      bool canAuthenticate = await _authService.isBiometricsAvailable();

      if (canAuthenticate) {
        try {
          bool authenticated = await _authService.authenticateUser();

          if (mounted) {
            if (authenticated) {
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              // Authentication failed, show message and retry button
              _showAuthFailedDialog();
            }
          }
        } catch (e) {
          // Authentication process error
          // Go to home on authentication process error
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      } else {
        // If device doesn't support biometrics, go to home screen anyway
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      // Authentication error
      // Fall back to home screen on errors
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _showAuthFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Failed'),
        content: const Text('Please try again to access your medications.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _authenticateUser();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: const Text('Continue Anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(AssetPaths.homePage, width: 350, height: 350),
            const SizedBox(height: 30),
            if (_isAuthenticating) const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
