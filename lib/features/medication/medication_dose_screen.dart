import 'dart:io';
import 'package:flutter/material.dart';
import 'package:medbuddy/core/models/medication.dart';
import 'package:medbuddy/core/services/database_service.dart';


class MedicationDoseScreen extends StatefulWidget {
  final Medication medication;
  final VoidCallback onDoseLogged;

  const MedicationDoseScreen({
    super.key,
    required this.medication,
    required this.onDoseLogged,
  });

  @override
  State<MedicationDoseScreen> createState() => _MedicationDoseScreenState();
}

class _MedicationDoseScreenState extends State<MedicationDoseScreen> {
  final DatabaseService _databaseService = DatabaseService.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Medication Dose'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Medication info card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: widget.medication.frontImagePath !=
                                              null &&
                                          widget.medication.frontImagePath!
                                              .isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(
                                            File(widget
                                                .medication.frontImagePath!),
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Icon(
                                          Icons.medication,
                                          size: 70,
                                          color: Colors.grey.shade400,
                                        ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.medication.name,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Dosage: ${widget.medication.dosage}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Schedule: ${widget.medication.schedule}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (widget.medication.purpose != null &&
                                widget.medication.purpose!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Text(
                                  'Purpose: ${widget.medication.purpose}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Information text
                    const Text(
                      'Did you take this medication?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Text(
                      'Select an option below to log your dose',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Dose action buttons
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton.icon(
                        onPressed: _markDoseTaken,
                        icon: const Icon(Icons.check_circle, size: 34),
                        label: const Text(
                          'YES, I\'VE TAKEN IT',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: ElevatedButton.icon(
                        onPressed: _markDoseSkipped,
                        icon: const Icon(Icons.cancel, size: 34),
                        label: const Text(
                          'NO, I\'M SKIPPING IT',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _markDoseTaken() async {
    if (widget.medication.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot log dose for this medication')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // The method returns a map with additional information
      final result = await _databaseService.insertDoseHistory(
        widget.medication.id!,
        DateTime.now(),
        true,
      );

      // Check for potential overdose
      if (result['isPotentialOverdose'] == true) {
        _showOverdoseWarning();
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

        // Call the callback to refresh medications in the previous screen
        widget.onDoseLogged();

        // Go back to previous screen
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging dose: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markDoseSkipped() async {
    if (widget.medication.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot log dose for this medication')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _databaseService.insertDoseHistory(
        widget.medication.id!,
        DateTime.now(),
        false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Skipped dose logged successfully'),
          backgroundColor: Colors.orange,
        ),
      );

      // Call the callback to refresh medications in the previous screen
      widget.onDoseLogged();

      // Go back to previous screen
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging skipped dose: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showOverdoseWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          'OVERDOSE WARNING',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          'You have already taken all scheduled doses of ${widget.medication.name} today. Taking more could lead to an overdose!',
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

              // Go back to previous screen
              Navigator.pop(context);

              // Call the callback to refresh medications
              widget.onDoseLogged();
            },
            child: const Text('RECORD ANYWAY'),
          ),
        ],
      ),
    );
  }
}
