import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// ===============================
/// CONFIG API
/// ===============================
class ApiConfig {
  static const String baseUrl = 'http://192.168.100.5:5000';
  static const String apiKey = 'aB7!xZ9\$ePqT3@rWuLfC%12yJkNvQdX5';
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

  final Map<String, String> body = {
    'url': url,
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
        'label': (jsonResponse['label'] ?? '').toString(),
        'probability': parseToDouble(jsonResponse['probability']),
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

  RecentPrediction({
    required this.url,
    required this.label,
    required this.probability,
    required this.createdAt,
  });

  factory RecentPrediction.fromJson(Map<String, dynamic> json) {
    return RecentPrediction(
      url: (json['url'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      probability: parseToDouble(json['probability']),
      createdAt: parseToDateTime(json['created_at']),
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
