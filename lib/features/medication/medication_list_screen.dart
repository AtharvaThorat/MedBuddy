import 'package:flutter/material.dart';
import 'dart:io';
import 'package:medbuddy/core/theme/app_theme.dart';
import 'package:medbuddy/features/medication/add_medication_screen.dart';
import 'package:medbuddy/features/medication/medication_detail_screen.dart';
import 'package:medbuddy/core/models/medication.dart';
import 'package:medbuddy/core/services/database_service.dart';
import 'package:medbuddy/features/medication/medication_dose_screen.dart';

class MedicationListScreen extends StatefulWidget {
  const MedicationListScreen({super.key});

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  List<Medication> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedications();
  }

  Future<void> _loadMedications() async {
    setState(() => _isLoading = true);
    try {
      final medications = await _databaseService.getMedications();
      setState(() {
        _medications = medications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading medications: $e')));
    }
  }

  Future<void> _markDoseTaken(Medication medication) async {
    if (medication.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot log dose for this medication')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // The method returns a map with additional information
      final result = await _databaseService.insertDoseHistory(
        medication.id!,
        DateTime.now(),
        true,
      );

      // Check for potential overdose
      if (result['isPotentialOverdose'] == true) {
        _showOverdoseWarning(medication.name);
      }
      // Check if this is the right time to take the medication
      else if (result['isCorrectTime'] == false) {
        _showWrongTimeWarning();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dose logged successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh the medications list
      _loadMedications();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging dose: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markDoseSkipped(Medication medication) async {
    if (medication.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot log dose for this medication')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _databaseService.insertDoseHistory(
        medication.id!,
        DateTime.now(),
        false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skipped dose logged successfully'),
          backgroundColor: Colors.orange,
        ),
      );

      // Refresh the medications list
      _loadMedications();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error logging skipped dose: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showOverdoseWarning(String medicationName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'OVERDOSE WARNING',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'You have already taken all scheduled doses of $medicationName today. Taking more could lead to an overdose!',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'I UNDERSTAND',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showWrongTimeWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Timing Alert',
          style: TextStyle(color: Colors.orange),
        ),
        content: const Text(
          'This is not the scheduled time to take this medication. Are you sure you want to record it now?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dose recorded outside of scheduled time'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('RECORD ANYWAY'),
          ),
        ],
      ),
    );
  }

  void _navigateToMedicationDetail(Medication medication) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicationDetailScreen(medication: medication),
      ),
    );
    if (result == true) {
      _loadMedications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Medications')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medications.isEmpty
              ? _buildEmptyState()
              : _buildMedicationList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddMedicationScreen(),
            ),
          );
          if (result == true) {
            _loadMedications();
          }
        },
        backgroundColor: AppTheme.darkPurple,
        child: const Icon(Icons.add, color: Colors.black87),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.medication_outlined,
            size: 100,
            color: AppTheme.lightPurple,
          ),
          const SizedBox(height: 16),
          const Text(
            'No medications added yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to add your first medication',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddMedicationScreen(),
                ),
              );
              if (result == true) {
                _loadMedications();
              }
            },
            child: const Text('Add Medication'),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _medications.length,
      itemBuilder: (context, index) {
        final medication = _medications[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 3,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () => _navigateToMedicationDetail(medication),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: medication.frontImagePath != null &&
                                medication.frontImagePath!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(medication.frontImagePath!),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.medication,
                                size: 50,
                                color: Colors.grey.shade400,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medication.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              medication.purpose ?? 'No purpose specified',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.schedule,
                                  size: 20,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  medication.frequency,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.date_range,
                                  size: 20,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  medication.schedule,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, size: 24),
                        onPressed: () =>
                            _navigateToMedicationDetail(medication),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
              Material(
                color: AppTheme.darkPurple,
                child: InkWell(
                  onTap: () => _navigateToDoseLogScreen(medication),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.medication_liquid,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'LOG DOSE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToDoseLogScreen(Medication medication) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MedicationDoseScreen(
          medication: medication,
          onDoseLogged: () => _loadMedications(),
        ),
      ),
    );
  }
}
