import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;


class ImageComparisonService {
  /// An enhanced image feature extraction and comparison service.
  /// This implementation uses color histograms, edge detection, shape analysis,
  /// and texture features for comprehensive medication identification.

  static const int _histogramBins =
      16; // Increased bins for better color resolution
  static const int _edgeGridSize =
      12; // Increased grid size for more detailed edge analysis

  // Adjusted weights for different feature types
  static const double _colorHistogramWeight = 0.35;
  static const double _edgeWeight = 0.25;
  static const double _dominantColorWeight = 0.25;
  static const double _aspectRatioWeight = 0.15;

  /// Extracts features from an image and saves them to a JSON file
  Future<void> extractAndSaveFeatures(
      String imagePath, String outputPath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List bytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize image to normalize it
      final img.Image resizedImage =
          img.copyResize(image, width: 300, height: 300);

      // Apply preprocessing to improve feature extraction
      final img.Image processedImage = _preprocessImage(resizedImage);

      // Extract features
      final Map<String, dynamic> features = {
        'color_histogram': await _extractColorHistogram(processedImage),
        'edge_features': _extractEdgeFeatures(processedImage),
        'dominant_colors':
            _extractDominantColors(processedImage, 8), // Increased from 5 to 8
        'aspect_ratio': image.width / image.height,
        'average_color': _extractAverageColor(processedImage),
        'texture_features': _extractTextureFeatures(processedImage),
        'image_size': {'width': image.width, 'height': image.height},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Save features to file
      final File outputFile = File(outputPath);
      await outputFile.writeAsString(jsonEncode(features));
    } catch (e) {
      throw Exception('Feature extraction failed: $e');
    }
  }

  /// Preprocesses image to improve feature extraction
  img.Image _preprocessImage(img.Image image) {
    // Apply noise reduction
    final img.Image denoised = img.gaussianBlur(image, radius: 1);

    // Enhance contrast
    return img.contrast(denoised, contrast: 10);
  }

  /// Compares two feature sets and returns a similarity score (0.0 to 1.0)
  Future<double> compareFeatures(
      String featureFile1, String featureFile2) async {
    try {
      final String features1Json = await File(featureFile1).readAsString();
      final String features2Json = await File(featureFile2).readAsString();

      final Map<String, dynamic> features1 = jsonDecode(features1Json);
      final Map<String, dynamic> features2 = jsonDecode(features2Json);

      // Compare color histograms
      final List<int> hist1 = List<int>.from(features1['color_histogram']);
      final List<int> hist2 = List<int>.from(features2['color_histogram']);
      final double colorSimilarity = _compareHistograms(hist1, hist2);

      // Compare edge features
      final List<double> edges1 = List<double>.from(features1['edge_features']);
      final List<double> edges2 = List<double>.from(features2['edge_features']);
      final double edgeSimilarity = _compareEdgeFeatures(edges1, edges2);

      // Compare dominant colors
      final List<List<int>> dominantColors1 =
          (features1['dominant_colors'] as List)
              .map((color) => List<int>.from(color))
              .toList();
      final List<List<int>> dominantColors2 =
          (features2['dominant_colors'] as List)
              .map((color) => List<int>.from(color))
              .toList();
      final double colorPaletteSimilarity =
          _compareDominantColors(dominantColors1, dominantColors2);

      // Compare aspect ratios
      final double aspectRatio1 = features1['aspect_ratio'] as double;
      final double aspectRatio2 = features2['aspect_ratio'] as double;
      final double aspectRatioSimilarity = 1.0 -
          min(
              (aspectRatio1 - aspectRatio2).abs() /
                  max(aspectRatio1, aspectRatio2),
              1.0);

      // Compare average colors if available
      double avgColorSimilarity = 0.0;
      if (features1.containsKey('average_color') &&
          features2.containsKey('average_color')) {
        final List<int> avgColor1 = List<int>.from(features1['average_color']);
        final List<int> avgColor2 = List<int>.from(features2['average_color']);
        avgColorSimilarity = _compareColors(avgColor1, avgColor2);
      }

      // Compare texture features if available
      double textureSimilarity = 0.0;
      if (features1.containsKey('texture_features') &&
          features2.containsKey('texture_features')) {
        final List<double> texture1 =
            List<double>.from(features1['texture_features']);
        final List<double> texture2 =
            List<double>.from(features2['texture_features']);
        textureSimilarity = _compareVectors(texture1, texture2);
      }

      // Calculate weighted average of all features
      final double similarity = (colorSimilarity * _colorHistogramWeight) +
          (edgeSimilarity * _edgeWeight) +
          (colorPaletteSimilarity * _dominantColorWeight) +
          (aspectRatioSimilarity * _aspectRatioWeight) +
          (avgColorSimilarity * 0.1) + // Small weight for average color
          (textureSimilarity * 0.1); // Small weight for texture

      return similarity;
    } catch (e) {
      throw Exception('Feature comparison failed: $e');
    }
  }

