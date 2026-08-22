import '../models/local_prediction.dart';
import 'local_prediction_store.dart';
import 'local_prediction_store_factory.dart';

class LocalPredictionRepository {
  LocalPredictionRepository({LocalPredictionStore? store})
      : _store = store ?? createLocalPredictionStore();

  final LocalPredictionStore _store;

  Future<int> insertPrediction(LocalPrediction prediction) {
    return _store.insertPrediction(prediction);
  }

  Future<List<LocalPrediction>> getPredictions() {
    return _store.getPredictions();
  }

  Future<int> deletePrediction(int id) {
    return _store.deletePrediction(id);
  }

  Future<int> clearPredictions() {
    return _store.clearPredictions();
  }

  Future<int> updateExplanation(int id, String explanation) {
    return _store.updateExplanation(id, explanation);
  }
}
