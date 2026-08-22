import 'package:detector_url/services/ocr_url_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OcrUrlExtractor', () {
    final cases = <String, String>{
      'Visita https://example.com/login para continuar.':
          'https://example.com/login',
      'www.portal-academico.cl/acceso':
          'https://www.portal-academico.cl/acceso',
      'Dominio: cuenta-validacion.net/reset':
          'https://cuenta-validacion.net/reset',
      'https : / / secure-login . example . com / verify':
          'https://secure-login.example.com/verify',
      'https://secure-login.\nexample.com/acceso':
          'https://secure-login.example.com/acceso',
      'hxxps://cuenta-segura.example.com/login':
          'https://cuenta-segura.example.com/login',
      'https：／／example．com／ruta': 'https://example.com/ruta',
      'URL: http//example.com/path': 'http://example.com/path',
      'Servidor http://192.168.1.50:8005/login':
          'http://192.168.1.50:8005/login',
    };

    for (final entry in cases.entries) {
      test('extrae ${entry.value}', () {
        expect(OcrUrlExtractor.extract(entry.key), entry.value);
      });
    }

    test('prefiere una URL explicita sobre un dominio mencionado', () {
      expect(
        OcrUrlExtractor.extract(
          'Ayuda example.org. Abre https://secure.example.net/login',
        ),
        'https://secure.example.net/login',
      );
    });

    test('ignora texto, correos y versiones que no son URL', () {
      expect(OcrUrlExtractor.extract('Contacta soporte@example.com'), isNull);
      expect(OcrUrlExtractor.extract('Version instalada 1.2.3'), isNull);
      expect(OcrUrlExtractor.extract('No hay ningun enlace aqui'), isNull);
    });

    test('rechaza hosts y puertos invalidos', () {
      expect(OcrUrlExtractor.normalize('https://-example.com'), isNull);
      expect(OcrUrlExtractor.normalize('https://example.com:99999'), isNull);
      expect(OcrUrlExtractor.normalize('javascript://example.com'), isNull);
    });
  });
}
