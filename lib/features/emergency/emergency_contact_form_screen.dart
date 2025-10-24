import 'package:flutter/material.dart';
import 'package:medbuddy/core/services/database_service.dart';
import 'package:medbuddy/core/theme/app_theme.dart';

class EmergencyContactFormScreen extends StatefulWidget {
  const EmergencyContactFormScreen({super.key});

  @override
  State<EmergencyContactFormScreen> createState() =>
      _EmergencyContactFormScreenState();
}

class _EmergencyContactFormScreenState
    extends State<EmergencyContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final DatabaseService _databaseService = DatabaseService.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveEmergencyContact() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if we already have 3 contacts
      final count = await _databaseService.getEmergencyContactsCount();
      if (count >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Maximum 3 emergency contacts allowed')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Save the contact
      await _databaseService.saveEmergencyContact({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'priority': count + 1, // Set priority based on existing contacts
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency contact added successfully')),
        );

        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving contact: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Emergency Contact'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Icon and instructions
                    const Icon(
                      Icons.emergency,
                      size: 80,
                      color: AppTheme.darkPurple,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Add a trusted emergency contact',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkPurple,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'These contacts will be called when you need urgent help',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Name',
                        hintText: 'Enter the name of your emergency contact',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a contact name';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 20),

                    // Phone field
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'Enter the phone number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a phone number';
                        }
                        if (!RegExp(r'^\d{10}$').hasMatch(
                            value.replaceAll(RegExp(r'[^0-9]'), ''))) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    ElevatedButton(
                      onPressed: _saveEmergencyContact,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Save Contact'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
