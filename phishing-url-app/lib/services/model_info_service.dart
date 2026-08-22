import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/model_info.dart';
import 'api_service.dart';

class ModelInfoService {
  const ModelInfoService();

  Future<ModelInfo> fetchModelInfo({String? modelId}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/model/info').replace(
      queryParameters: modelId == null ? null : {'model_id': modelId},
    );
    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'X-API-KEY': ApiConfig.apiKey,
      },
    ).timeout(const Duration(seconds: 20));

    final decodedBody = utf8.decode(response.bodyBytes);
    final dynamic decoded =
        decodedBody.isEmpty ? null : jsonDecode(decodedBody);
    final data =
        decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

    if (response.statusCode != 200) {
      throw Exception(
        (data['error'] ?? 'No fue posible obtener el modelo').toString(),
      );
    }

    return ModelInfo.fromJson(data);
  }
}
