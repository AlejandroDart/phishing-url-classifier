enum SensitivityProfile {
  aggressive,
  balanced,
  passive;

  static SensitivityProfile fromApiValue(String? value) {
    return switch (value?.trim().toLowerCase()) {
      'aggressive' => SensitivityProfile.aggressive,
      'passive' => SensitivityProfile.passive,
      _ => SensitivityProfile.balanced,
    };
  }

  String get apiValue => switch (this) {
        SensitivityProfile.aggressive => 'aggressive',
        SensitivityProfile.balanced => 'balanced',
        SensitivityProfile.passive => 'passive',
      };

  String get label => switch (this) {
        SensitivityProfile.aggressive => 'Agresivo',
        SensitivityProfile.balanced => 'Equilibrado',
        SensitivityProfile.passive => 'Pasivo',
      };

  String get shortDescription => switch (this) {
        SensitivityProfile.aggressive => 'Detecta más señales de riesgo',
        SensitivityProfile.balanced => 'Usa el umbral validado del modelo',
        SensitivityProfile.passive => 'Reduce las alertas preventivas',
      };
}
