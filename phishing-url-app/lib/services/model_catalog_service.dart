import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/model_option.dart';
import 'api_service.dart';

class ModelCatalogService {
  Future<ModelCatalog> fetchModels() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/models'),
      headers: const {
        'Content-Type': 'application/json',
        'X-API-KEY': ApiConfig.apiKey,
      },
    ).timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200 || decoded is! Map<String, dynamic>) {
      throw Exception('No fue posible obtener los modelos disponibles');
    }
    return ModelCatalog.fromJson(decoded);
  }
}
