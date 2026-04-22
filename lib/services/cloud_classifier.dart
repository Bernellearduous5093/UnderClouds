import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/cloud_type.dart';

class ClassificationResult {
  final CloudType cloudType;
  final double confidence;
  final double normalizedEntropy; // 0.0–1.0
  final CloudType? secondType;
  final double? secondConfidence;

  const ClassificationResult({
    required this.cloudType,
    required this.confidence,
    required this.normalizedEntropy,
    this.secondType,
    this.secondConfidence,
  });
}

class _PreprocessInput {
  final String imagePath;
  _PreprocessInput(this.imagePath);
}

class _PreprocessOutput {
  final Float32List tensor;
  _PreprocessOutput(this.tensor);
}

// Runs in a separate isolate via compute()
Future<Float32List> _preprocessImage(_PreprocessInput input) async {
  final bytes = await File(input.imagePath).readAsBytes();
  img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Failed to decode image');

  // Center square crop
  final side = min(decoded.width, decoded.height);
  final x = (decoded.width - side) ~/ 2;
  final y = (decoded.height - side) ~/ 2;
  final cropped = img.copyCrop(decoded, x: x, y: y, width: side, height: side);

  // Resize to 224x224
  final resized = img.copyResize(cropped, width: 224, height: 224);

  // Convert to Float32List normalized to [0, 1]
  final tensor = Float32List(1 * 224 * 224 * 3);
  int idx = 0;
  for (int row = 0; row < 224; row++) {
    for (int col = 0; col < 224; col++) {
      final pixel = resized.getPixel(col, row);
      tensor[idx++] = pixel.r / 255.0;
      tensor[idx++] = pixel.g / 255.0;
      tensor[idx++] = pixel.b / 255.0;
    }
  }
  return tensor;
}

class CloudClassifier {
  CloudClassifier._();
  static final CloudClassifier instance = CloudClassifier._();

  Interpreter? _interpreter;
  List<String>? _labels;
  bool _loading = false;

  Future<void> warmUp() async {
    await _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (_interpreter != null) return;
    if (_loading) {
      while (_loading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    _loading = true;
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/cloud_classifier.tflite',
      );
      final labelData = await rootBundle.loadString(
        'assets/models/cloud_labels.txt',
      );
      _labels = labelData
          .trim()
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } finally {
      _loading = false;
    }
  }

  Future<ClassificationResult> classify(String imagePath) async {
    await _ensureLoaded();
    final interpreter = _interpreter!;
    final labels = _labels!;

    final tensor = await _preprocessImage(_PreprocessInput(imagePath));

    // Shape: [1, 224, 224, 3]
    final input = tensor.reshape([1, 224, 224, 3]);
    final output = List.filled(labels.length, 0.0).reshape([1, labels.length]);

    interpreter.run(input, output);

    final scores = (output[0] as List).cast<double>();

    // Normalized entropy: 0 = all probability on one class, 1 = uniform
    double entropy = 0;
    for (final p in scores) {
      if (p > 0) entropy -= p * log(p);
    }
    final normalizedEntropy = entropy / log(scores.length);

    // Find top-2 indices
    final indexed = List.generate(scores.length, (i) => MapEntry(i, scores[i]));
    indexed.sort((a, b) => b.value.compareTo(a.value));

    final topType = cloudTypeFromLabel(labels[indexed[0].key]);
    final topConf = indexed[0].value;

    CloudType? secondType;
    double? secondConf;
    if (indexed.length > 1) {
      secondType = cloudTypeFromLabel(labels[indexed[1].key]);
      secondConf = indexed[1].value;
    }

    return ClassificationResult(
      cloudType: topType,
      confidence: topConf,
      normalizedEntropy: normalizedEntropy.clamp(0.0, 1.0),
      secondType: secondType,
      secondConfidence: secondConf,
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
