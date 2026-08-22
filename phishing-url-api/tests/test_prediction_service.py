import numpy as np
import pandas as pd

from services.prediction_service import PredictionService


class FakeModel:
    classes_ = np.array([0, 1])
    feature_names_in_ = np.array(["feature_a"])

    def predict_proba(self, features):
        return np.array([[0.25, 0.75]])


class FakeModerateModel(FakeModel):
    def predict_proba(self, features):
        return np.array([[0.40, 0.60]])


class FakeShapService:
    def explain(self, scaled_features, raw_features, probability):
        return {
            "available": True,
            "method": "TreeExplainer",
            "predicted_probability": probability,
            "top_factors": [],
        }


def test_prediction_service_preserves_route_contract():
    stored = []
    raw = pd.DataFrame([{"feature_a": np.int64(3)}])
    service = PredictionService(
        model=FakeModel(),
        feature_names=["feature_a"],
        extractor=lambda url, use_network_features: raw,
        scaler=lambda features: features,
        repository=lambda *args: stored.append(args),
        shap_service=FakeShapService(),
    )

    result = service.analyze("https://example.com", store_global=True)
    payload = result.to_dict()

    assert payload["url"] == "https://example.com"
    assert payload["label"] == "phishing"
    assert payload["probability"] == 0.75
    assert payload["stored_global"] is True
    assert payload["explanation"]["features"] == {"feature_a": 3}
    assert payload["explanation"]["shap"]["available"] is True
    assert payload["model_id"] == "test_model"
    assert payload["model_name"] == "FakeModel"
    assert len(stored) == 1
    assert stored[0][4] == "test_model"


def test_rebuilds_shap_from_stored_features_without_fetching_url():
    raw = pd.DataFrame([{"feature_a": np.int64(3)}])
    service = PredictionService(
        model=FakeModel(),
        feature_names=["feature_a"],
        extractor=lambda url, use_network_features: raw,
        scaler=lambda features: features,
        repository=lambda *args: None,
        shap_service=FakeShapService(),
    )

    result = service.explain_stored_features({"feature_a": 3})

    assert result["label"] == "phishing"
    assert result["probability"] == 0.75
    assert result["shap"]["available"] is True


def test_sensitivity_changes_decision_without_changing_probability():
    raw = pd.DataFrame([{"feature_a": np.int64(3)}])
    service = PredictionService(
        model=FakeModerateModel(),
        feature_names=["feature_a"],
        extractor=lambda url, use_network_features: raw,
        scaler=lambda features: features,
        repository=lambda *args: None,
        shap_service=FakeShapService(),
    )

    aggressive = service.analyze(
        "https://example.com", sensitivity_profile="aggressive"
    )
    passive = service.analyze(
        "https://example.com", sensitivity_profile="passive"
    )

    assert aggressive.probability == passive.probability == 0.60
    assert aggressive.label == "phishing"
    assert passive.label == "no-phishing"
    assert aggressive.effective_threshold == 0.25
    assert passive.effective_threshold == 0.75
