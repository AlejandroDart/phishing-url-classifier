double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic> _map(dynamic value) {
  return value is Map<String, dynamic> ? value : <String, dynamic>{};
}

class ModelInfo {
  const ModelInfo({
    required this.status,
    required this.validated,
    required this.model,
    required this.dataset,
    required this.metrics,
    required this.confusionMatrix,
    required this.features,
    required this.validation,
    required this.notes,
  });

  final String status;
  final bool validated;
  final ModelSummary model;
  final ModelDataset dataset;
  final ModelMetrics metrics;
  final ConfusionMatrixData confusionMatrix;
  final List<ModelFeature> features;
  final ModelValidation validation;
  final List<String> notes;

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    final rawNotes = json['notes'];
    return ModelInfo(
      status: (json['status'] ?? 'unknown').toString(),
      validated: json['validated'] == true,
      model: ModelSummary.fromJson(_map(json['model'])),
      dataset: ModelDataset.fromJson(_map(json['dataset'])),
      metrics: ModelMetrics.fromJson(_map(json['metrics'])),
      confusionMatrix: ConfusionMatrixData.fromJson(
        _map(json['confusion_matrix']),
      ),
      features: rawFeatures is List
          ? rawFeatures
              .whereType<Map<String, dynamic>>()
              .map(ModelFeature.fromJson)
              .toList()
          : const [],
      validation: ModelValidation.fromJson(_map(json['validation'])),
      notes: rawNotes is List
          ? rawNotes.map((item) => item.toString()).toList()
          : const [],
    );
  }
}

class ModelSummary {
  const ModelSummary({
    required this.id,
    required this.displayName,
    required this.technicalName,
    required this.version,
    required this.trainedAt,
    required this.artifactId,
    required this.framework,
    required this.frameworkVersion,
    required this.threshold,
    required this.estimators,
    required this.criterion,
    required this.classWeight,
    required this.maxFeatures,
    required this.randomState,
    required this.featureCount,
    required this.continuousFeatureCount,
    required this.description,
    required this.recommended,
  });

  final String id;
  final String displayName;
  final String technicalName;
  final String version;
  final DateTime? trainedAt;
  final String artifactId;
  final String framework;
  final String frameworkVersion;
  final double threshold;
  final int estimators;
  final String criterion;
  final String classWeight;
  final String maxFeatures;
  final int randomState;
  final int featureCount;
  final int continuousFeatureCount;
  final String description;
  final bool recommended;

  factory ModelSummary.fromJson(Map<String, dynamic> json) {
    return ModelSummary(
      id: (json['id'] ?? 'random_forest').toString(),
      displayName: (json['display_name'] ?? 'Modelo sin nombre').toString(),
      technicalName: (json['technical_name'] ?? '-').toString(),
      version: (json['version'] ?? '-').toString(),
      trainedAt: DateTime.tryParse(json['trained_at']?.toString() ?? ''),
      artifactId: (json['artifact_id'] ?? '-').toString(),
      framework: (json['framework'] ?? '-').toString(),
      frameworkVersion: (json['framework_version'] ?? '-').toString(),
      threshold: _toDouble(json['threshold']),
      estimators: _toInt(json['estimators']),
      criterion: (json['criterion'] ?? '-').toString(),
      classWeight: (json['class_weight'] ?? '-').toString(),
      maxFeatures: (json['max_features'] ?? '-').toString(),
      randomState: _toInt(json['random_state']),
      featureCount: _toInt(json['feature_count']),
      continuousFeatureCount: _toInt(json['continuous_feature_count']),
      description: (json['description'] ?? '').toString(),
      recommended: json['recommended'] == true,
    );
  }
}

class ModelDataset {
  const ModelDataset({
    required this.name,
    required this.totalRows,
    required this.trainRows,
    required this.testRows,
    required this.trainRatio,
    required this.testRatio,
    required this.legitimateRows,
    required this.phishingRows,
    required this.testLegitimateRows,
    required this.testPhishingRows,
  });

  final String name;
  final int totalRows;
  final int trainRows;
  final int testRows;
  final double trainRatio;
  final double testRatio;
  final int legitimateRows;
  final int phishingRows;
  final int testLegitimateRows;
  final int testPhishingRows;

  factory ModelDataset.fromJson(Map<String, dynamic> json) {
    return ModelDataset(
      name: (json['name'] ?? '-').toString(),
      totalRows: _toInt(json['total_rows']),
      trainRows: _toInt(json['train_rows']),
      testRows: _toInt(json['test_rows']),
      trainRatio: _toDouble(json['train_ratio']),
      testRatio: _toDouble(json['test_ratio']),
      legitimateRows: _toInt(json['legitimate_rows']),
      phishingRows: _toInt(json['phishing_rows']),
      testLegitimateRows: _toInt(json['test_legitimate_rows']),
      testPhishingRows: _toInt(json['test_phishing_rows']),
    );
  }
}

class ModelMetrics {
  const ModelMetrics({
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1,
    required this.rocAuc,
  });

  final double accuracy;
  final double precision;
  final double recall;
  final double f1;
  final double rocAuc;

  factory ModelMetrics.fromJson(Map<String, dynamic> json) {
    return ModelMetrics(
      accuracy: _toDouble(json['accuracy']),
      precision: _toDouble(json['precision']),
      recall: _toDouble(json['recall']),
      f1: _toDouble(json['f1']),
      rocAuc: _toDouble(json['roc_auc']),
    );
  }
}

class ConfusionMatrixData {
  const ConfusionMatrixData({
    required this.trueNegative,
    required this.falsePositive,
    required this.falseNegative,
    required this.truePositive,
    required this.total,
    required this.correct,
    required this.errors,
  });

  final int trueNegative;
  final int falsePositive;
  final int falseNegative;
  final int truePositive;
  final int total;
  final int correct;
  final int errors;

  factory ConfusionMatrixData.fromJson(Map<String, dynamic> json) {
    return ConfusionMatrixData(
      trueNegative: _toInt(json['tn']),
      falsePositive: _toInt(json['fp']),
      falseNegative: _toInt(json['fn']),
      truePositive: _toInt(json['tp']),
      total: _toInt(json['total']),
      correct: _toInt(json['correct']),
      errors: _toInt(json['errors']),
    );
  }
}

class ModelFeature {
  const ModelFeature({
    required this.position,
    required this.key,
    required this.label,
    required this.description,
    required this.kind,
    required this.continuous,
  });

  final int position;
  final String key;
  final String label;
  final String description;
  final String kind;
  final bool continuous;

  factory ModelFeature.fromJson(Map<String, dynamic> json) {
    return ModelFeature(
      position: _toInt(json['position']),
      key: (json['key'] ?? '-').toString(),
      label: (json['label'] ?? '-').toString(),
      description: (json['description'] ?? '').toString(),
      kind: (json['kind'] ?? 'numeric').toString(),
      continuous: json['continuous'] == true,
    );
  }
}

class ModelValidation {
  const ModelValidation({
    required this.featureOrderMatches,
    required this.runtimeFeatureCount,
    required this.metadataFeatureCount,
    required this.source,
  });

  final bool featureOrderMatches;
  final int runtimeFeatureCount;
  final int metadataFeatureCount;
  final String source;

  factory ModelValidation.fromJson(Map<String, dynamic> json) {
    return ModelValidation(
      featureOrderMatches: json['feature_order_matches'] == true,
      runtimeFeatureCount: _toInt(json['runtime_feature_count']),
      metadataFeatureCount: _toInt(json['metadata_feature_count']),
      source: (json['source'] ?? '-').toString(),
    );
  }
}
