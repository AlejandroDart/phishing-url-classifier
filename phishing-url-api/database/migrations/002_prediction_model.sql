ALTER TABLE predictions
    ADD COLUMN IF NOT EXISTS model_id VARCHAR(64);

UPDATE predictions
SET model_id = 'random_forest'
WHERE model_id IS NULL OR model_id = '';

ALTER TABLE predictions
    ALTER COLUMN model_id SET DEFAULT 'random_forest',
    ALTER COLUMN model_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_predictions_model_id
    ON predictions(model_id);
