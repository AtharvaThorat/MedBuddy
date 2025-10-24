import 'package:flutter/material.dart';
import 'package:medbuddy/core/constants/asset_paths.dart';
import 'package:medbuddy/core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService.instance;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Check if device supports biometrics on screen load
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final canAuthenticate = await _authService.isBiometricsAvailable();
    if (!canAuthenticate && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('This device does not support biometric authentication'),
        ),
      );
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final authenticated = await _authService.authenticateUser();

      if (mounted) {
        if (authenticated) {
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authentication error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                AssetPaths.medScan,
                height: 200,
              ),
              const SizedBox(height: 32),
              const Text(
                'Welcome to MedBuddy',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Authenticate to access your medications',
                style: TextStyle(
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_isAuthenticating)
                const CircularProgressIndicator()
              else
                ElevatedButton.icon(
                  onPressed: _authenticateWithBiometrics,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Authenticate'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                child: const Text('Skip Authentication'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
