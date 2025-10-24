import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:medbuddy/core/services/database_service.dart' as core_db;
import 'package:medbuddy/core/services/image_comparison_service.dart';
import 'package:medbuddy/core/theme/app_theme.dart';
import 'package:medbuddy/shared/models/medication.dart';
import 'package:medbuddy/shared/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AddMedicationScreen extends StatefulWidget {
  final Medication? medication;

  const AddMedicationScreen({super.key, this.medication});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _purposeController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  File? _frontImage;
  File? _backImage;
  bool _isEditing = false;
  bool _isLoading = false;
  List<MedicationTime> _scheduledTimes = [MedicationTime(8, 0)];

  final DatabaseService _databaseService = DatabaseService();
  final ImageComparisonService _comparisonService = ImageComparisonService();
  final core_db.DatabaseService _coreDbService =
      core_db.DatabaseService.instance;

  final FlutterTts _tts = FlutterTts();
  List<Map<String, dynamic>> _emergencyContacts = [];
  bool _loadingContacts = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.medication != null;
    if (_isEditing) {
      _nameController.text = widget.medication!.name;
      _purposeController.text = widget.medication!.purpose;
      _dosageController.text = widget.medication!.dosageInstructions;
      _frequencyController.text = widget.medication!.frequency;
      _notesController.text = widget.medication?.additionalNotes ?? '';
      _startDate = widget.medication!.startDate;
      _endDate = widget.medication!.endDate;
      _scheduledTimes = widget.medication!.scheduledTimes;

      if (widget.medication?.frontImagePath != null) {
        _frontImage = File(widget.medication!.frontImagePath!);
      }

      if (widget.medication?.backImagePath != null) {
        _backImage = File(widget.medication!.backImagePath!);
      }
    }

    _loadEmergencyContacts();
    _initTts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purposeController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    _notesController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _pickImage(bool isFrontImage) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        if (isFrontImage) {
          _frontImage = File(image.path);
        } else {
          _backImage = File(image.path);
        }
      });
    }
  }

  Future<void> _takePicture(bool isFrontImage) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      setState(() {
        if (isFrontImage) {
          _frontImage = File(image.path);
        } else {
          _backImage = File(image.path);
        }
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime initialDate = isStartDate ? _startDate : _endDate;
    final DateTime firstDate = isStartDate ? DateTime.now() : _startDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before new start date, update it
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 7));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay initialTime = TimeOfDay(
      hour: _scheduledTimes[index].hour,
      minute: _scheduledTimes[index].minute,
    );

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      setState(() {
        final updatedTimes = List<MedicationTime>.from(_scheduledTimes);
        updatedTimes[index] = MedicationTime(picked.hour, picked.minute);
        _scheduledTimes = updatedTimes;
      });
    }
  }

  void _addScheduledTime() {
    setState(() {
      _scheduledTimes.add(MedicationTime(12, 0)); // Default to noon
    });
  }

  void _removeScheduledTime(int index) {
    if (_scheduledTimes.length > 1) {
      setState(() {
        _scheduledTimes.removeAt(index);
      });
    }
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final medication = Medication(
          id: _isEditing ? widget.medication!.id : null,
          name: _nameController.text,
          purpose: _purposeController.text,
          dosageInstructions: _dosageController.text,
          frequency: _frequencyController.text,
          frontImagePath: _frontImage?.path,
          backImagePath: _backImage?.path,
          additionalNotes:
              _notesController.text.isEmpty ? null : _notesController.text,
          startDate: _startDate,
          endDate: _endDate,
          scheduledTimes: _scheduledTimes,
        );

        String medicationId;
        if (_isEditing) {
          await _databaseService.updateMedication(medication);
          medicationId = medication.id;
          await _tts.speak('Med_Updated ');
        } else {
          medicationId = await _databaseService.insertMedication(medication);
          await _tts.speak('Med_Added');
        }

        // Extract and save image features for pill identification
        await _processImages(medicationId, medication);

        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.pop(context, true);
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving medication: $e')),
          );
        }
      }
    }
  }

  Future<void> _processImages(
      String medicationId, Medication medication) async {
    try {
      // Get the app's document directory for permanent storage
      final appDir = await getApplicationDocumentsDirectory();
      final featureDir =
          Directory(path.join(appDir.path, 'medication_features'));

      // Create the directory if it doesn't exist
      if (!await featureDir.exists()) {
        await featureDir.create(recursive: true);
      }

      // Convert string ID to int for core database service
      final int medicationIdInt =
          int.tryParse(medicationId) ?? medicationId.hashCode.abs();

      // Now also create a core medication record if it doesn't exist
      try {
        final existingMed = await _coreDbService.getMedication(medicationIdInt);
        if (existingMed == null) {
          await _coreDbService.insertMedicationWithId(
            medicationIdInt,
            medication.name,
            medication.dosageInstructions,
            'Every day at ${medication.scheduledTimes.first.formatTime()}',
            medication.purpose,
            medication.frontImagePath,
            medication.backImagePath,
            medication.frequency,
          );
        }
      } catch (e) {
        // Error handling without print
      }

      // Process images in background
      if (_frontImage != null && await _frontImage!.exists()) {
        final featurePath =
            path.join(featureDir.path, 'front_features_$medicationId.json');
        await compute(_processImageInBackground, {
          'imagePath': _frontImage!.path,
          'featurePath': featurePath,
          'medicationId': medicationIdInt,
          'side': 'front',
          'comparisonService': _comparisonService,
          'coreDbService': _coreDbService,
        });
      }

      if (_backImage != null && await _backImage!.exists()) {
        final featurePath =
            path.join(featureDir.path, 'back_features_$medicationId.json');
        await compute(_processImageInBackground, {
          'imagePath': _backImage!.path,
          'featurePath': featurePath,
          'medicationId': medicationIdInt,
          'side': 'back',
          'comparisonService': _comparisonService,
          'coreDbService': _coreDbService,
        });
      }

      // Verify if features were saved
      try {
        await _coreDbService.getAllMedicationImageFeatures();
      } catch (e) {
        // Error handling without print
      }
    } catch (e) {
      // Error handling without print
    }
  }

  static Future<void> _processImageInBackground(
      Map<String, dynamic> params) async {
    final imagePath = params['imagePath'] as String;
    final featurePath = params['featurePath'] as String;
    final medicationId = params['medicationId'] as int;
    final side = params['side'] as String;
    final comparisonService =
        params['comparisonService'] as ImageComparisonService;
    final coreDbService = params['coreDbService'] as core_db.DatabaseService;

    try {
      // Extract features
      await comparisonService.extractAndSaveFeatures(imagePath, featurePath);

      // Save features to core database
      await coreDbService.saveMedicationImageFeatures(
        medicationId,
        side,
        '${side}_image_${path.basename(imagePath)}',
        featurePath,
      );
    } catch (e) {
      // Error handling without print
    }
  }

  Future<void> _loadEmergencyContacts() async {
    setState(() {
      _loadingContacts = true;
    });

    try {
      final contacts = await _coreDbService.getEmergencyContacts();
      setState(() {
        _emergencyContacts = contacts;
        _loadingContacts = false;
      });
    } catch (e) {
      setState(() {
        _loadingContacts = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _speakText(String text) async {
    await _tts.speak(text);
  }

  Future<void> _callEmergencyContact() async {
    if (_loadingContacts) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading contacts, please wait...')),
      );
      return;
    }

    if (_emergencyContacts.isEmpty) {
      await _loadEmergencyContacts();

      if (_emergencyContacts.isEmpty) {
        _showAddContactDialog();
        return;
      }
    }

    // Show list of contacts to call
    final contact = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Call Emergency Contact'),
        content: SizedBox(
          width: double.maxFinite,
          child: _emergencyContacts.isEmpty
              ? const Text('No emergency contacts found. Add one first.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: _emergencyContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _emergencyContacts[index];
                    return ListTile(
                      title: Text(contact['name']),
                      subtitle: Text(contact['phone']),
                      onTap: () => Navigator.pop(context, contact),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _showAddContactDialog,
            child: const Text('Add Contact'),
          ),
        ],
      ),
    );

    if (contact != null) {
      await _callContact(contact);
    }
  }

  Future<void> _callContact(Map<String, dynamic> contact) async {
    await _speakText("Calling ${contact['name']}");

    final Uri phoneUri = Uri(scheme: 'tel', path: contact['phone']);
    try {
      await launchUrl(phoneUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error making call: $e')),
        );
      }
    }
  }

  Future<void> _showAddContactDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter contact name',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter phone number',
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
          TextButton(
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
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // Check if we already have 3 contacts
        final count = await _coreDbService.getEmergencyContactsCount();
        if (count >= 3) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Maximum 3 emergency contacts allowed')),
            );
          }
          return;
        }

        await _coreDbService.saveEmergencyContact({
          'name': result['name'],
          'phone': result['phone'],
          'priority': count + 1, // Set priority based on existing contacts
        });

        await _loadEmergencyContacts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Emergency contact added successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving contact: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Medication' : 'Add Medication'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildImageSection(),
                    const SizedBox(height: 24),
                    _buildFormFields(),
                    const SizedBox(height: 24),
                    _buildDateSection(),
                    const SizedBox(height: 24),
                    _buildScheduleSection(),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkPurple,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Text(
                        _isEditing ? 'Update Medication' : 'Save Medication',
                      ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _callEmergencyContact,
        backgroundColor: Colors.red,
        tooltip: 'Call Emergency Contact',
        child: const Icon(Icons.call, color: Colors.white),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Medicine Images',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Front image column
            Column(
              children: [
                GestureDetector(
                  onTap: () => _pickImage(true),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _frontImage != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  _frontImage!,
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Front',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: AppTheme.lightPurple,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Front of Medicine',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => _pickImage(true),
                      icon: const Icon(Icons.photo_library),
                      color: AppTheme.lightPurple,
                      tooltip: 'Gallery',
                    ),
                    IconButton(
                      onPressed: () => _takePicture(true),
                      icon: const Icon(Icons.camera_alt),
                      color: AppTheme.lightPink,
                      tooltip: 'Camera',
                    ),
                  ],
                ),
              ],
            ),

            // Back image column
            Column(
              children: [
                GestureDetector(
                  onTap: () => _pickImage(false),
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: AppTheme.lightGreen,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _backImage != null
                        ? Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  _backImage!,
                                  width: 140,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: const Text(
                                    'Back',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: AppTheme.lightPurple,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Back of Medicine',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: () => _pickImage(false),
                      icon: const Icon(Icons.photo_library),
                      color: AppTheme.lightPurple,
                      tooltip: 'Gallery',
                    ),
                    IconButton(
                      onPressed: () => _takePicture(false),
                      icon: const Icon(Icons.camera_alt),
                      color: AppTheme.lightPink,
                      tooltip: 'Camera',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Medication Name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.medication),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a medication name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _purposeController,
          decoration: const InputDecoration(
            labelText: 'Purpose',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.healing),
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter the purpose of this medication';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _dosageController,
          decoration: const InputDecoration(
            labelText: 'Dosage Instructions',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.medical_information),
            hintText: 'e.g., 1 tablet twice daily after meals',
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter dosage instructions';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _frequencyController,
          decoration: const InputDecoration(
            labelText: 'Frequency',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.schedule),
            hintText: 'e.g., Every 8 hours, Once daily',
          ),
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter frequency of use';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Additional Notes (Optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.note),
            hintText: 'Any additional information',
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Treatment Duration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Start Date',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM d, y').format(_startDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'End Date',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM d, y').format(_endDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Duration: ${_endDate.difference(_startDate).inDays + 1} days',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _addScheduledTime,
                  icon: const Icon(Icons.add_circle),
                  color: AppTheme.darkPurple,
                  tooltip: 'Add time',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // List of scheduled times
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _scheduledTimes.length,
              itemBuilder: (context, index) {
                return Card(
                  color: AppTheme.lightGreen.withOpacity(0.3),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(
                      Icons.access_time,
                      color: AppTheme.darkPurple,
                    ),
                    title: Text(
                      _scheduledTimes[index].formatTime(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _selectTime(context, index),
                          color: Colors.blue,
                        ),
                        if (_scheduledTimes.length > 1)
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _removeScheduledTime(index),
                            color: Colors.red,
                          ),
                      ],
                    ),
                    onTap: () => _selectTime(context, index),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap on a time to edit it. You can add multiple times for complex medication schedules.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
