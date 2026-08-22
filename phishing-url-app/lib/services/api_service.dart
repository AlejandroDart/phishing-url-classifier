import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'preferences_service.dart';

/// ===============================
/// CONFIG API
/// ===============================
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.26.146.209:5000',
  );
  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );
}

/// ===============================
/// HELPERS
/// ===============================
double parseToDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

int parseToInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? parseToDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;

  if (value is String) {
    final parsedIso = DateTime.tryParse(value);
    if (parsedIso != null) return parsedIso;

    try {
      final cleaned = value.replaceAll(' GMT', '').trim();

      return DateFormat(
        'EEE, dd MMM yyyy HH:mm:ss',
        'en_US',
      ).parseStrict(cleaned);
    } catch (_) {
      return null;
    }
  }

  return null;
}

/// ===============================
/// PREDICCIÓN
/// ===============================
Future<Map<String, dynamic>> predictPhishing(String url) async {
  const apiUrl = '${ApiConfig.baseUrl}/predict';
  final globalStorageEnabled =
      await PreferencesService().getGlobalStorageEnabled();
  final selectedModelId = await PreferencesService().getSelectedModelId();
  final sensitivityProfile = await PreferencesService().getSensitivityProfile();

  final Map<String, dynamic> body = {
    'url': url,
    'store_global': globalStorageEnabled,
    'model_id': selectedModelId,
    'sensitivity_profile': sensitivityProfile.apiValue,
  };

  try {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': ApiConfig.apiKey,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      return {
        'url': (jsonResponse['url'] ?? url).toString(),
        'label': (jsonResponse['label'] ?? '').toString(),
        'probability': parseToDouble(jsonResponse['probability']),
        'explanation': jsonResponse['explanation'],
        'stored_global': jsonResponse['stored_global'] == true,
        'model_id': (jsonResponse['model_id'] ?? selectedModelId).toString(),
        'model_name':
            (jsonResponse['model_name'] ?? selectedModelId).toString(),
        'sensitivity_profile':
            (jsonResponse['sensitivity_profile'] ?? sensitivityProfile.apiValue)
                .toString(),
        'base_threshold': parseToDouble(jsonResponse['base_threshold']),
        'effective_threshold':
            parseToDouble(jsonResponse['effective_threshold']),
      };
    } else {
      final dynamic rawBody = response.body;
      return {
        'error': 'Error en la solicitud: ${response.statusCode} - $rawBody',
      };
    }
  } catch (e) {
    return {'error': 'Error de conexión: $e'};
  }
}

Future<Map<String, dynamic>?> explainStoredFeatures(
  Map<String, dynamic> features,
  double expectedProbability,
  String? modelId,
) async {
  try {
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/explain-features'),
          headers: {
            'Content-Type': 'application/json',
            'X-API-KEY': ApiConfig.apiKey,
          },
          body: jsonEncode({
            'features': features,
            if (modelId != null) 'model_id': modelId,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) return null;
    final rebuiltProbability = parseToDouble(decoded['probability']);
    if ((rebuiltProbability - expectedProbability).abs() > 0.000001) {
      return null;
    }
    final shap = decoded['shap'];
    return shap is Map<String, dynamic> ? shap : null;
  } catch (_) {
    return null;
  }
}

/// ===============================
/// CHATBOT RAG
/// ===============================
class ChatbotReply {
  final String answer;
  final List<String> sources;
  final String? model;
  final String? interactionId;
  final String? intent;
  final String? generationMode;
  final Map<String, dynamic>? analysis;
  final Map<String, dynamic>? decision;
  final Map<String, dynamic>? action;

  const ChatbotReply({
    required this.answer,
    required this.sources,
    this.model,
    this.interactionId,
    this.intent,
    this.generationMode,
    this.analysis,
    this.decision,
    this.action,
  });
}

Future<ChatbotReply> askChatbot(
  String question, {
  List<Map<String, String>> history = const [],
  String? conversationId,
}) async {
  final globalStorageEnabled =
      await PreferencesService().getGlobalStorageEnabled();
  final selectedModelId = await PreferencesService().getSelectedModelId();
  final sensitivityProfile = await PreferencesService().getSensitivityProfile();
  final response = await http
      .post(
        Uri.parse('${ApiConfig.baseUrl}/chat'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': ApiConfig.apiKey,
        },
        body: jsonEncode({
          'question': question,
          'history': history,
          if (conversationId != null) 'conversation_id': conversationId,
          'store_global': globalStorageEnabled,
          'model_id': selectedModelId,
          'sensitivity_profile': sensitivityProfile.apiValue,
        }),
      )
      .timeout(const Duration(seconds: 130));

  final decodedBody = utf8.decode(response.bodyBytes);
  final dynamic decoded = decodedBody.isEmpty ? null : jsonDecode(decodedBody);
  final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};

  if (response.statusCode != 200) {
    throw Exception(
      (data['error'] ?? 'No fue posible consultar el asistente').toString(),
    );
  }

  final answer = (data['answer'] ?? '').toString().trim();
  if (answer.isEmpty) {
    throw Exception('El asistente devolvió una respuesta vacía');
  }

  final rawSources = data['sources'];
  final sources = rawSources is List
      ? rawSources.map((source) => source.toString()).toList()
      : <String>[];

  return ChatbotReply(
    answer: answer,
    sources: sources,
    model: data['model']?.toString(),
    interactionId: data['interaction_id']?.toString(),
    intent: data['intent']?.toString(),
    generationMode: data['generation_mode']?.toString(),
    analysis: data['analysis'] is Map<String, dynamic>
        ? data['analysis'] as Map<String, dynamic>
        : null,
    decision: data['decision'] is Map<String, dynamic>
        ? data['decision'] as Map<String, dynamic>
        : null,
    action: data['action'] is Map<String, dynamic>
        ? data['action'] as Map<String, dynamic>
        : null,
  );
}

