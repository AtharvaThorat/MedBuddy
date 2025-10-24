import 'package:local_auth/local_auth.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static AuthService get instance => _instance;

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<void> initialize() async {
    // Authentication service initialized
  }

  // Check if the device supports biometric authentication
  Future<bool> isBiometricsAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (e) {
      // Error checking biometrics
      return false;
    }
  }

  // Authenticate the user using device security
  Future<bool> authenticateUser() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access MedBuddy',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      // Authentication error
      return false;
    }
  }
}
