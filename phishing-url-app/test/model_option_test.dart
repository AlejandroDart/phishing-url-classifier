import 'package:flutter_test/flutter_test.dart';
import 'package:detector_url/models/model_option.dart';

void main() {
  test('ModelCatalog parses selectable models and recommendation', () {
    final catalog = ModelCatalog.fromJson({
      'default_model_id': 'hybrid_ensemble',
      'models': [
        {
          'id': 'hybrid_ensemble',
          'display_name': 'LinkShield Hybrid Ensemble',
          'technical_name': 'StackingLogisticEnsemble',
          'description': 'Modelo recomendado',
          'family': 'hybrid',
          'recommended': true,
          'metrics': {'accuracy': 0.9488, 'f1': 0.9491},
        },
      ],
    });

    expect(catalog.defaultModelId, 'hybrid_ensemble');
    expect(catalog.models, hasLength(1));
    expect(catalog.models.first.recommended, isTrue);
    expect(catalog.models.first.accuracy, closeTo(0.9488, 0.00001));
    expect(catalog.models.first.familyLabel, 'Modelo híbrido');
  });
}
