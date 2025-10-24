import 'dart:io';

import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:medbuddy/core/models/medication.dart';
import 'package:medbuddy/core/services/database_service.dart';

class MedicationDetailScreen extends StatefulWidget {
  final Medication? medication;

  const MedicationDetailScreen({
    super.key,
    this.medication,
  });

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _dosageController;
  late TextEditingController _scheduleController;
  late TextEditingController _purposeController;
  late TextEditingController _notesController;

  // Additional time controllers for multiple dosages per day
  List<TimeOfDay> _doseTimes = [TimeOfDay(hour: 8, minute: 0)];
  int _numDoses = 1;

  // Doctor information
  late TextEditingController _doctorController;

  File? _frontImageFile;
  File? _backImageFile;
  bool _isLoading = false;
  bool _showFrontImage = true;
  List<Map<String, dynamic>> _doseHistory = [];

  // Add new controllers for text recognition and TTS
  final FlutterTts _flutterTts = FlutterTts();
  final TextRecognizer _textRecognizer = TextRecognizer();
  String _recognizedText = '';
  bool _showRecognizedText = false;
  bool _isSpeaking = false;
  Map<String, dynamic>? _lastDoseResult;

  // Add new state variables for frequency
  String _selectedFrequency = 'daily';
  int _intervalDays = 2; // Default every 2 days
  List<int> _selectedDaysOfWeek = [1, 3, 5]; // Default Mon, Wed, Fri

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.medication?.name ?? '');
    _dosageController =
        TextEditingController(text: widget.medication?.dosage ?? '');
    _scheduleController =
        TextEditingController(text: widget.medication?.schedule ?? '');
    _purposeController =
        TextEditingController(text: widget.medication?.purpose ?? '');
    _notesController =
        TextEditingController(text: widget.medication?.notes ?? '');
    _doctorController = TextEditingController(text: '');

    if (widget.medication != null) {
      _loadDoseHistory();

      // Set up dose times from schedule string
      if (widget.medication!.schedule.isNotEmpty) {
        setState(() {
          final scheduleParts = widget.medication!.schedule.split(',');
          _numDoses = scheduleParts.length;
          _doseTimes = scheduleParts.map((timeStr) {
            // Parse time like "8:00 AM" into TimeOfDay
            final parts = timeStr.trim().split(' ');
            final timeParts = parts[0].split(':');
            int hour = int.tryParse(timeParts[0]) ?? 8;
            final int minute = int.tryParse(timeParts[1]) ?? 0;

            // Convert to 24-hour format if PM
            if (parts.length > 1 && parts[1] == 'PM' && hour < 12) {
              hour += 12;
            } else if (parts.length > 1 && parts[1] == 'AM' && hour == 12) {
              hour = 0;
            }

            return TimeOfDay(hour: hour, minute: minute);
          }).toList();
        });
      }

      if (widget.medication!.frontImagePath != null) {
        _frontImageFile = File(widget.medication!.frontImagePath!);
      }

      if (widget.medication!.backImagePath != null) {
        _backImageFile = File(widget.medication!.backImagePath!);
      }

      // Initialize frequency fields
      _selectedFrequency = widget.medication!.frequency;

      if (widget.medication!.intervalDays != null) {
        _intervalDays = widget.medication!.intervalDays!;
      }

      if (widget.medication!.daysOfWeek != null) {
        _selectedDaysOfWeek = widget.medication!.daysOfWeek!;
      }
    }

    // Initialize TTS
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  // Helper method to format scheduled times
  String? _formatScheduleTimes() {
    if (widget.medication?.schedule == null ||
        widget.medication!.schedule.isEmpty) {
      return null;
    }

    return widget.medication!.schedule;
  }

  Future<void> _loadDoseHistory() async {
    if (widget.medication?.id == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final history = await DatabaseService.instance
          .getDoseHistoryForMedication(widget.medication!.id!);
      setState(() {
        _doseHistory = history;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading dose history: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMedication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Build schedule string from dose times
      String scheduleString = _doseTimes.map((time) {
        final hour = time.hour;
        final minute = time.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12
            ? hour - 12
            : hour == 0
                ? 12
                : hour;
        return '$displayHour:$minute $period';
      }).join(', ');

      final medication = Medication(
        id: widget.medication?.id,
        name: _nameController.text,
        dosage: _dosageController.text,
        schedule: scheduleString,
        purpose:
            _purposeController.text.isEmpty ? null : _purposeController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        frontImagePath: _frontImageFile?.path,
        backImagePath: _backImageFile?.path,
        frequency: _selectedFrequency,
        intervalDays: _selectedFrequency == 'custom' ? _intervalDays : null,
        daysOfWeek: _selectedFrequency == 'weekly' ? _selectedDaysOfWeek : null,
      );

      if (widget.medication?.id == null) {
        await DatabaseService.instance.saveMedication(medication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medication saved successfully')),
          );
          await _flutterTts.speak('Medication added successfully');
          Navigator.pop(context, true);
        }
      } else {
        await DatabaseService.instance.updateMedication(medication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Medication updated successfully')),
          );
          await _flutterTts.speak('Medication updated successfully');
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving medication: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteMedication() async {
    if (widget.medication?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Medication'),
        content: const Text('Are you sure you want to delete this medication?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseService.instance.deleteMedication(widget.medication!.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medication deleted successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting medication: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanMedication() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_frontImageFile != null) {
        await _processImageForText(_frontImageFile!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Please take a front image of the medication first')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning medication: $e')),
      );
    }
  }

  Future<void> _pickImage(ImageSource source, bool isFrontImage) async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          if (isFrontImage) {
            _frontImageFile = File(pickedFile.path);
          } else {
            _backImageFile = File(pickedFile.path);
          }
        });

        if (isFrontImage && source == ImageSource.camera) {
          await _processImageForText(File(pickedFile.path));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _showImagePickerOptions(bool isFrontImage) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a picture'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isFrontImage);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isFrontImage);
              },
            ),
            if ((isFrontImage && _frontImageFile != null) ||
                (!isFrontImage && _backImageFile != null))
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove image',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    if (isFrontImage) {
                      _frontImageFile = null;
                    } else {
                      _backImageFile = null;
                    }
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _updateNumDoses(int value) {
    setState(() {
      _numDoses = value;

      // Update dose times
      if (_doseTimes.length < value) {
        // Add new times
        while (_doseTimes.length < value) {
          _doseTimes.add(
              TimeOfDay(hour: 8 + (_doseTimes.length * 4) % 24, minute: 0));
        }
      } else if (_doseTimes.length > value) {
        // Remove extra times
        _doseTimes = _doseTimes.sublist(0, value);
      }
    });
  }

  Future<void> _selectTime(BuildContext context, int index) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _doseTimes[index],
    );

    if (pickedTime != null && pickedTime != _doseTimes[index]) {
      setState(() {
        _doseTimes[index] = pickedTime;
      });
    }
  }

  Future<void> _logDoseTaken() async {
    if (widget.medication?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the medication first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // The new method returns a map with additional information
      final result = await DatabaseService.instance.insertDoseHistory(
        widget.medication!.id!,
        DateTime.now(),
        true,
      );

      setState(() {
        _lastDoseResult = result;
      });

      await _loadDoseHistory();

      if (mounted) {
        // Check for potential overdose
        if (result['isPotentialOverdose'] == true) {
          _showOverdoseWarning();
        }

        // Check if this is the right time to take the medication
        if (result['isCorrectTime'] == false) {
          _showWrongTimeWarning();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dose logged successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging dose: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _logDoseSkipped() async {
    if (widget.medication?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the medication first')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await DatabaseService.instance.insertDoseHistory(
        widget.medication!.id!,
        DateTime.now(),
        false,
      );

      await _loadDoseHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Skipped dose logged successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging skipped dose: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add text recognition function
  Future<void> _processImageForText(File imageFile) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      setState(() {
        _recognizedText = recognizedText.text;
        _showRecognizedText = true;
        _isLoading = false;
      });

      // Analyze the recognized text for medication information
      _analyzeMedicationText(_recognizedText);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing text: $e')),
      );
    }
  }

  void _analyzeMedicationText(String text) {
    // Look for common medication information patterns
    final namePattern =
        RegExp(r'name[:\s]+([A-Za-z0-9\s\-]+)', caseSensitive: false);
    final dosagePattern = RegExp(
        r'(dosage|dose|strength)[:\s]+([0-9]+\s*[a-z]+)',
        caseSensitive: false);
    final frequencyPattern = RegExp(
        r'(frequency|take)[:\s]+(once|twice|three times|[0-9]+\s*times)',
        caseSensitive: false);

    final nameMatch = namePattern.firstMatch(text);
    final dosageMatch = dosagePattern.firstMatch(text);
    final frequencyMatch = frequencyPattern.firstMatch(text);

    bool foundInfo = false;

    if (nameMatch != null && nameMatch.group(1)!.trim().isNotEmpty) {
      _nameController.text = nameMatch.group(1)!.trim();
      foundInfo = true;
    }

    if (dosageMatch != null && dosageMatch.group(2)!.trim().isNotEmpty) {
      _dosageController.text = dosageMatch.group(2)!.trim();
      foundInfo = true;
    }

    // Convert frequency text to schedule times
    if (frequencyMatch != null) {
      final frequency = frequencyMatch.group(2)!.toLowerCase().trim();
      if (frequency.contains('once')) {
        _updateNumDoses(1);
        foundInfo = true;
      } else if (frequency.contains('twice')) {
        _updateNumDoses(2);
        foundInfo = true;
      } else if (frequency.contains('three')) {
        _updateNumDoses(3);
        foundInfo = true;
      } else {
        // Try to parse a number
        final numPattern = RegExp(r'([0-9]+)');
        final numMatch = numPattern.firstMatch(frequency);
        if (numMatch != null) {
          final numDoses = int.tryParse(numMatch.group(1)!) ?? 1;
          _updateNumDoses(numDoses.clamp(1, 5));
          foundInfo = true;
        }
      }
    }

    if (foundInfo) {
      _speakText(
          "Medication information detected: ${_nameController.text}, ${_dosageController.text}");
    } else {
      _speakText(
          "No medication information detected. Please enter details manually.");
    }
  }

  Future<void> _speakText(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }

    setState(() {
      _isSpeaking = true;
    });

    await _flutterTts.speak(text);
  }

  void _showOverdoseWarning() {
    _speakText(
        "Warning! Potential overdose detected. You have already taken the maximum doses for today.");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title:
            const Text('OVERDOSE WARNING', style: TextStyle(color: Colors.red)),
        content: const Text(
          'You have already taken all scheduled doses of this medication today. Taking more could lead to an overdose!',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I UNDERSTAND',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showWrongTimeWarning() {
    _speakText(
        "This is not the scheduled time to take this medication. Please check your schedule.");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title:
            const Text('Timing Alert', style: TextStyle(color: Colors.orange)),
        content: const Text(
          'This is not the scheduled time to take this medication. Are you sure you want to take it now?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I\'LL WAIT'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dose taken outside of scheduled time'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('TAKE ANYWAY'),
          ),
        ],
      ),
    );
  }

  // Add helper methods for days of week
  String _getDayName(int day) {
    switch (day) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  void _toggleDaySelection(int day) {
    setState(() {
      if (_selectedDaysOfWeek.contains(day)) {
        _selectedDaysOfWeek.remove(day);
      } else {
        _selectedDaysOfWeek.add(day);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _scheduleController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    _doctorController.dispose();
    _flutterTts.stop();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medication == null
            ? 'Add Medication'
            : widget.medication!.name),
        actions: widget.medication != null
            ? [
                IconButton(
                  icon: const Icon(Icons.qr_code),
                  onPressed: _generateBarcode,
                  tooltip: 'Generate Barcode',
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                  tooltip: 'Scan Barcode',
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Camera scanner section
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Scan Medicine',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Take a clear picture of your medication to automatically identify it',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _pickImage(ImageSource.camera, true),
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Front'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _pickImage(ImageSource.camera, false),
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('Back'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Image section
                        if (_frontImageFile != null || _backImageFile != null)
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Medication Images',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      TextButton.icon(
                                        icon: Icon(
                                          Icons.medication,
                                          color: _showFrontImage
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey,
                                        ),
                                        label: Text(
                                          'Front',
                                          style: TextStyle(
                                            color: _showFrontImage
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey,
                                          ),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _showFrontImage = true;
                                          });
                                        },
                                      ),
                                      TextButton.icon(
                                        icon: Icon(
                                          Icons.medication_liquid,
                                          color: !_showFrontImage
                                              ? Theme.of(context).primaryColor
                                              : Colors.grey,
                                        ),
                                        label: Text(
                                          'Back',
                                          style: TextStyle(
                                            color: !_showFrontImage
                                                ? Theme.of(context).primaryColor
                                                : Colors.grey,
                                          ),
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _showFrontImage = false;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _showImagePickerOptions(
                                        _showFrontImage),
                                    child: Center(
                                      child: Container(
                                        width: 200,
                                        height: 200,
                                        decoration: BoxDecoration(
                                          border:
                                              Border.all(color: Colors.grey),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: _showFrontImage
                                            ? (_frontImageFile != null
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: Image.file(
                                                      _frontImageFile!,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : const Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(Icons.add_a_photo,
                                                            size: 40),
                                                        SizedBox(height: 8),
                                                        Text('Add Front Image'),
                                                      ],
                                                    ),
                                                  ))
                                            : (_backImageFile != null
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    child: Image.file(
                                                      _backImageFile!,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  )
                                                : const Center(
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Icon(Icons.add_a_photo,
                                                            size: 40),
                                                        SizedBox(height: 8),
                                                        Text('Add Back Image'),
                                                      ],
                                                    ),
                                                  )),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Form fields
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Medication Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Medication Name',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.medication),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a medication name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _dosageController,
                                  decoration: const InputDecoration(
                                    labelText: 'Dosage',
                                    border: OutlineInputBorder(),
                                    hintText: 'Example: 10mg, 2 tablets, etc.',
                                    prefixIcon: Icon(Icons.scale),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a dosage';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _purposeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Purpose (Optional)',
                                    border: OutlineInputBorder(),
                                    hintText: 'What condition does this treat?',
                                    prefixIcon: Icon(Icons.healing),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Scheduling section
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dosage Schedule',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Number of doses per day
                                Row(
                                  children: [
                                    const Text('Doses per day:'),
                                    const SizedBox(width: 16),
                                    DropdownButton<int>(
                                      value: _numDoses,
                                      items: [1, 2, 3, 4, 5].map((int value) {
                                        return DropdownMenuItem<int>(
                                          value: value,
                                          child: Text(value.toString()),
                                        );
                                      }).toList(),
                                      onChanged: (int? newValue) {
                                        if (newValue != null) {
                                          _updateNumDoses(newValue);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Time selection
                                Column(
                                  children: List.generate(_numDoses, (index) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          Text('Dose ${index + 1}:'),
                                          const SizedBox(width: 16),
                                          ElevatedButton(
                                            onPressed: () =>
                                                _selectTime(context, index),
                                            child: Text(_formatTimeOfDay(
                                                _doseTimes[index])),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Frequency section
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Medication Frequency',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Frequency selection
                                DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'How often to take',
                                  ),
                                  value: _selectedFrequency,
                                  items: [
                                    DropdownMenuItem(
                                        value: 'daily', child: Text('Daily')),
                                    DropdownMenuItem(
                                        value: 'weekly', child: Text('Weekly')),
                                    DropdownMenuItem(
                                        value: 'custom',
                                        child: Text('Every X days')),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedFrequency = value!;
                                    });
                                  },
                                ),

                                const SizedBox(height: 16),

                                // Show relevant fields based on frequency
                                if (_selectedFrequency == 'weekly')
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Select days of the week:'),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        children: List.generate(7, (index) {
                                          final day = index + 1; // 1-7
                                          final isSelected =
                                              _selectedDaysOfWeek.contains(day);
                                          return FilterChip(
                                            label: Text(_getDayName(day)),
                                            selected: isSelected,
                                            selectedColor: Theme.of(context)
                                                .primaryColor
                                                .withOpacity(0.25),
                                            onSelected: (_) =>
                                                _toggleDaySelection(day),
                                          );
                                        }),
                                      ),
                                    ],
                                  )
                                else if (_selectedFrequency == 'custom')
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('Take every'),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 80,
                                            child: DropdownButtonFormField<int>(
                                              value: _intervalDays,
                                              items: [2, 3, 4, 5, 6, 7, 14, 28]
                                                  .map((int value) {
                                                return DropdownMenuItem<int>(
                                                  value: value,
                                                  child: Text(value.toString()),
                                                );
                                              }).toList(),
                                              onChanged: (int? newValue) {
                                                if (newValue != null) {
                                                  setState(() {
                                                    _intervalDays = newValue;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('days'),
                                        ],
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Additional information
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Additional Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _doctorController,
                                  decoration: const InputDecoration(
                                    labelText: 'Doctor (Optional)',
                                    border: OutlineInputBorder(),
                                    hintText: "Doctor's name",
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _notesController,
                                  decoration: const InputDecoration(
                                    labelText: 'Notes (Optional)',
                                    border: OutlineInputBorder(),
                                    hintText: 'Any additional information',
                                    prefixIcon: Icon(Icons.note),
                                  ),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Add recognized text card if text was recognized
                        if (_showRecognizedText && _recognizedText.isNotEmpty)
                          Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Recognized Text',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.volume_up),
                                        onPressed: () =>
                                            _speakText(_recognizedText),
                                        tooltip: 'Read aloud',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_recognizedText),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _showRecognizedText = false;
                                      });
                                    },
                                    icon: const Icon(Icons.close),
                                    label: const Text('Dismiss'),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Scan button after camera section
                        if (_frontImageFile != null && !_showRecognizedText)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.document_scanner),
                                label: const Text('Scan & Extract Text',
                                    style: TextStyle(fontSize: 16)),
                                onPressed: _scanMedication,
                              ),
                            ),
                          ),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveMedication,
                            child: Text(
                              widget.medication == null
                                  ? 'Save Medication'
                                  : 'Update Medication',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final format = DateFormat.jm(); // "6:00 AM"
    return format.format(dt);
  }

  Future<void> _generateBarcode() async {
    if (widget.medication?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please save the medication first')),
      );
      return;
    }

    // Creating a unique ID for this medication with all necessary info
    final medData = {
      'id': widget.medication!.id,
      'name': widget.medication!.name,
      'dosage': widget.medication!.dosage,
    };

    final barcodeData = Uri.encodeComponent(medData.toString());

    // Show barcode in dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan this barcode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Use this to quickly identify your medication'),
            const SizedBox(height: 20),
            BarcodeWidget(
              barcode: Barcode.qrCode(),
              data: barcodeData,
              width: 200,
              height: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    await _speakText("Barcode generated for ${widget.medication!.name}");
  }

  Future<void> _scanBarcode() async {
    try {
      final result = await BarcodeScanner.scan();
      if (result.rawContent.isNotEmpty) {
        try {
          final decodedData = Uri.decodeComponent(result.rawContent);
          // Parse the medication data
          if (decodedData.contains('id') && decodedData.contains('name')) {
            // Extract id from the string
            final idRegex = RegExp(r'id: ([^,}]+)');
            final idMatch = idRegex.firstMatch(decodedData);

            if (idMatch != null) {
              final medId = idMatch.group(1)?.trim();
              if (medId != null) {
                // Look up the medication
                try {
                  // Try to get the medication from database
                  final medication =
                      await DatabaseService.instance.getMedicationById(medId);

                  if (medication != null) {
                    // Navigate to the medication details
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MedicationDetailScreen(
                            medication: medication,
                          ),
                        ),
                      );
                    }

                    await _speakText("Found medication ${medication.name}");
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Medication not found in database')),
                    );
                    await _speakText("Medication not found in database");
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error finding medication: $e')),
                  );
                }
              }
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invalid barcode format: $e')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning barcode: $e')),
      );
    }
  }
}
