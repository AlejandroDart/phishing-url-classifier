import 'package:detector_url/models/local_prediction.dart';
import 'package:detector_url/services/local_prediction_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persiste el historial local en IndexedDB cuando se ejecuta en Web',
      () async {
    if (!kIsWeb) return;

    final repository = LocalPredictionRepository();
    await repository.clearPredictions();

    final id = await repository.insertPrediction(
      LocalPrediction(
        url: 'https://example.com/login',
        label: 'phishing',
        probability: 0.82,
        explanation: '{"summary":"inicial"}',
        modelId: 'hybrid_recommended',
        modelName: 'Modelo hibrido recomendado',
        sensitivityProfile: 'aggressive',
        baseThreshold: 0.5,
        effectiveThreshold: 0.25,
        createdAt: DateTime.utc(2026, 8, 14, 12),
      ),
    );

    var predictions = await repository.getPredictions();
    expect(predictions, hasLength(1));
    expect(predictions.single.id, id);
    expect(predictions.single.url, 'https://example.com/login');
    expect(predictions.single.probability, 0.82);
    expect(predictions.single.effectiveThreshold, 0.25);

    expect(
      await repository.updateExplanation(id, '{"summary":"actualizada"}'),
      1,
    );
    predictions = await repository.getPredictions();
    expect(predictions.single.explanation, '{"summary":"actualizada"}');

    expect(await repository.deletePrediction(id), 1);
    expect(await repository.getPredictions(), isEmpty);
  });
}
