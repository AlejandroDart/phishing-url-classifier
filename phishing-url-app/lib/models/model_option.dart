class ModelOption {
  const ModelOption({
    required this.id,
    required this.displayName,
    required this.technicalName,
    required this.description,
    required this.family,
    required this.recommended,
    required this.accuracy,
    required this.f1,
    required this.threshold,
  });

  final String id;
  final String displayName;
  final String technicalName;
  final String description;
  final String family;
  final bool recommended;
  final double accuracy;
  final double f1;
  final double threshold;

  factory ModelOption.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'];
    final metrics =
        rawMetrics is Map<String, dynamic> ? rawMetrics : <String, dynamic>{};
    return ModelOption(
      id: (json['id'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['id'] ?? '-').toString(),
      technicalName: (json['technical_name'] ?? '-').toString(),
      description: (json['description'] ?? '').toString(),
      family: (json['family'] ?? 'machine_learning').toString(),
      recommended: json['recommended'] == true,
      accuracy: _toDouble(metrics['accuracy']),
      f1: _toDouble(metrics['f1']),
      threshold: _toDouble(json['threshold']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get familyLabel {
    switch (family) {
      case 'deep_learning_tabular':
        return 'Deep Learning tabular';
      case 'deep_learning_sequential':
        return 'Deep Learning secuencial';
      case 'heuristic':
        return 'Reglas heurísticas';
      case 'hybrid':
        return 'Modelo híbrido';
      default:
        return 'Machine Learning';
    }
  }
}

class ModelCatalog {
  const ModelCatalog({required this.defaultModelId, required this.models});

  final String defaultModelId;
  final List<ModelOption> models;

  factory ModelCatalog.fromJson(Map<String, dynamic> json) {
    final rawModels = json['models'];
    return ModelCatalog(
      defaultModelId: (json['default_model_id'] ?? 'random_forest').toString(),
      models: rawModels is List
          ? rawModels
              .whereType<Map<String, dynamic>>()
              .map(ModelOption.fromJson)
              .toList()
          : const [],
    );
  }
}
