import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:medbuddy/core/services/image_comparison_service.dart';
import 'package:medbuddy/core/services/database_service.dart';
import 'package:medbuddy/features/medication/medication_detail_screen.dart';
import 'package:medbuddy/core/models/medication.dart';
import 'package:flutter/foundation.dart';

class IdentificationScreen extends StatefulWidget {
  const IdentificationScreen({super.key});

  @override
  State<IdentificationScreen> createState() => _IdentificationScreenState();
}

class _IdentificationScreenState extends State<IdentificationScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;
  bool _hasResult = false;
  List<Map<String, dynamic>> _matchResults = [];
  final ImageComparisonService _comparisonService = ImageComparisonService();
  bool _showDebugInfo = false;
  String _debugInfo = '';

  void _addDebugInfo(String info) {
    if (mounted) {
      setState(() {
        _debugInfo += '$info\n';
      });
    }
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _hasResult = false;
          _matchResults = [];
        });

        // Process the image to identify the medication
        _identifyMedication();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  Future<void> _identifyMedication() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
      _hasResult = false;
      _matchResults = [];
      _debugInfo = ''; // Clear debug info
    });

    try {
      _addDebugInfo('Starting pill identification process...');

      // Get application documents directory for feature extraction
      final appDir = await getApplicationDocumentsDirectory();
      final tempPath = path.join(appDir.path, 'temp_query_features.json');

      _addDebugInfo('Selected image path: ${_selectedImage!.path}');
      _addDebugInfo('Temporary features will be saved to: $tempPath');

      // Extract features from the input image in background
      try {
        await compute(_extractFeaturesInBackground, {
          'imagePath': _selectedImage!.path,
          'featurePath': tempPath,
          'comparisonService': _comparisonService,
        });
        _addDebugInfo('Successfully extracted features from the input image');
      } catch (e) {
        _addDebugInfo('Error extracting features from input image: $e');
        throw Exception(
            'Failed to extract features from the selected image: $e');
      }

      // Get all medication image features from the database
      final allFeatures =
          await DatabaseService.instance.getAllMedicationImageFeatures();
      _addDebugInfo(
          'Found ${allFeatures.length} feature entries in the database');

      if (allFeatures.isEmpty) {
        _addDebugInfo('No medication features found in database!');
        setState(() {
          _matchResults = [];
          _hasResult = true;
          _isProcessing = false;
        });

        // Delete temporary file
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        return;
      }

      // Process features in background
      final results = await compute(_processFeaturesInBackground, {
        'allFeatures': allFeatures,
        'tempPath': tempPath,
        'comparisonService': _comparisonService,
        'databaseService': DatabaseService.instance,
      });

      // Sort by similarity (highest first)
      results.sort((a, b) =>
          (b['similarity'] as double).compareTo(a['similarity'] as double));

      setState(() {
        _matchResults = results;
        _hasResult = true;
        _isProcessing = false;
      });

      // Delete temporary file
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error identifying medication: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pill Identification'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Identify Your Medication',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Take a photo or select an image of your medication to identify it.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _getImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _getImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_selectedImage != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Selected Image',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImage!,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isProcessing)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing image and comparing with database...'),
                      ],
                    ),
                  ),
                ),
              if (_hasResult) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          _matchResults.isEmpty
                              ? 'No matches found'
                              : 'Potential Matches',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        if (_matchResults.isEmpty)
                          const Text(
                            'No medications in your database match this pill. Add this medication to your records first.',
                            textAlign: TextAlign.center,
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _matchResults.length,
                            itemBuilder: (context, index) {
                              final medicationData = _matchResults[index];
                              final medication =
                                  medicationData['medication'] as Medication;
                              final similarity =
                                  (medicationData['similarity'] as double) *
                                      100;

                              return ListTile(
                                title: Text(medication.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Dosage: ${medication.dosage}'),
                                    Text(
                                        'Match confidence: ${similarity.toStringAsFixed(0)}%'),
                                  ],
                                ),
                                leading: CircleAvatar(
                                  child: Text('${index + 1}'),
                                ),
                                onTap: () {
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
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                if (_hasResult && _matchResults.isEmpty) ...[
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showDebugInfo = !_showDebugInfo;
                      });
                    },
                    child: Text(
                        _showDebugInfo ? 'Hide Debug Info' : 'Show Debug Info'),
                  ),
                  if (_showDebugInfo) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          _debugInfo,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Add these static methods for background processing
  static Future<void> _extractFeaturesInBackground(
      Map<String, dynamic> params) async {
    final imagePath = params['imagePath'] as String;
    final featurePath = params['featurePath'] as String;
    final comparisonService =
        params['comparisonService'] as ImageComparisonService;

    await comparisonService.extractAndSaveFeatures(imagePath, featurePath);
  }

  static Future<List<Map<String, dynamic>>> _processFeaturesInBackground(
      Map<String, dynamic> params) async {
    final allFeatures = params['allFeatures'] as List<Map<String, dynamic>>;
    final tempPath = params['tempPath'] as String;
    final comparisonService =
        params['comparisonService'] as ImageComparisonService;
    final databaseService = params['databaseService'] as DatabaseService;

    List<Map<String, dynamic>> results = [];

    for (var feature in allFeatures) {
      final featurePath = feature['feature_path'] as String;
      final featureFile = File(featurePath);

      if (!await featureFile.exists()) {
        continue;
      }

      final medicationId = feature['medication_id'] as int;

      try {
        final medication = await databaseService.getMedication(medicationId);

        if (medication == null) {
          continue;
        }

        final similarity =
            await comparisonService.compareFeatures(tempPath, featurePath);

        if (similarity > 0.3) {
          results.add({
            'id': medication.id,
            'name': medication.name,
            'dosage': medication.dosage,
            'purpose': medication.purpose,
            'similarity': similarity,
            'medication': medication,
          });
        }
      } catch (e) {
        // Error handling without print
      }
    }

    return results;
  }
}
