import json

from services.model_info_service import ModelInfoService


class FakeModel:
    n_features_in_ = 2
    n_estimators = 12
    criterion = "gini"
    class_weight = "balanced"
    max_features = "sqrt"
    random_state = 42


def test_model_info_exposes_validated_training_metadata(tmp_path):
    metadata_path = tmp_path / "metadata.json"
    model_path = tmp_path / "model.pkl"
    model_path.write_bytes(b"active-model")
    metadata_path.write_text(
        json.dumps({
            "created_at": "2026-07-11T00:12:25",
            "sklearn_version": "1.7.2",
            "model_params": {"n_estimators": 12},
            "features": ["google_index", "domain_age"],
            "continuous_features": ["domain_age"],
            "class_distribution": {"legitimate": 60, "phishing": 40},
            "metrics": {
                "dataset": "sample.csv",
                "rows": 100,
                "train_rows": 80,
                "test_rows": 20,
                "accuracy": 0.9,
                "precision": 0.8,
                "recall": 0.75,
                "f1": 0.774,
                "roc_auc": 0.92,
                "tn": 11,
                "fp": 1,
                "fn": 1,
                "tp": 7,
            },
        }),
        encoding="utf-8",
    )

    service = ModelInfoService(
        FakeModel(),
        ["google_index", "domain_age"],
        metadata_path=metadata_path,
        model_path=model_path,
    )
    result = service.get_info()

    assert result["status"] == "ready"
    assert result["validated"] is True
    assert result["model"]["technical_name"] == "FakeModel"
    assert result["dataset"]["train_rows"] == 80
    assert result["confusion_matrix"]["correct"] == 18
    assert result["features"][0]["label"] == "Presencia en buscadores"
    assert len(result["model"]["artifact_id"]) == 12


def test_model_info_warns_when_feature_order_does_not_match(tmp_path):
    metadata_path = tmp_path / "metadata.json"
    metadata_path.write_text(
        json.dumps({
            "features": ["domain_age", "google_index"],
            "continuous_features": [],
            "metrics": {},
        }),
        encoding="utf-8",
    )

    service = ModelInfoService(
        FakeModel(),
        ["google_index", "domain_age"],
        metadata_path=metadata_path,
        model_path=tmp_path / "missing.pkl",
    )

    result = service.get_info()
    assert result["status"] == "warning"
    assert result["validation"]["feature_order_matches"] is False
