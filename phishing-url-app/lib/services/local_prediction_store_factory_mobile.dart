import 'local_prediction_store.dart';
import 'sqflite_prediction_store.dart';

LocalPredictionStore createLocalPredictionStore() {
  return SqflitePredictionStore();
}
