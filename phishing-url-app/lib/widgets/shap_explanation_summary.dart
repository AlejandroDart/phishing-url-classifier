import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_design.dart';

Map<String, dynamic>? decodeStoredExplanation(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

class ShapExplanationSummary extends StatelessWidget {
  const ShapExplanationSummary({
    super.key,
    required this.explanation,
    required this.textColor,
    required this.subtleColor,
    required this.accentColor,
    required this.increaseColor,
    required this.decreaseColor,
  });

  final Map<String, dynamic>? explanation;
  final Color textColor;
  final Color subtleColor;
  final Color accentColor;
  final Color increaseColor;
  final Color decreaseColor;

  List<Map<String, dynamic>> get _factors {
    final shap = explanation?['shap'];
    if (shap is! Map) return const [];
    final rawFactors = shap['top_factors'];
    if (rawFactors is! List) return const [];

    return rawFactors
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .take(3)
        .toList();
  }

  List<Map<String, dynamic>> get _featureFactors {
    final shap = explanation?['shap'];
    if (shap is! Map) return const [];
    final rawFactors = shap['feature_factors'];
    if (rawFactors is! List) return const [];

    return rawFactors
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .take(6)
        .toList();
  }

  bool get _isHybrid {
    final shap = explanation?['shap'];
    return shap is Map && shap['method'] == 'ExactBranchShapley';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildContributionRow(Map<String, dynamic> factor) {
    final contribution = _toDouble(factor['shap_value']);
    final increases = contribution > 0;
    final color = increases ? increaseColor : decreaseColor;
    final name = (factor['display_name'] ?? factor['feature']).toString();
    final points = contribution.abs() * 100;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDesign.gapSmall),
      child: Row(
        children: [
          Icon(
            increases ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: AppDesign.gapSmall),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: textColor,
                fontSize: AppDesign.fontLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppDesign.gapSmall),
          Text(
            '${increases ? '+' : '-'}${points.toStringAsFixed(1)} pts',
            style: TextStyle(
              color: color,
              fontSize: AppDesign.fontLabel,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(Map<String, dynamic> factor) {
    final contribution = _toDouble(factor['shap_value']);
    final increases = contribution > 0;
    final color = increases ? increaseColor : decreaseColor;
    final name = (factor['display_name'] ?? factor['feature']).toString();
    final source = (factor['source_name'] ?? 'Modelo').toString();
    final meaning = (factor['raw_value_meaning'] ?? factor['description'] ?? '')
        .toString()
        .trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDesign.gapSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(
              increases ? Icons.add_chart_rounded : Icons.ssid_chart_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: AppDesign.gapSmall),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: textColor,
                    fontSize: AppDesign.fontLabel,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppDesign.gapXSmall),
                Text(
                  meaning.isEmpty ? source : '$source · $meaning',
                  style: TextStyle(
                    color: subtleColor,
                    fontSize: AppDesign.fontMicro,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDesign.gapSmall),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
              border: Border.all(color: color.withValues(alpha: 0.20)),
            ),
            child: Text(
              increases ? 'AUMENTA' : 'REDUCE',
              style: TextStyle(
                color: color,
                fontSize: AppDesign.fontMicro,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final factors = _factors;
    final featureFactors = _featureFactors;
    final isHybrid = _isHybrid;

    return Padding(
      padding: const EdgeInsets.only(top: AppDesign.gapContent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: accentColor.withValues(alpha: 0.22), height: 1),
          const SizedBox(height: AppDesign.gapContent),
          Row(
            children: [
              Icon(Icons.insights_rounded, color: accentColor, size: 20),
              const SizedBox(width: AppDesign.gapSmall),
              Expanded(
                child: Text(
                  isHybrid ? 'APORTES DEL ENSAMBLE' : 'FACTORES PRINCIPALES',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: AppDesign.fontCaption,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapXSmall),
          Text(
            isHybrid
                ? 'Contribuci\u00f3n de cada componente a la probabilidad final'
                : 'Influencia SHAP sobre la probabilidad de phishing',
            style: TextStyle(
              color: subtleColor,
              fontSize: AppDesign.fontCaption,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppDesign.gapCompact),
          if (factors.isEmpty)
            Text(
              'Explicabilidad no disponible para este análisis.',
              style: TextStyle(
                color: subtleColor,
                fontSize: AppDesign.fontLabel,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            for (final factor in factors) _buildContributionRow(factor),
            const SizedBox(height: AppDesign.gapXSmall),
            Text(
              '+ aumenta el riesgo estimado; - lo reduce.',
              style: TextStyle(
                color: subtleColor,
                fontSize: AppDesign.fontMicro,
                height: 1.35,
              ),
            ),
            if (isHybrid && featureFactors.isNotEmpty) ...[
              const SizedBox(height: AppDesign.gapContent),
              Divider(color: accentColor.withValues(alpha: 0.18), height: 1),
              const SizedBox(height: AppDesign.gapContent),
              Row(
                children: [
                  Icon(Icons.manage_search_rounded,
                      color: accentColor, size: 20),
                  const SizedBox(width: AppDesign.gapSmall),
                  Expanded(
                    child: Text(
                      'SE\u00d1ALES DETECTADAS',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: AppDesign.fontCaption,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDesign.gapXSmall),
              Text(
                'Caracter\u00edsticas, palabras y evidencias observadas por las ramas',
                style: TextStyle(
                  color: subtleColor,
                  fontSize: AppDesign.fontCaption,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppDesign.gapCompact),
              for (final factor in featureFactors) _buildFeatureRow(factor),
              const SizedBox(height: AppDesign.gapXSmall),
              Text(
                'Estas se\u00f1ales explican ramas internas; los aportes superiores '
                'explican la probabilidad final del ensamble.',
                style: TextStyle(
                  color: subtleColor,
                  fontSize: AppDesign.fontMicro,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
