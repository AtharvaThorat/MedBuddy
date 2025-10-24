import 'dart:io';

import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medbuddy/core/models/medication.dart';
import 'package:medbuddy/core/services/database_service.dart';
import 'package:medbuddy/core/services/image_comparison_service.dart';
import 'package:medbuddy/features/medication/medication_detail_screen.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class PillIdentificationScreen extends StatefulWidget {
  const PillIdentificationScreen({super.key});

  @override
  State<PillIdentificationScreen> createState() =>
      _PillIdentificationScreenState();
}

class _PillIdentificationScreenState extends State<PillIdentificationScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final DatabaseService _databaseService = DatabaseService.instance;
  final ImageComparisonService _comparisonService = ImageComparisonService();
  final TextEditingController _searchController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();

  File? _selectedImage;
  bool _isProcessing = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _identificationResults = [];
  bool _showDebugInfo = false;
  String _debugInfo = '';
  bool _isSearching = false;

  // Adjustable similarity threshold for pill image matching
  static const double _similarityThreshold = 0.1; // Lowered for testing, adjust as needed

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speakText(String text) async {
    await _flutterTts.speak(text);
  }

  void _addDebugInfo(String info) {
    setState(() {
      _debugInfo += '$info\n';
    });
  }

  Future<void> _searchMedicationByText() async {
    final searchText = _searchController.text.trim();
    if (searchText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a search term')),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _identificationResults = [];
      _errorMessage = null;
    });

    try {
      await _speakText("Searching for $searchText");

      // Search for medications that match the text
      final allMeds = await _databaseService.getMedications();
      final results = <Map<String, dynamic>>[];

      for (var med in allMeds) {
        // Check if medication name, dosage, or purpose contains the search text
        if (med.name.toLowerCase().contains(searchText.toLowerCase()) ||
            med.dosage.toLowerCase().contains(searchText.toLowerCase()) ||
            (med.purpose != null &&
                med.purpose!
                    .toLowerCase()
                    .contains(searchText.toLowerCase()))) {
          results.add({
            'id': med.id,
            'name': med.name,
            'dosage': med.dosage,
            'purpose': med.purpose,
            'similarity': 1.0, // Set to 1.0 for text match
            'medication': med,
          });
        }
      }

      setState(() {
        _identificationResults = results;
        _isSearching = false;
        if (results.isEmpty) {
          _errorMessage = 'No medications found matching "$searchText"';
          _speakText('No medications found matching your search');
        } else {
          _speakText(
              'Found ${results.length} medications matching your search');
        }
      });
      // Add TTS for first result, similar to QR scan
      if (results.isNotEmpty) {
        final med = results.first['medication'] as Medication;
        final nextDose = _getNextDoseTime(med);
        final nextDoseText = nextDose != null
            ? 'Next dose at ${_formatMedicationTime(nextDose)}.'
            : 'No scheduled doses.';
        final purpose = (med.purpose != null && med.purpose.toString().trim().isNotEmpty)
            ? med.purpose.toString()
            : 'Purpose not mentioned.';
        final dosage = med.dosage ?? ((med as dynamic).dosageInstructions ?? 'Dosage not mentioned.');
        final ttsText = 'Medication identified: ${med.name}. '
            '$nextDoseText '
            'Dosage: $dosage. '
            'Purpose: $purpose';
        await _speakText(ttsText);
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'Error searching for medications: $e';
      });

      _speakText('Error searching for medications');
    }
  }

  Future<void> _getImageFromSource(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _errorMessage = null;
          _identificationResults = [];
        });

        // Automatically start identification when an image is selected
        _identifyPill();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting image: ${e.toString()}';
      });
    }
  }

  Future<void> _identifyPill() async {
    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Please select an image of a pill first';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _identificationResults = [];
      _debugInfo = ''; // Clear debug info
    });

    try {
      _addDebugInfo('Starting pill identification process...');

      // Get application documents directory for feature extraction
      final appDir = await getApplicationDocumentsDirectory();
      final tempPath = path.join(appDir.path, 'temp_query_features.json');

      _addDebugInfo('Selected image path: ${_selectedImage!.path}');
      _addDebugInfo('Temporary features will be saved to: $tempPath');

      // Extract features from the input image
      try {
        await _comparisonService.extractAndSaveFeatures(
          _selectedImage!.path,
          tempPath,
        );
        _addDebugInfo('Successfully extracted features from the input image');
      } catch (e) {
        _addDebugInfo('Error extracting features from input image: $e');
        throw Exception(
            'Failed to extract features from the selected image: $e');
      }

      // Get all medication image features from the database
      final allFeatures =
          await _databaseService.getAllMedicationImageFeatures();
      _addDebugInfo(
          'Found ${allFeatures.length} feature entries in the database');

      if (allFeatures.isEmpty) {
        _addDebugInfo('No medication features found in database!');
        setState(() {
          _identificationResults = [];
          _isProcessing = false;
          _errorMessage =
              'No medications with images found in the database. Add medications with images first.';
        });

        // Delete temporary file
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        return;
      }

      List<Map<String, dynamic>> results = [];

      // Check if feature files exist
      for (var feature in allFeatures) {
        final featurePath = feature['feature_path'] as String;
        final featureFile = File(featurePath);

        if (!await featureFile.exists()) {
          _addDebugInfo('Feature file does not exist: $featurePath');
          continue;
        }

        _addDebugInfo(
            'Processing feature for medication ${feature['medication_id']}');
        final medicationId = feature['medication_id'] as int;

        // Get the medication details
        try {
          final medication = await _databaseService.getMedication(medicationId);

          if (medication == null) {
            _addDebugInfo('Could not find medication with ID: $medicationId');
            continue;
          }

          _addDebugInfo('Comparing with medication: ${medication.name}');

          // Compare features
          try {
            final similarity =
                await _comparisonService.compareFeatures(tempPath, featurePath);

            _addDebugInfo('Similarity score with ${medication.name}: $similarity');

            // Add to potential matches if similarity is above threshold
            if (similarity > _similarityThreshold) {
              results.add({
                'id': medication.id,
                'name': medication.name,
                'dosage': medication.dosage,
                'purpose': medication.purpose,
                'similarity': similarity,
                'medication': medication,
              });
              _addDebugInfo(
                  'Added to potential matches with score: $similarity');
            } else {
              _addDebugInfo('Below threshold ($_similarityThreshold), not adding to results');
            }
          } catch (e) {
            _addDebugInfo('Error comparing features: $e');
          }
        } catch (e) {
          _addDebugInfo('Error retrieving medication $medicationId: $e');
        }
      }

      // Sort by similarity (highest first)
      results.sort((a, b) =>
          (b['similarity'] as double).compareTo(a['similarity'] as double));

      _addDebugInfo('Found ${results.length} potential matches');

      // Limit to top 5 results
      if (results.length > 5) {
        results = results.sublist(0, 5);
      }

      setState(() {
        _identificationResults = results;
        _isProcessing = false;
        if (results.isEmpty) {
          _errorMessage = 'No matching medications found.';
        }
      });

      // Delete temporary file
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (e) {
      _addDebugInfo('Error in identification process: $e');
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Error identifying medication: ${e.toString()}';
      });
    }
  }

  Future<void> _scanQRCode() async {
    try {
      final result = await BarcodeScanner.scan();
      if (result.rawContent.isNotEmpty) {
        // Get medications from database
        final medications = await _databaseService.getMedications();

        // Debug: print scanned content and medication IDs
        print('Scanned QR: \\${result.rawContent}');
        print('Medication IDs: \\${medications.map((m) => m.id).toList()}');

        // Decode the QR code content
        final decodedContent = Uri.decodeComponent(result.rawContent);
        print('Decoded QR: $decodedContent');

        // Try to extract ID from QR code content if it contains more than just the ID
        final idRegex = RegExp(r'id: ([^,}]+)');
        final idMatch = idRegex.firstMatch(decodedContent);
        String? scannedId;
        if (idMatch != null) {
          scannedId = idMatch.group(1)?.trim();
        } else {
          scannedId = decodedContent;
        }
        print('Extracted scannedId: $scannedId');

        // Find matching medication (compare as strings)
        Medication? matchingMedication = medications.firstWhereOrNull(
          (med) => med.id.toString() == scannedId,
        );

        if (matchingMedication != null) {
          setState(() {
            _identificationResults = [
              {
                'id': matchingMedication.id,
                'name': matchingMedication.name,
                'dosage': matchingMedication.dosage ?? ((matchingMedication as dynamic).dosageInstructions),
                'purpose': matchingMedication.purpose,
                'similarity': 1.0, // 100% match for QR
                'medication': matchingMedication,
              }
            ];
            _errorMessage = null;
          });
          // TTS: name, next dose, dosage, purpose
          final nextDose = _getNextDoseTime(matchingMedication);
          final nextDoseText = nextDose != null
              ? 'Next dose at ${_formatMedicationTime(nextDose)}.'
              : 'No scheduled doses.';
          final purpose = (matchingMedication.purpose != null && matchingMedication.purpose.toString().trim().isNotEmpty)
              ? matchingMedication.purpose.toString()
              : 'Purpose not mentioned.';
          final dosage = matchingMedication.dosage ?? ((matchingMedication as dynamic).dosageInstructions ?? 'Dosage not mentioned.');
          final ttsText = 'Medication identified: ${matchingMedication.name}. '
              '$nextDoseText '
              'Dosage: $dosage. '
              'Purpose: $purpose';
          await _speakText(ttsText);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No medication found with this ID')),
            );
          }
        }

        print('Comparing med.id: \\${matchingMedication?.id.toString()} with scannedId: \\$scannedId');
        print('med.id type: \\${matchingMedication?.id.runtimeType}, scannedId type: \\${scannedId.runtimeType}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning QR code: \\$e')),
        );
      }
    }
  }

  // Refactored: Only save dose if user confirms 'Take anyway'.
  Future<void> _markDoseTaken(Medication medication) async {
    if (medication.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medication ID not found')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Check for potential overdose and timing BEFORE saving
      final result = await DatabaseService.instance.checkDoseAllowed(
        medication.id!,
        DateTime.now(),
      );

      setState(() {
        _isProcessing = false;
      });

      if (result['isPotentialOverdose'] == true) {
        _showOverdoseWarning(medication.name, onTakeAnyway: () async {
          await _saveDose(medication, isOutsideSchedule: false);
        });
      } else if (result['isCorrectTime'] == false) {
        _showWrongTimeWarning(medication, onTakeAnyway: () async {
          await _saveDose(medication, isOutsideSchedule: true);
        });
      } else {
        await _saveDose(medication, isOutsideSchedule: false);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging dose: $e')),
      );
    }
  }

  // Helper to actually save dose and update history
  Future<void> _saveDose(Medication medication, {required bool isOutsideSchedule}) async {
    setState(() {
      _isProcessing = true;
    });
    try {
      await DatabaseService.instance.insertDoseHistory(
        medication.id!,
        DateTime.now(),
        true,
      );
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOutsideSchedule
              ? 'Dose taken outside of scheduled time'
              : 'Dose logged successfully'),
          backgroundColor: isOutsideSchedule ? Colors.orange : Colors.green,
        ),
      );
      await _speakText(isOutsideSchedule
          ? 'Patient selected to take medicine'
          : 'Dose logged successfully');
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging dose: $e')),
      );
    }
  }

  // Overdose warning dialog with callback
  void _showOverdoseWarning(String medicationName, {VoidCallback? onTakeAnyway}) {
    _speakText(
        "Warning! Potential overdose detected. You have already taken the maximum doses for today.");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('OVERDOSE WARNING', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(
          'You have already taken all scheduled doses of $medicationName today. Taking more could lead to an overdose!',
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _speakText('Scheduled time is over for today.');
            },
            child: const Text('I\'LL WAIT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          if (onTakeAnyway != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _speakText('Patient selected to take medicine');
                onTakeAnyway();
              },
              child: const Text('TAKE ANYWAY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ),
        ],
      ),
    );
  }

  // Timing warning dialog with callback
  void _showWrongTimeWarning(Medication medication, {VoidCallback? onTakeAnyway}) {
    final nextDose = _getNextDoseTime(medication);
    final nextDoseText = nextDose != null ? _formatMedicationTime(nextDose) : 'unknown';
    _speakText(
        "This is not the scheduled time to take this medication. Please check your schedule.");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timing Alert', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Text(
          'This is not the scheduled time to take this medication. Are you sure you want to take it now?',
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _speakText('Scheduled time is $nextDoseText');
            },
            child: const Text('I\'LL WAIT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
          if (onTakeAnyway != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _speakText('Patient selected to take medicine');
                onTakeAnyway();
              },
              child: const Text('TAKE ANYWAY', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            ),
        ],
      ),
    );
  }

  // Helper to get next scheduled dose time
  TimeOfDay? _getNextDoseTime(dynamic medication) {
    try {
      // Try scheduledTimes if it exists and is a List
      if (medication != null &&
          (medication as dynamic).scheduledTimes != null &&
          (medication as dynamic).scheduledTimes is List) {
        final times = List.from((medication as dynamic).scheduledTimes);
        if (times.isEmpty) return null;
        times.sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
        final now = TimeOfDay.now();
        for (final t in times) {
          if (t != null && (t.hour > now.hour || (t.hour == now.hour && t.minute > now.minute))) {
            return TimeOfDay(hour: t.hour, minute: t.minute);
          }
        }
        final first = times.first;
        return first != null ? TimeOfDay(hour: first.hour, minute: first.minute) : null;
      }
    } catch (e) {
      print('Error accessing scheduledTimes: $e');
      // Ignore and fall back to schedule string
    }
    // Fallback: parse schedule string (core/models/medication.dart)
    if (medication != null && medication.schedule != null && medication.schedule is String) {
      final schedule = medication.schedule as String;
      final parts = schedule.split(',').map((e) => e.trim()).toList();
      final now = TimeOfDay.now();
      List<TimeOfDay> times = [];
      for (final part in parts) {
        try {
          final timeParts = part.split(' ');
          if (timeParts.length == 2) {
            final hourMinute = timeParts[0].split(':');
            int hour = int.parse(hourMinute[0]);
            int minute = int.parse(hourMinute[1]);
            if (timeParts[1].toLowerCase() == 'pm' && hour < 12) hour += 12;
            if (timeParts[1].toLowerCase() == 'am' && hour == 12) hour = 0;
            times.add(TimeOfDay(hour: hour, minute: minute));
          }
        } catch (_) {}
      }
      if (times.isEmpty) return null;
      times.sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));
      for (final t in times) {
        if ((t.hour > now.hour || (t.hour == now.hour && t.minute > now.minute))) {
          return t;
        }
      }
      final first = times.first;
      return first;
    }
    return null;
  }

  String _formatMedicationTime(TimeOfDay time) {
    final hour12 = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = time.minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $period';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Pill Identification'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Text search section
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Search by Name',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Enter medication name',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.search),
                                ),
                                onSubmitted: (_) => _searchMedicationByText(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _searchMedicationByText,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 16),
                              ),
                              child: const Text('Search'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Or use image recognition below',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildImageSelectionArea(),
                const SizedBox(height: 20),
                if (_selectedImage != null) _buildActionButtons(),
                if (_errorMessage != null) _buildErrorMessage(),
                if (_identificationResults.isNotEmpty)
                  _buildIdentificationResults(),
                if (_showDebugInfo) _buildDebugInfo(),
              ],
            ),
          ),
        ),
        if (_isProcessing || _isSearching) _buildLoadingOverlay(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Identifying medication...',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('This may take a moment'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSelectionArea() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Take or Select a Photo of Your Medication',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_selectedImage != null)
              _buildSelectedImage()
            else
              _buildImagePlaceholder(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                    onPressed: () => _getImageFromSource(ImageSource.camera),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                    onPressed: () => _getImageFromSource(ImageSource.gallery),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR Code'),
              onPressed: _scanQRCode,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImage() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _selectedImage!,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 64, color: Colors.grey),
            SizedBox(height: 8),
            Text('No image selected'),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.search),
          label: const Text('Identify Medication'),
          onPressed: _identifyPill,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.refresh),
          label: const Text('Use Different Image'),
          onPressed: () {
            setState(() {
              _selectedImage = null;
              _errorMessage = null;
              _identificationResults = [];
            });
          },
        ),
        TextButton.icon(
          icon: Icon(_showDebugInfo ? Icons.visibility_off : Icons.visibility),
          label: Text(_showDebugInfo ? 'Hide Debug Info' : 'Show Debug Info'),
          onPressed: () {
            setState(() {
              _showDebugInfo = !_showDebugInfo;
            });
          },
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Card(
        color: Colors.red[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[700]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red[700]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentificationResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Identification Results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _identificationResults.length,
                  itemBuilder: (context, index) {
                    final medicationData = _identificationResults[index];
                    final medication =
                        medicationData['medication'] as Medication;
                    final similarity =
                        (medicationData['similarity'] as double) * 100;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(medication.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Purpose: ${medication.purpose}'),
                                Text('Dosage: ${medication.dosage}'),
                                Text(
                                    'Match confidence: ${similarity.toStringAsFixed(0)}%'),
                              ],
                            ),
                            leading: medication.frontImagePath != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      File(medication.frontImagePath!),
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : CircleAvatar(
                                    child: Text('${index + 1}'),
                                  ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.info_outline),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            MedicationDetailScreen(
                                          medication: medication,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.check),
                                    label: const Text('Take Dose'),
                                    onPressed: () => _markDoseTaken(medication),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDebugInfo() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debug Information',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                child: Text(
                  _debugInfo,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _flutterTts.stop();
    super.dispose();
  }
}
