import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:medbuddy/core/models/medication.dart';
import 'package:medbuddy/core/services/database_service.dart';
import 'package:medbuddy/core/services/image_comparison_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class IdentificationResult {
  final Medication? medication;
  final double confidence;
  final String message;

  IdentificationResult({
    this.medication,
    required this.confidence,
    required this.message,
  });
}

class PillIdentificationService {
  final DatabaseService _databaseService = DatabaseService.instance;
  final ImageComparisonService _imageComparisonService =
      ImageComparisonService();

  /// Identifies a medication based on an image
  Future<IdentificationResult> identifyPill(String imagePath) async {
    try {
      // Extract features from the image
      final tempDir = await getTemporaryDirectory();
      final tempFeaturePath = path.join(tempDir.path, 'temp_features.json');

      await _imageComparisonService.extractAndSaveFeatures(
        imagePath,
        tempFeaturePath,
      );

      // Get all medication image features from the database
      final allFeatures =
          await _databaseService.getAllMedicationImageFeatures();

      if (allFeatures.isEmpty) {
        return IdentificationResult(
          confidence: 0.0,
          message: 'No medications with images found in the database',
        );
      }

      List<Map<String, dynamic>> results = [];

      // Compare with each stored medication
      for (var feature in allFeatures) {
        final featurePath = feature['feature_path'] as String;
        final medicationId = feature['medication_id'] as int;

        // Get the medication details
        final medication = await _databaseService.getMedication(medicationId);

        if (medication == null) continue;

        // Compare features
        final similarity = await _imageComparisonService.compareFeatures(
          tempFeaturePath,
          featurePath,
        );

        if (similarity > 0.5) {
          // Threshold for potential match
          results.add({
            'medication': medication,
            'similarity': similarity,
          });
        }
      }

      // Clean up temporary file
      final tempFile = File(tempFeaturePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      if (results.isEmpty) {
        return IdentificationResult(
          confidence: 0.0,
          message: 'No matching medications found',
        );
      }

      // Sort by similarity (highest first)
      results.sort((a, b) =>
          (b['similarity'] as double).compareTo(a['similarity'] as double));

      // Return the best match
      final bestMatch = results.first;
      final bestMedication = bestMatch['medication'] as Medication;
      final confidence = bestMatch['similarity'] as double;

      return IdentificationResult(
        medication: bestMedication,
        confidence: confidence,
        message: confidence > 0.7
            ? 'Strong match found'
            : 'Possible match found with medium confidence',
      );
    } catch (e) {
      return IdentificationResult(
        confidence: 0.0,
        message: 'Error identifying pill: $e',
      );
    }
  }

  /// Extracts image features for comparing medications
  Future<Map<String, dynamic>> extractImageFeatures(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    return {
      'color_histogram': await _extractColorHistogram(image),
      'average_color': _extractAverageColor(image),
      'edge_density': _extractEdgeDensity(image),
    };
  }

  /// Extracts a simple color histogram from the image
  Future<List<int>> _extractColorHistogram(img.Image image) async {
    // Create a histogram with 8 bins per channel (RGB)
    final bins = 8;
    final histogram = List<int>.filled(bins * 3, 0);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();

        // Map each RGB value to its appropriate bin
        final rBin = (r * bins ~/ 256);
        final gBin = (g * bins ~/ 256);
        final bBin = (b * bins ~/ 256);

        histogram[rBin]++;
        histogram[gBin + bins]++;
        histogram[bBin + 2 * bins]++;
      }
    }

    return histogram;
  }

  /// Extracts the average color of the image
  List<int> _extractAverageColor(img.Image image) {
    int totalR = 0, totalG = 0, totalB = 0;
    int pixelCount = 0;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        totalR += pixel.r.toInt();
        totalG += pixel.g.toInt();
        totalB += pixel.b.toInt();
        pixelCount++;
      }
    }

    if (pixelCount == 0) return [0, 0, 0];

    return [
      totalR ~/ pixelCount,
      totalG ~/ pixelCount,
      totalB ~/ pixelCount,
    ];
  }

  /// Extracts edge density as a measure of texture
  double _extractEdgeDensity(img.Image image) {
    int edgeCount = 0;
    final width = image.width;
    final height = image.height;

    // Simple edge detection by comparing adjacent pixels
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final center = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final bottom = image.getPixel(x, y + 1);

        // Convert to grayscale
        final centerGray =
            _rgbToGray(center.r.toInt(), center.g.toInt(), center.b.toInt());
        final rightGray =
            _rgbToGray(right.r.toInt(), right.g.toInt(), right.b.toInt());
        final bottomGray =
            _rgbToGray(bottom.r.toInt(), bottom.g.toInt(), bottom.b.toInt());

        // Check for significant change
        if ((centerGray - rightGray).abs() > 20 ||
            (centerGray - bottomGray).abs() > 20) {
          edgeCount++;
        }
      }
    }

    return edgeCount / ((width - 2) * (height - 2));
  }

  /// Converts RGB to grayscale value
  int _rgbToGray(int r, int g, int b) {
    return (0.299 * r + 0.587 * g + 0.114 * b).round();
  }
}
