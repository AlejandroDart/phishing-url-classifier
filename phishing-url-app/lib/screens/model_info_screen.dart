import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/model_info.dart';
import '../services/model_info_service.dart';
import '../theme/app_design.dart';
import '../widgets/app_content_width.dart';

class ModelInfoScreen extends StatefulWidget {
  const ModelInfoScreen({super.key, this.modelId});

  final String? modelId;

  @override
  State<ModelInfoScreen> createState() => _ModelInfoScreenState();
}

class _ModelInfoScreenState extends State<ModelInfoScreen> {
  final ModelInfoService _service = const ModelInfoService();
  final TextEditingController _featureSearchController =
      TextEditingController();

  ModelInfo? _modelInfo;
  Object? _error;
  bool _loading = true;
  String _featureQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _featureSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final modelInfo = await _service.fetchModelInfo(modelId: widget.modelId);
      if (!mounted) return;
      setState(() {
        _modelInfo = modelInfo;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Color _background(bool isDark) =>
      isDark ? const Color(0xFF030B16) : const Color(0xFFF4F7FB);

  Color _panel(bool isDark) => isDark ? const Color(0xFF071423) : Colors.white;

  Color _text(bool isDark) => isDark ? Colors.white : const Color(0xFF102030);

  Color _muted(bool isDark) =>
      isDark ? const Color(0xFF8DB6D8) : const Color(0xFF4F718C);

  Color _blue(bool isDark) =>
      isDark ? const Color(0xFF0A84FF) : const Color(0xFF1565C0);

  Color _cyan(bool isDark) =>
      isDark ? const Color(0xFF00E5FF) : const Color(0xFF008FA6);

  Color _success(bool isDark) =>
      isDark ? const Color(0xFF28DDB3) : const Color(0xFF118C73);

  Color _danger(bool isDark) =>
      isDark ? const Color(0xFFFF5A7A) : const Color(0xFFD63556);

  BoxDecoration _cardDecoration(bool isDark, {Color? accent}) {
    final borderColor = accent ?? _blue(isDark);
    return BoxDecoration(
      color: _panel(isDark),
      borderRadius: BorderRadius.circular(AppDesign.radiusControl),
      border: Border.all(color: borderColor.withValues(alpha: 0.30)),
      boxShadow: [
        BoxShadow(
          color: borderColor.withValues(alpha: isDark ? 0.10 : 0.05),
          blurRadius: 14,
        ),
      ],
    );
  }

  String _count(int value) =>
      NumberFormat.decimalPattern('es_CL').format(value);

  String _percent(double value, {int decimals = 1}) =>
      '${(value * 100).toStringAsFixed(decimals)}%';

  String _date(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
  }

  Widget _buildBackground(bool isDark) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _ModelGridPainter(
            color: isDark
                ? const Color(0xFF0D2A4D).withValues(alpha: 0.35)
                : const Color(0xFFC5DAEB).withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _background(isDark).withValues(alpha: 0.97),
          border: Border(
            bottom: BorderSide(color: _blue(isDark).withValues(alpha: 0.22)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _cyan(isDark).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDesign.radiusItem),
                border: Border.all(
                  color: _cyan(isDark).withValues(alpha: 0.28),
                ),
              ),
              child: Icon(Icons.psychology_alt_rounded, color: _cyan(isDark)),
            ),
            const SizedBox(width: AppDesign.gapCompact),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MODELO DE IA',
                    style: TextStyle(
                      color: _text(isDark),
                      fontSize: AppDesign.fontHeading,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Métricas y configuración activa',
                    style: TextStyle(
                      color: _muted(isDark),
                      fontSize: AppDesign.fontCaption,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Actualizar',
              child: IconButton(
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh_rounded, color: _blue(isDark)),
              ),
            ),
            Tooltip(
              message: 'Cerrar',
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: _text(isDark)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(
    bool isDark,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _cyan(isDark), size: 22),
          const SizedBox(width: AppDesign.gapRegular),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _text(isDark),
                    fontSize: AppDesign.fontSectionTitle,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _muted(isDark),
                    fontSize: AppDesign.fontCaption,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(bool isDark, ModelInfo info) {
    final statusColor = info.validated ? _success(isDark) : _danger(isDark);
    return Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: _cardDecoration(isDark, accent: statusColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDesign.radiusItem),
                ),
                child: Icon(
                  info.validated
                      ? Icons.verified_rounded
                      : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppDesign.gapCompact),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.model.displayName,
                      style: TextStyle(
                        color: _text(isDark),
                        fontSize: AppDesign.fontPageTitle,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppDesign.gapXSmall),
                    Text(
                      info.model.estimators > 0
                          ? '${info.model.technicalName} · ${info.model.estimators} árboles'
                          : info.model.technicalName,
                      style: TextStyle(
                        color: _muted(isDark),
                        fontSize: AppDesign.fontBody,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesign.gapStandard),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(
                isDark,
                info.validated ? 'MODELO VALIDADO' : 'REVISAR MODELO',
                statusColor,
              ),
              _statusChip(
                  isDark, 'VERSIÓN ${info.model.version}', _blue(isDark)),
              _statusChip(
                isDark,
                '${info.model.featureCount} VARIABLES',
                _cyan(isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(bool isDark, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: AppDesign.fontMicro,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildOverview(bool isDark, ModelInfo info) {
    final items = [
      ('Entrenamiento', _date(info.model.trainedAt), Icons.event_rounded),
      (
        'Framework',
        '${info.model.framework} ${info.model.frameworkVersion}',
        Icons.code_rounded
      ),
      (
        'Umbral',
        _percent(info.model.threshold, decimals: 0),
        Icons.tune_rounded
      ),
      ('Artefacto', info.model.artifactId, Icons.fingerprint_rounded),
      ('Criterio', info.model.criterion, Icons.account_tree_rounded),
      ('Balance', info.model.classWeight, Icons.balance_rounded),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _OverviewTile(
                    icon: item.$3,
                    label: item.$1,
                    value: item.$2,
                    textColor: _text(isDark),
                    mutedColor: _muted(isDark),
                    accentColor: _blue(isDark),
                    panelColor: _panel(isDark),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildMetrics(bool isDark, ModelMetrics metrics) {
    final items = [
      ('Accuracy', metrics.accuracy, 'Aciertos sobre todas las muestras.'),
      (
        'Precision',
        metrics.precision,
        'Cuántas alertas phishing fueron correctas.'
      ),
      ('Recall', metrics.recall, 'Cuánto phishing real logró detectar.'),
      ('F1-score', metrics.f1, 'Equilibrio entre precision y recall.'),
      ('ROC-AUC', metrics.rocAuc, 'Separación global entre ambas clases.'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 142),
                    padding: const EdgeInsets.all(14),
                    decoration: _cardDecoration(isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1.toUpperCase(),
                          style: TextStyle(
                            color: _muted(isDark),
                            fontSize: AppDesign.fontMicro,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _percent(item.$2),
                          style: TextStyle(
                            color: _success(isDark),
                            fontSize: AppDesign.fontMetric,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.$3,
                          style: TextStyle(
                            color: _muted(isDark),
                            fontSize: AppDesign.fontMicro,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildConfusionMatrix(bool isDark, ConfusionMatrixData matrix) {
    final correctRate = matrix.total == 0 ? 0.0 : matrix.correct / matrix.total;
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: AppDesign.cardPadding,
          decoration: _cardDecoration(isDark),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REAL ↓   ·   PREDICHO →',
                style: TextStyle(
                  color: _muted(isDark),
                  fontSize: AppDesign.fontMicro,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const SizedBox(width: 74),
                  Expanded(child: _matrixHeader(isDark, 'LEGÍTIMA')),
                  const SizedBox(width: 8),
                  Expanded(child: _matrixHeader(isDark, 'PHISHING')),
                ],
              ),
              const SizedBox(height: 8),
              _matrixRow(
                isDark,
                'LEGÍTIMA',
                matrix.trueNegative,
                'VN',
                matrix.falsePositive,
                'FP',
              ),
              const SizedBox(height: 8),
              _matrixRow(
                isDark,
                'PHISHING',
                matrix.falseNegative,
                'FN',
                matrix.truePositive,
                'VP',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _compactValue(
                isDark,
                'ACIERTOS',
                '${_count(matrix.correct)} · ${_percent(correctRate)}',
                _success(isDark),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _compactValue(
                isDark,
                'ERRORES',
                _count(matrix.errors),
                _danger(isDark),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _matrixHeader(bool isDark, String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _muted(isDark),
        fontSize: AppDesign.fontMicro,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _matrixRow(
    bool isDark,
    String actual,
    int leftValue,
    String leftCode,
    int rightValue,
    String rightCode,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            actual,
            style: TextStyle(
              color: _muted(isDark),
              fontSize: AppDesign.fontMicro,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: _matrixCell(
            isDark,
            leftValue,
            leftCode,
            leftCode == 'VN' ? _success(isDark) : _danger(isDark),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _matrixCell(
            isDark,
            rightValue,
            rightCode,
            rightCode == 'VP' ? _success(isDark) : _danger(isDark),
          ),
        ),
      ],
    );
  }

  Widget _matrixCell(bool isDark, int value, String code, Color color) {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _count(value),
            style: TextStyle(
              color: color,
              fontSize: AppDesign.fontResult,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            code,
            style: TextStyle(
              color: _text(isDark),
              fontSize: AppDesign.fontMicro,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactValue(
    bool isDark,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(isDark, accent: color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _muted(isDark),
              fontSize: AppDesign.fontMicro,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: AppDesign.fontHeading,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataset(bool isDark, ModelDataset dataset) {
    final trainPercent = dataset.trainRatio.clamp(0.0, 1.0);
    final legitimateRatio = dataset.totalRows == 0
        ? 0.0
        : dataset.legitimateRows / dataset.totalRows;
    return Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dataset.name,
            style: TextStyle(
              color: _text(isDark),
              fontSize: AppDesign.fontSubtitle,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _datasetBar(
            isDark,
            label: 'División de muestras',
            leftLabel: 'Entrenamiento ${_count(dataset.trainRows)}',
            rightLabel: 'Prueba ${_count(dataset.testRows)}',
            leftRatio: trainPercent,
            leftColor: _blue(isDark),
            rightColor: _cyan(isDark),
          ),
          const SizedBox(height: 18),
          _datasetBar(
            isDark,
            label: 'Balance de clases',
            leftLabel: 'Legítimas ${_count(dataset.legitimateRows)}',
            rightLabel: 'Phishing ${_count(dataset.phishingRows)}',
            leftRatio: legitimateRatio,
            leftColor: _success(isDark),
            rightColor: _danger(isDark),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _datasetNumber(
                  isDark,
                  'TOTAL',
                  _count(dataset.totalRows),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _datasetNumber(
                  isDark,
                  'PRUEBA LEGÍTIMA',
                  _count(dataset.testLegitimateRows),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _datasetNumber(
                  isDark,
                  'PRUEBA PHISHING',
                  _count(dataset.testPhishingRows),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datasetBar(
    bool isDark, {
    required String label,
    required String leftLabel,
    required String rightLabel,
    required double leftRatio,
    required Color leftColor,
    required Color rightColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: _muted(isDark),
            fontSize: AppDesign.fontMicro,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(
                  flex: (leftRatio * 1000).round().clamp(1, 999),
                  child: ColoredBox(color: leftColor),
                ),
                Expanded(
                  flex: ((1 - leftRatio) * 1000).round().clamp(1, 999),
                  child: ColoredBox(color: rightColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                leftLabel,
                style: TextStyle(
                  color: leftColor,
                  fontSize: AppDesign.fontMicro,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                rightLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: rightColor,
                  fontSize: AppDesign.fontMicro,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _datasetNumber(bool isDark, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              color: _text(isDark),
              fontSize: AppDesign.fontHeading,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: _muted(isDark),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatures(bool isDark, List<ModelFeature> allFeatures) {
    final normalized = _featureQuery.trim().toLowerCase();
    final features = normalized.isEmpty
        ? allFeatures
        : allFeatures.where((feature) {
            return feature.label.toLowerCase().contains(normalized) ||
                feature.key.toLowerCase().contains(normalized) ||
                feature.description.toLowerCase().contains(normalized);
          }).toList();
    return Column(
      children: [
        TextField(
          controller: _featureSearchController,
          onChanged: (value) => setState(() => _featureQuery = value),
          style: TextStyle(color: _text(isDark)),
          decoration: InputDecoration(
            hintText: 'Buscar característica',
            hintStyle: TextStyle(color: _muted(isDark)),
            prefixIcon: Icon(Icons.search_rounded, color: _blue(isDark)),
            suffixIcon: _featureQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () {
                      _featureSearchController.clear();
                      setState(() => _featureQuery = '');
                    },
                    icon: Icon(Icons.close_rounded, color: _muted(isDark)),
                  ),
            filled: true,
            fillColor: _panel(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesign.radiusControl),
              borderSide: BorderSide(color: _blue(isDark)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesign.radiusControl),
              borderSide: BorderSide(
                color: _blue(isDark).withValues(alpha: 0.28),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (features.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se encontraron características.',
              style: TextStyle(color: _muted(isDark)),
            ),
          )
        else
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: _cardDecoration(isDark),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: _blue(isDark).withValues(alpha: 0.08),
                  ),
                  child: ExpansionTile(
                    leading: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _blue(isDark).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        feature.position.toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: _blue(isDark),
                          fontSize: AppDesign.fontMicro,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    title: Text(
                      feature.label,
                      style: TextStyle(
                        color: _text(isDark),
                        fontSize: AppDesign.fontBody,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      feature.key,
                      style: TextStyle(
                        color: _muted(isDark),
                        fontSize: AppDesign.fontMicro,
                      ),
                    ),
                    iconColor: _blue(isDark),
                    collapsedIconColor: _muted(isDark),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          feature.description,
                          style: TextStyle(
                            color: _muted(isDark),
                            fontSize: AppDesign.fontLabel,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _statusChip(
                          isDark,
                          feature.continuous
                              ? 'CONTINUA · ${feature.kind.toUpperCase()}'
                              : 'DISCRETA · ${feature.kind.toUpperCase()}',
                          feature.continuous ? _cyan(isDark) : _blue(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTechnical(bool isDark, ModelInfo info) {
    final values = [
      ('Modelo', info.model.technicalName),
      ('Árboles', info.model.estimators.toString()),
      ('Max. variables', info.model.maxFeatures),
      ('Semilla', info.model.randomState.toString()),
      ('Variables continuas', info.model.continuousFeatureCount.toString()),
      ('Orden validado', info.validation.featureOrderMatches ? 'Sí' : 'No'),
      ('Fuente', info.validation.source),
    ];
    return Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: _cardDecoration(isDark),
      child: Column(
        children: values
            .map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.$1,
                        style: TextStyle(
                          color: _muted(isDark),
                          fontSize: AppDesign.fontLabel,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        item.$2,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _text(isDark),
                          fontSize: AppDesign.fontLabel,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildNotes(bool isDark, List<String> notes) {
    return Container(
      width: double.infinity,
      padding: AppDesign.cardPadding,
      decoration: _cardDecoration(isDark, accent: const Color(0xFFFFB020)),
      child: Column(
        children: notes
            .map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFFFB020),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note,
                        style: TextStyle(
                          color: _muted(isDark),
                          fontSize: AppDesign.fontCaption,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildContent(bool isDark, ModelInfo info) {
    return RefreshIndicator(
      onRefresh: _load,
      color: _blue(isDark),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 34),
        children: [
          AppContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(isDark, info),
                const SizedBox(height: 26),
                _sectionTitle(
                  isDark,
                  Icons.memory_rounded,
                  'Resumen técnico',
                  'Identidad y configuración del artefacto cargado.',
                ),
                _buildOverview(isDark, info),
                const SizedBox(height: 26),
                _sectionTitle(
                  isDark,
                  Icons.query_stats_rounded,
                  'Rendimiento',
                  'Resultados obtenidos sobre el conjunto de prueba.',
                ),
                _buildMetrics(isDark, info.metrics),
                const SizedBox(height: 26),
                _sectionTitle(
                  isDark,
                  Icons.grid_view_rounded,
                  'Matriz de confusión',
                  'La clase positiva corresponde a phishing.',
                ),
                _buildConfusionMatrix(isDark, info.confusionMatrix),
                const SizedBox(height: 26),
                _sectionTitle(
                  isDark,
                  Icons.dataset_rounded,
                  'Datos utilizados',
                  'Tamaño, división y balance del dataset de entrenamiento.',
                ),
                _buildDataset(isDark, info.dataset),
                const SizedBox(height: 26),
                _sectionTitle(
                  isDark,
                  Icons.rule_rounded,
                  'Características del modelo',
                  '${info.features.length} variables en el orden esperado por el clasificador.',
                ),
                _buildFeatures(isDark, info.features),
                const SizedBox(height: 26),
                _sectionTitle(
                  isDark,
                  Icons.settings_suggest_rounded,
                  'Configuración avanzada',
                  'Parámetros técnicos y validación del artefacto.',
                ),
                _buildTechnical(isDark, info),
                const SizedBox(height: 18),
                _buildNotes(isDark, info.notes),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: _danger(isDark), size: 48),
            const SizedBox(height: 14),
            Text(
              'No fue posible cargar el modelo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text(isDark),
                fontSize: AppDesign.fontHeading,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error.toString().replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted(isDark), height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: _background(isDark),
      body: Stack(
        children: [
          _buildBackground(isDark),
          Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(color: _cyan(isDark)),
                      )
                    : _error != null
                        ? _buildError(isDark)
                        : _buildContent(isDark, _modelInfo!),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
    required this.accentColor,
    required this.panelColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;
  final Color accentColor;
  final Color panelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(AppDesign.radiusSmall),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 9),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: mutedColor,
              fontSize: AppDesign.fontMicro,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: AppDesign.fontLabel,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelGridPainter extends CustomPainter {
  const _ModelGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ModelGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
