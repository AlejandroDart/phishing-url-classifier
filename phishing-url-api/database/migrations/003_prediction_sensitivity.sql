ALTER TABLE predictions
    ADD COLUMN IF NOT EXISTS sensitivity_profile VARCHAR(16),
    ADD COLUMN IF NOT EXISTS base_threshold DOUBLE PRECISION,
    ADD COLUMN IF NOT EXISTS effective_threshold DOUBLE PRECISION;

UPDATE predictions
SET sensitivity_profile = COALESCE(NULLIF(sensitivity_profile, ''), 'balanced');

UPDATE predictions
SET base_threshold = COALESCE(
        base_threshold,
        CASE
            WHEN explanation -> 'model' ->> 'threshold'
                 ~ '^[0-9]+(\.[0-9]+)?$'
            THEN (explanation -> 'model' ->> 'threshold')::DOUBLE PRECISION
        END,
        0.5
    );

UPDATE predictions
SET effective_threshold = COALESCE(effective_threshold, base_threshold, 0.5);

-- Corrige respaldos previos de esta migración que asumieron 0.5 para todos.
UPDATE predictions
SET base_threshold = (explanation -> 'model' ->> 'threshold')::DOUBLE PRECISION,
    effective_threshold = (explanation -> 'model' ->> 'threshold')::DOUBLE PRECISION
WHERE sensitivity_profile = 'balanced'
  AND base_threshold = 0.5
  AND effective_threshold = 0.5
  AND explanation -> 'model' ->> 'threshold' ~ '^[0-9]+(\.[0-9]+)?$'
  AND (explanation -> 'model' ->> 'threshold')::DOUBLE PRECISION <> 0.5;

ALTER TABLE predictions
    ALTER COLUMN sensitivity_profile SET DEFAULT 'balanced',
    ALTER COLUMN sensitivity_profile SET NOT NULL,
    ALTER COLUMN base_threshold SET DEFAULT 0.5,
    ALTER COLUMN base_threshold SET NOT NULL,
    ALTER COLUMN effective_threshold SET DEFAULT 0.5,
    ALTER COLUMN effective_threshold SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_predictions_sensitivity_profile
    ON predictions(sensitivity_profile);