/// ===============================
/// MODELOS STATS
/// ===============================
class DashboardStats {
  final int totalAnalysis;
  final double phishingRatio;
  final List<RecentPrediction> recentPredictions;
  final List<DailyActivity> dailyActivity;

  DashboardStats({
    required this.totalAnalysis,
    required this.phishingRatio,
    required this.recentPredictions,
    required this.dailyActivity,
  });
}

class RecentPrediction {
  final String url;
  final String label;
  final double probability;
  final DateTime? createdAt;
  final Map<String, dynamic>? explanation;
  final String modelId;
  final String modelName;
  final String sensitivityProfile;
  final double baseThreshold;
  final double effectiveThreshold;

  RecentPrediction({
    required this.url,
    required this.label,
    required this.probability,
    required this.createdAt,
    this.explanation,
    required this.modelId,
    required this.modelName,
    required this.sensitivityProfile,
    required this.baseThreshold,
    required this.effectiveThreshold,
  });

  factory RecentPrediction.fromJson(Map<String, dynamic> json) {
    final explanation = json['explanation'] is Map<String, dynamic>
        ? json['explanation'] as Map<String, dynamic>
        : null;
    final rawModel = explanation?['model'];
    final model = rawModel is Map ? rawModel : const {};
    return RecentPrediction(
      url: (json['url'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      probability: parseToDouble(json['probability']),
      createdAt: parseToDateTime(json['created_at']),
      explanation: explanation,
      modelId: (json['model_id'] ?? 'random_forest').toString(),
      modelName: (model['name'] ?? json['model_id'] ?? 'Random Forest Top 25')
          .toString(),
      sensitivityProfile: (json['sensitivity_profile'] ??
              model['sensitivity_profile'] ??
              'balanced')
          .toString(),
      baseThreshold: parseToDouble(
        json['base_threshold'] ?? model['base_threshold'] ?? 0.5,
      ),
      effectiveThreshold: parseToDouble(
        json['effective_threshold'] ??
            model['effective_threshold'] ??
            model['threshold'] ??
            0.5,
      ),
    );
  }
}

class DailyActivity {
  final DateTime? date;
  final int total;

  DailyActivity({
    required this.date,
    required this.total,
  });

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      date: parseToDateTime(json['date']),
      total: parseToInt(json['total']),
    );
  }
}

/// ===============================
/// STATS SERVICE
/// ===============================
class StatsService {
  Future<DashboardStats> fetchDashboardStats() async {
    final results = await Future.wait<dynamic>([
      _getTotalAnalysis(),
      _getPhishingRatio(),
      _getRecentPredictions(),
      _getDailyActivity(),
    ]);

    return DashboardStats(
      totalAnalysis: results[0] as int,
      phishingRatio: results[1] as double,
      recentPredictions: results[2] as List<RecentPrediction>,
      dailyActivity: results[3] as List<DailyActivity>,
    );
  }

  Future<int> _getTotalAnalysis() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stats/count'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': ApiConfig.apiKey,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error obteniendo total de análisis');
    }

    final data = jsonDecode(response.body);
    return parseToInt(data['total_analysis']);
  }

  Future<double> _getPhishingRatio() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stats/phishing-ratio'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': ApiConfig.apiKey,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error obteniendo ratio de phishing');
    }

    final data = jsonDecode(response.body);
    return parseToDouble(data['phishing_ratio']);
  }

  Future<List<RecentPrediction>> _getRecentPredictions() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stats/recent'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': ApiConfig.apiKey,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error obteniendo predicciones recientes');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data
        .map((item) => RecentPrediction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<DailyActivity>> _getDailyActivity() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/stats/daily'),
      headers: {
        'Content-Type': 'application/json',
        'X-API-KEY': ApiConfig.apiKey,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error obteniendo actividad diaria');
    }

    final List<dynamic> data = jsonDecode(response.body);

    final apiItems = data
        .map((item) => DailyActivity.fromJson(item as Map<String, dynamic>))
        .toList();

    final Map<String, int> totalsByDay = {};

    for (final item in apiItems) {
      if (item.date == null) continue;

      final localDate = item.date!;
      final key =
          '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';

      totalsByDay[key] = item.total;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<DailyActivity> completed = [];

    for (int i = 6; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));

      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

      completed.add(
        DailyActivity(
          date: day,
          total: totalsByDay[key] ?? 0,
        ),
      );
    }

    return completed;
  }
}
