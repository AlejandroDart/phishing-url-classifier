class LocalPrediction {
  final int? id;
  final String url;
  final String label;
  final double probability;
  final String? explanation;
  final String modelId;
  final String modelName;
  final String sensitivityProfile;
  final double baseThreshold;
  final double effectiveThreshold;
  final DateTime createdAt;

  const LocalPrediction({
    this.id,
    required this.url,
    required this.label,
    required this.probability,
    this.explanation,
    this.modelId = 'random_forest',
    this.modelName = 'Random Forest Top 25',
    this.sensitivityProfile = 'balanced',
    this.baseThreshold = 0.5,
    this.effectiveThreshold = 0.5,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'label': label,
      'probability': probability,
      'explanation': explanation,
      'model_id': modelId,
      'model_name': modelName,
      'sensitivity_profile': sensitivityProfile,
      'base_threshold': baseThreshold,
      'effective_threshold': effectiveThreshold,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LocalPrediction.fromMap(Map<String, dynamic> map) {
    return LocalPrediction(
      id: map['id'] as int?,
      url: map['url'] as String,
      label: map['label'] as String,
      probability: (map['probability'] as num).toDouble(),
      explanation: map['explanation'] as String?,
      modelId: (map['model_id'] ?? 'random_forest').toString(),
      modelName: (map['model_name'] ?? 'Random Forest Top 25').toString(),
      sensitivityProfile: (map['sensitivity_profile'] ?? 'balanced').toString(),
      baseThreshold: ((map['base_threshold'] ?? 0.5) as num).toDouble(),
      effectiveThreshold:
          ((map['effective_threshold'] ?? 0.5) as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
