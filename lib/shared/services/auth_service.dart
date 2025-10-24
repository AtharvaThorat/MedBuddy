import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';


class AuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticated = false;
  List<BiometricType> _availableBiometrics = [];

  // Initialize auth service
  Future<void> initialize() async {
    try {
      // Check if we can use biometrics
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (canCheckBiometrics && isDeviceSupported) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
      }
    } on PlatformException {
      // Failed to initialize biometrics
    }
  }

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException {
      // Error checking biometric availability
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      bool didAuthenticate = false;

      // Get available authentication options
      final bool canAuthenticateWithBiometrics =
          await _localAuth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      // Try to authenticate with device
      didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access MedBuddy',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Allow PIN/pattern/password
        ),
      );

      _isAuthenticated = didAuthenticate;
      return didAuthenticate;
    } on PlatformException catch (e) {
    // Print the error message for debugging
    print("PlatformException during authentication: ${e.message}");
    return false;
  } catch (e) {
    // Print the unexpected error message for debugging
    print("Unexpected error during authentication: $e");
    return false;
  }
  }

  bool get isAuthenticated => _isAuthenticated;

  List<BiometricType> get availableBiometrics => _availableBiometrics;

  void logout() {
    _isAuthenticated = false;
  }
}
