import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:medbuddy/core/services/database_service.dart';

class EmergencyService {
  // Singleton pattern
  static final EmergencyService _instance = EmergencyService._internal();
  static EmergencyService get instance => _instance;
  EmergencyService._internal();

  final DatabaseService _databaseService = DatabaseService.instance;

  /// Get all emergency contacts from the database
  Future<List<Map<String, dynamic>>> getEmergencyContacts() async {
    return await _databaseService.getEmergencyContacts();
  }

  /// Check if there are any emergency contacts
  Future<bool> hasEmergencyContacts() async {
    final contacts = await getEmergencyContacts();
    return contacts.isNotEmpty;
  }

  /// Get the first emergency contact
  Future<Map<String, dynamic>?> getFirstEmergencyContact() async {
    final contacts = await getEmergencyContacts();
    if (contacts.isEmpty) return null;
    return contacts.first;
  }

  /// Call a specific emergency contact
  Future<bool> callContact(Map<String, dynamic> contact,
      {BuildContext? context}) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: contact['phone']);
    try {
      final bool canLaunch = await canLaunchUrl(phoneUri);
      if (canLaunch) {
        await launchUrl(phoneUri);
        return true;
      } else {
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch phone dialer')),
          );
        }
        return false;
      }
    } catch (e) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making call: $e')),
        );
      }
      return false;
    }
  }

  /// Call the first emergency contact
  Future<bool> callFirstEmergencyContact({BuildContext? context}) async {
    final contact = await getFirstEmergencyContact();
    if (contact == null) {
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No emergency contacts available')),
        );
      }
      return false;
    }

    return await callContact(contact, context: context);
  }

  /// Sequential call to emergency contacts
  Future<void> startEmergencyCallSequence(BuildContext context) async {
    final contacts = await getEmergencyContacts();
    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No emergency contacts available')),
      );
      return;
    }

    // Start with the first contact
    int currentIndex = 0;
    bool continueSequence = true;

    while (continueSequence && currentIndex < contacts.length) {
      final contact = contacts[currentIndex];

      // Call the contact
      await callContact(contact, context: context);

      // After call, ask if we should call the next contact
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Called ${contact['name']}'),
            duration: const Duration(seconds: 2),
          ),
        );

        // Only show the dialog if there are more contacts to call
        if (currentIndex < contacts.length - 1) {
          final response = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Emergency Call'),
              content: Text('Do you need to call the next contact?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No, Stop'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('Yes, Call Next'),
                ),
              ],
            ),
          );

          continueSequence = response ?? false;
        } else {
          continueSequence = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No more emergency contacts to call'),
            ),
          );
        }
      }

      currentIndex++;
    }
  }
}
