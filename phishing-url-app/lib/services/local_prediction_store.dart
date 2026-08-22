import '../models/local_prediction.dart';

abstract interface class LocalPredictionStore {
  Future<int> insertPrediction(LocalPrediction prediction);

  Future<List<LocalPrediction>> getPredictions();

  Future<int> deletePrediction(int id);

  Future<int> clearPredictions();

  Future<int> updateExplanation(int id, String explanation);
}