  /// Extracts average color of the image
  List<int> _extractAverageColor(img.Image image) {
    int totalR = 0, totalG = 0, totalB = 0;
    final int totalPixels = image.width * image.height;

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        totalR += pixel.r.toInt();
        totalG += pixel.g.toInt();
        totalB += pixel.b.toInt();
      }
    }

    return [
      totalR ~/ totalPixels,
      totalG ~/ totalPixels,
      totalB ~/ totalPixels,
    ];
  }

  /// Extracts texture features using Haralick texture measures (simplified)
  List<double> _extractTextureFeatures(img.Image image) {
    // Convert to grayscale for texture analysis
    final img.Image grayImage = img.grayscale(image);

    // Calculate horizontal co-occurrence matrix (simplified)
    final List<double> features = List<double>.filled(5, 0.0);

    // Energy (uniformity)
    double energy = 0.0;
    // Contrast
    double contrast = 0.0;
    // Homogeneity
    double homogeneity = 0.0;

    for (int y = 0; y < grayImage.height; y++) {
      for (int x = 0; x < grayImage.width - 1; x++) {
        final int pixel1 = grayImage.getPixel(x, y).r.toInt();
        final int pixel2 = grayImage.getPixel(x + 1, y).r.toInt();

        // Calculate texture metrics
        final int diff = (pixel1 - pixel2).abs();
        contrast += diff * diff;
        homogeneity += 1.0 / (1.0 + diff);
        energy += pixel1 * pixel1;
      }
    }

    // Normalize by number of pixel pairs
    final double normalizer =
        (grayImage.width * grayImage.height - grayImage.height).toDouble();
    features[0] = energy / (grayImage.width * grayImage.height);
    features[1] = contrast / normalizer;
    features[2] = homogeneity / normalizer;

    // Add entropy and correlation placeholders (simplified)
    features[3] = 0.0;
    features[4] = 0.0;

    return features;
  }

  /// Extracts color histogram for RGB channels
  Future<List<int>> _extractColorHistogram(img.Image image) async {
    // Create a histogram with _histogramBins bins per channel (RGB)
    final List<int> histogram = List<int>.filled(_histogramBins * 3, 0);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();

        // Map each RGB value to its appropriate bin
        final int rBin = (r * _histogramBins ~/ 256);
        final int gBin = (g * _histogramBins ~/ 256);
        final int bBin = (b * _histogramBins ~/ 256);

        histogram[rBin]++;
        histogram[gBin + _histogramBins]++;
        histogram[bBin + 2 * _histogramBins]++;
      }
    }

    return histogram;
  }

  /// Extracts edge features by analyzing pixel intensity changes
  List<double> _extractEdgeFeatures(img.Image image) {
    final int cellWidth = image.width ~/ _edgeGridSize;
    final int cellHeight = image.height ~/ _edgeGridSize;
    final List<double> edgeFeatures =
        List<double>.filled(_edgeGridSize * _edgeGridSize, 0);

    // Convert to grayscale for edge detection
    final img.Image grayImage = img.grayscale(image);

    // Apply Sobel operator for better edge detection
    final img.Image edgeImage = img.sobel(grayImage);

    for (int gridY = 0; gridY < _edgeGridSize; gridY++) {
      for (int gridX = 0; gridX < _edgeGridSize; gridX++) {
        double edgeStrength = 0;
        final int startX = gridX * cellWidth;
        final int startY = gridY * cellHeight;
        final int endX = min(startX + cellWidth, image.width - 1);
        final int endY = min(startY + cellHeight, image.height - 1);

        for (int y = startY; y < endY; y++) {
          for (int x = startX; x < endX; x++) {
            final img.Pixel pixel = edgeImage.getPixel(x, y);
            // Edge image will have high values at edge points
            edgeStrength += pixel.r.toInt();
          }
        }

        // Normalize by cell size
        final int cellSize = (endX - startX) * (endY - startY);
        if (cellSize > 0) {
          edgeStrength /= cellSize;
        }

        edgeFeatures[gridY * _edgeGridSize + gridX] =
            edgeStrength / 255.0; // Normalize to [0,1]
      }
    }

    return edgeFeatures;
  }

  /// Extracts dominant colors from the image
  List<List<int>> _extractDominantColors(img.Image image, int colorCount) {
    // Improved implementation: Sample pixels and find most common colors
    final Map<int, int> colorFrequency = {};
    final int sampleStep =
        max(1, (image.width * image.height) ~/ 20000); // More samples

    for (int y = 0; y < image.height; y += sampleStep) {
      for (int x = 0; x < image.width; x += sampleStep) {
        final img.Pixel pixel = image.getPixel(x, y);
        final int r = pixel.r.toInt();
        final int g = pixel.g.toInt();
        final int b = pixel.b.toInt();

        // Quantize colors to reduce variations (less aggressive quantization)
        final int quantizedR = (r ~/ 16) * 16;
        final int quantizedG = (g ~/ 16) * 16;
        final int quantizedB = (b ~/ 16) * 16;

        final int quantizedColor =
            (quantizedR << 16) | (quantizedG << 8) | quantizedB;
        colorFrequency[quantizedColor] =
            (colorFrequency[quantizedColor] ?? 0) + 1;
      }
    }

    // Sort colors by frequency
    final List<MapEntry<int, int>> sortedColors = colorFrequency.entries
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Return top N colors as RGB lists
    final List<List<int>> dominantColors = [];
    for (int i = 0; i < min(colorCount, sortedColors.length); i++) {
      final int color = sortedColors[i].key;
      final int r = (color >> 16) & 0xFF;
      final int g = (color >> 8) & 0xFF;
      final int b = color & 0xFF;
      dominantColors.add([r, g, b]);
    }

    return dominantColors;
  }

  /// Compares two color histograms using correlation
  double _compareHistograms(List<int> hist1, List<int> hist2) {
    if (hist1.length != hist2.length) {
      return 0.0;
    }

    // Normalize histograms
    final List<double> normHist1 = _normalizeHistogram(hist1);
    final List<double> normHist2 = _normalizeHistogram(hist2);

    // Calculate correlation using cosine similarity
    return _calculateCosineSimilarity(normHist1, normHist2);
  }

  /// Calculate cosine similarity between two vectors
  double _calculateCosineSimilarity(List<double> vec1, List<double> vec2) {
    double dotProduct = 0;
    double norm1 = 0;
    double norm2 = 0;

    for (int i = 0; i < vec1.length; i++) {
      dotProduct += vec1[i] * vec2[i];
      norm1 += vec1[i] * vec1[i];
      norm2 += vec2[i] * vec2[i];
    }

    if (norm1 == 0 || norm2 == 0) {
      return 0.0;
    }

    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  /// Compares two vectors using cosine similarity
  double _compareVectors(List<double> vec1, List<double> vec2) {
    return _calculateCosineSimilarity(vec1, vec2);
  }

  /// Compares two edge feature sets with improved similarity measure
  double _compareEdgeFeatures(List<double> edges1, List<double> edges2) {
    if (edges1.length != edges2.length) {
      return 0.0;
    }

    // Use cosine similarity for edge features
    return _calculateCosineSimilarity(edges1, edges2);
  }

  /// Compares two color lists
  double _compareColors(List<int> color1, List<int> color2) {
    if (color1.length != 3 || color2.length != 3) {
      return 0.0;
    }

    // Calculate Euclidean distance in RGB space
    double distance = sqrt(pow(color1[0] - color2[0], 2) +
        pow(color1[1] - color2[1], 2) +
        pow(color1[2] - color2[2], 2));

    // Convert to similarity (0-1 range)
    return 1.0 -
        min(distance / 441.67, 1.0); // 441.67 = sqrt(255^2 + 255^2 + 255^2)
  }

  /// Compares two sets of dominant colors with improved matching
  double _compareDominantColors(
      List<List<int>> colors1, List<List<int>> colors2) {
    if (colors1.isEmpty || colors2.isEmpty) {
      return 0.0;
    }

    // Create all possible color pairs and find best matches
    double totalSimilarity = 0;
    int matchCount = 0;

    // For each color in the first set, find the best matching color in the second set
    for (final color1 in colors1) {
      double bestMatch = 0;
      for (final color2 in colors2) {
        final similarity = _compareColors(color1, color2);
        if (similarity > bestMatch) {
          bestMatch = similarity;
        }
      }

      if (bestMatch > 0.5) {
        // Only count good matches
        totalSimilarity += bestMatch;
        matchCount++;
      }
    }

    if (matchCount == 0) {
      return 0.0;
    }

    return totalSimilarity / matchCount;
  }

  /// Normalizes a histogram
  List<double> _normalizeHistogram(List<int> histogram) {
    final List<double> normalized = List<double>.filled(histogram.length, 0);
    final int sum = histogram.fold(0, (sum, value) => sum + value);

    if (sum == 0) {
      return normalized;
    }

    for (int i = 0; i < histogram.length; i++) {
      normalized[i] = histogram[i] / sum;
    }

    return normalized;
  }

  /// Converts RGB to grayscale
  int _rgbToGray(int r, int g, int b) {
    return (0.299 * r + 0.587 * g + 0.114 * b).round();
  }
}
