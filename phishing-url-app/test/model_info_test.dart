import 'package:detector_url/models/model_info.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ModelInfo parses metrics, matrix and features', () {
    final info = ModelInfo.fromJson({
      'status': 'ready',
      'validated': true,
      'model': {
        'display_name': 'LinkShield Random Forest Top 25',
        'technical_name': 'RandomForestClassifier',
        'feature_count': 25,
        'estimators': 300,
        'threshold': 0.5,
      },
      'dataset': {
        'name': 'dataset.csv',
        'total_rows': 11429,
        'train_rows': 9143,
        'test_rows': 2286,
      },
      'metrics': {
        'accuracy': 0.9488,
        'precision': 0.943,
        'recall': 0.9554,
        'f1': 0.9492,
        'roc_auc': 0.9863,
      },
      'confusion_matrix': {
        'tn': 1077,
        'fp': 66,
        'fn': 51,
        'tp': 1092,
        'total': 2286,
        'correct': 2169,
        'errors': 117,
      },
      'features': [
        {
          'position': 1,
          'key': 'google_index',
          'label': 'Presencia en buscadores',
          'description': 'Descripción',
          'kind': 'google_index',
          'continuous': false,
        },
      ],
      'validation': {
        'feature_order_matches': true,
        'runtime_feature_count': 25,
        'metadata_feature_count': 25,
        'source': 'training_metadata',
      },
      'notes': ['Métricas del conjunto de prueba.'],
    });

    expect(info.validated, isTrue);
    expect(info.model.estimators, 300);
    expect(info.dataset.testRows, 2286);
    expect(info.metrics.accuracy, closeTo(0.9488, 0.00001));
    expect(info.confusionMatrix.truePositive, 1092);
    expect(info.features.single.key, 'google_index');
    expect(info.validation.featureOrderMatches, isTrue);
  });
}
