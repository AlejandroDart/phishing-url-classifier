import 'indexed_db_prediction_store.dart';
import 'local_prediction_store.dart';

LocalPredictionStore createLocalPredictionStore() {
  return IndexedDbPredictionStore();
}
