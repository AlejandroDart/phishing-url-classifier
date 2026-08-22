import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

class NetworkDiagnosticResult {
  final bool isOnline;
  final String statusText;
  final String host;
  final String port;
  final String scheme;
  final String endpoint;
  final int? latencyMs;
  final String message;

  const NetworkDiagnosticResult({
    required this.isOnline,
    required this.statusText,
    required this.host,
    required this.port,
    required this.scheme,
    required this.endpoint,
    required this.message,
    this.latencyMs,
  });
}

class NetworkDiagnosticService {
  const NetworkDiagnosticService();

  Future<NetworkDiagnosticResult> testConnection() async {
    final baseUri = Uri.parse(ApiConfig.baseUrl);

    final stopwatch = Stopwatch()..start();

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/stats/count');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': ApiConfig.apiKey,
        },
      ).timeout(const Duration(seconds: 5));

      stopwatch.stop();

      if (response.statusCode == 200) {
        return NetworkDiagnosticResult(
          isOnline: true,
          statusText: 'READY',
          host: baseUri.host,
          port: baseUri.hasPort
              ? baseUri.port.toString()
              : (baseUri.scheme == 'https' ? '443' : '80'),
          scheme: baseUri.scheme.toUpperCase(),
          endpoint: '/stats/count',
          latencyMs: stopwatch.elapsedMilliseconds,
          message: 'Conexión exitosa',
        );
      }

      String serverMessage = 'Servidor respondió ${response.statusCode}';
      try {
        final body = jsonDecode(response.body);
        serverMessage = body.toString();
      } catch (_) {}

      return NetworkDiagnosticResult(
        isOnline: false,
        statusText: 'ERROR',
        host: baseUri.host,
        port: baseUri.hasPort
            ? baseUri.port.toString()
            : (baseUri.scheme == 'https' ? '443' : '80'),
        scheme: baseUri.scheme.toUpperCase(),
        endpoint: '/stats/count',
        message: serverMessage,
      );
    } on TimeoutException {
      stopwatch.stop();
      return NetworkDiagnosticResult(
        isOnline: false,
        statusText: 'TIMEOUT',
        host: baseUri.host,
        port: baseUri.hasPort
            ? baseUri.port.toString()
            : (baseUri.scheme == 'https' ? '443' : '80'),
        scheme: baseUri.scheme.toUpperCase(),
        endpoint: '/stats/count',
        message: 'Tiempo agotado',
      );
    } catch (e) {
      stopwatch.stop();
      return NetworkDiagnosticResult(
        isOnline: false,
        statusText: 'OFFLINE',
        host: baseUri.host,
        port: baseUri.hasPort
            ? baseUri.port.toString()
            : (baseUri.scheme == 'https' ? '443' : '80'),
        scheme: baseUri.scheme.toUpperCase(),
        endpoint: '/stats/count',
        message: 'Error de conexión',
      );
    }
  }
}
