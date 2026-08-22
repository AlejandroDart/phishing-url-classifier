import 'local_prediction_store.dart';
import 'local_prediction_store_factory_stub.dart'
    if (dart.library.io) 'local_prediction_store_factory_mobile.dart'
    if (dart.library.js_interop) 'local_prediction_store_factory_web.dart'
    as platform;

LocalPredictionStore createLocalPredictionStore() {
  return platform.createLocalPredictionStore();
}
