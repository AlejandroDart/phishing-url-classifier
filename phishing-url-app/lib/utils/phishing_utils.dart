import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

void resetGlobals() {
  label = '';
  globalPercentage = 0.0;
  globalColor = const Color.fromRGBO(149, 196, 190, 1.0);
  globalTitleMessage = '...';
  globalMessage = '...';
}

List getIconColorMessageForPercentage(double percentage) {
  final percent = (percentage * 100).toStringAsFixed(2);

  if (percentage < 0.25) {
    return [
      Icons.check_circle,
      const Color.fromRGBO(149, 196, 190, 1.0),
      '¡CONFIANZA!',
      'Riesgo bajo de phishing: $percent%.'
    ];
  } else if (percentage < 0.50) {
    return [
      Icons.warning,
      const Color.fromRGBO(255, 208, 166, 1.0),
      '¡PRECAUCIÓN!',
      'Riesgo moderado de phishing: $percent%.'
    ];
  } else {
    return [
      Icons.error,
      const Color.fromRGBO(249, 147, 151, 1.0),
      '¡ALERTA!',
      'Riesgo alto de phishing: $percent%.'
    ];
  }
}
