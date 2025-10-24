import 'package:flutter/material.dart';
import 'package:medbuddy/core/services/database_service.dart';
import 'package:medbuddy/core/services/emergency_service.dart';
import 'package:medbuddy/core/theme/app_theme.dart';
import 'package:medbuddy/features/emergency/emergency_contact_form_screen.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  final EmergencyService _emergencyService = EmergencyService.instance;
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  bool _isCallingContacts = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final contacts = await _databaseService.getEmergencyContacts();
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  Future<void> _navigateToAddContact() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EmergencyContactFormScreen(),
      ),
    );

    if (result == true) {
      _loadContacts();
    }
  }

  Future<void> _editContact(Map<String, dynamic> contact) async {
    // Show edit dialog - you could create a separate edit screen for this
    final nameController = TextEditingController(text: contact['name']);
    final phoneController = TextEditingController(text: contact['phone']);

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter contact name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter phone number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty || phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter both name and phone number')),
                );
                return;
              }

              Navigator.pop(context, {
                'name': name,
                'phone': phone,
              });
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        await _databaseService.updateEmergencyContact({
          'id': contact['id'],
          'name': result['name'],
          'phone': result['phone'],
          'priority': contact['priority'],
        });

        await _loadContacts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving contact: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteContact(Map<String, dynamic> contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
            'Are you sure you want to remove ${contact['name']} from your emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _databaseService.deleteEmergencyContact(contact['id']);

        // Reorder priorities for remaining contacts
        final remainingContacts =
            _contacts.where((c) => c['id'] != contact['id']).toList();
        for (int i = 0; i < remainingContacts.length; i++) {
          await _databaseService.updateEmergencyContact({
            'id': remainingContacts[i]['id'],
            'name': remainingContacts[i]['name'],
            'phone': remainingContacts[i]['phone'],
            'priority': i + 1,
          });
        }

        await _loadContacts();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting contact: $e')),
          );
        }
      }
    }
  }

  Future<void> _updatePriority(int oldIndex, int newIndex) async {
    try {
      final List<Map<String, dynamic>> reorderedContacts = List.from(_contacts);
      final item = reorderedContacts.removeAt(oldIndex);
      reorderedContacts.insert(newIndex, item);

      // Update priorities in database
      for (int i = 0; i < reorderedContacts.length; i++) {
        await _databaseService.updateEmergencyContact({
          'id': reorderedContacts[i]['id'],
          'name': reorderedContacts[i]['name'],
          'phone': reorderedContacts[i]['phone'],
          'priority': i + 1,
        });
      }

      await _loadContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating priorities: $e')),
        );
      }
    }
  }

  Future<void> _callEmergencyContacts() async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No emergency contacts available')),
      );
      return;
    }

    setState(() {
      _isCallingContacts = true;
    });

    try {
      await _emergencyService.startEmergencyCallSequence(context);
    } finally {
      if (mounted) {
        setState(() {
          _isCallingContacts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _contacts.isEmpty
                      ? _buildEmptyState()
                      : _buildContactsList(),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed:
                          _isCallingContacts ? null : _callEmergencyContacts,
                      icon: const Icon(Icons.phone),
                      label: const Text('Call Emergency Contacts'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: _contacts.length < 3
          ? FloatingActionButton(
              onPressed: _navigateToAddContact,
              backgroundColor: AppTheme.darkPurple,
              tooltip: 'Add Emergency Contact',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contact_phone,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No emergency contacts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add up to 3 emergency contacts',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddContact,
            icon: const Icon(Icons.add),
            label: const Text('Add First Contact'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkPurple,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactsList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contacts.length,
      onReorder: (oldIndex, newIndex) {
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        _updatePriority(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        return Card(
          key: Key('contact_${contact['id']}'),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.darkPurple,
              child: Text(
                (index + 1).toString(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              contact['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(contact['phone']),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editContact(contact),
                  tooltip: 'Edit Contact',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteContact(contact),
                  tooltip: 'Delete Contact',
                  color: Colors.red,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
