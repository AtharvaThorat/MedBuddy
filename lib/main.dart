import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medbuddy/core/services/database_service.dart';
import 'package:medbuddy/core/services/emergency_service.dart';
import 'package:medbuddy/core/services/auth_service.dart';
import 'package:medbuddy/features/home/home_screen.dart';
import 'package:medbuddy/features/history/history_screen.dart';
import 'package:medbuddy/features/medications/medication_list_screen.dart';
import 'package:medbuddy/features/schedule/schedule_screen.dart';
import 'package:medbuddy/features/splash/splash_screen.dart';
import 'package:medbuddy/features/emergency/emergency_contacts_screen.dart';
import 'package:medbuddy/features/emergency/emergency_contact_form_screen.dart';
import 'package:medbuddy/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await AuthService.instance.initialize();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Get database instance - this initializes the database
  await DatabaseService.instance.database;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedBuddy',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/medications': (context) => const MedicationListScreen(),
        '/history': (context) => const HistoryScreen(),
        '/schedule': (context) => const ScheduleScreen(),
        '/emergency': (context) => const EmergencyContactsScreen(),
        '/emergency/add': (context) => const EmergencyContactFormScreen(),
      },
      builder: (context, child) {
        return Scaffold(
          body: child,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.only(bottom: 60.0),
              child: FloatingActionButton(
                heroTag: 'helpButton',
                backgroundColor: Colors.red,
                onPressed: () => _handleHelpButton(context),
                child: const Icon(Icons.emergency, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleHelpButton(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Help'),
        content: const Text(
            'Do you need emergency assistance? This will call your emergency contact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Call Emergency Contact'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Use the EmergencyService to call the first contact
      final emergencyService = EmergencyService.instance;
      final hasContacts = await emergencyService.hasEmergencyContacts();

      if (hasContacts) {
        await emergencyService.callFirstEmergencyContact(context: context);
      } else {
        // Navigate to emergency contacts screen to add contacts
        Navigator.pushNamed(context, '/emergency');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add emergency contacts first')),
        );
      }
    }
  }
}
