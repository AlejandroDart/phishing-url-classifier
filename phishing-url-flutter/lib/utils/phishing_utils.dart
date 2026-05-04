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
  if (percentage < 0.25) {
    return [
      Icons.check_circle,
      const Color.fromRGBO(149, 196, 190, 1.0),
      '¡CONFIANZA!',
      'Este sitio web parece seguro. La probabilidad de ser phishing es baja. ${(percentage * 100).toStringAsFixed(2)}%.'
    ];
  } else if (percentage < 0.50) {
    return [
      Icons.warning,
      const Color.fromRGBO(255, 208, 166, 1.0),
      '¡PRECAUCIÓN!',
      'Este sitio web podría ser sospechoso. La probabilidad de phishing es media. ${(percentage * 100).toStringAsFixed(2)}%.'
    ];
  } else {
    return [
      Icons.error,
      const Color.fromRGBO(249, 147, 151, 1.0),
      '¡ALERTA!',
      'Este sitio web es muy sospechoso. La probabilidad de phishing es alta. ${(percentage * 100).toStringAsFixed(2)}%.'
    ];
  }
}