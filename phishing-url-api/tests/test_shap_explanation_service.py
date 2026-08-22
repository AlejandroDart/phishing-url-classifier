import numpy as np
import pandas as pd

from services.shap_explanation_service import ShapExplanationService


class FakeModel:
    classes_ = np.array([0, 1])


class FakeExplainer:
    expected_value = np.array([0.6, 0.4])

    def shap_values(self, features, check_additivity=True):
        assert check_additivity is True
        return np.array([[[ -0.15, 0.15], [0.05, -0.05]]])


def test_explains_phishing_probability_and_ranks_absolute_impact():
    scaled = pd.DataFrame([{"phish_hints": 1.2, "domain_age": -0.4}])
    raw = pd.DataFrame([{"phish_hints": 2, "domain_age": 30}])
    service = ShapExplanationService(
        FakeModel(),
        explainer_factory=lambda model: FakeExplainer(),
    )

    result = service.explain(scaled, raw, probability=0.5)

    assert result["available"] is True
    assert result["explained_output"] == "phishing_probability"
    assert result["reconstructed_probability"] == 0.5
    assert result["additivity_error"] == 0.0
    assert result["top_factors"][0]["feature"] == "phish_hints"
    assert result["top_factors"][0]["effect"] == "supports_phishing"
    assert result["top_factors"][1]["effect"] == "supports_legitimate"


def test_supports_legacy_list_output_from_older_shap_versions():
    values = [
        np.array([[-0.2, 0.1]]),
        np.array([[0.2, -0.1]]),
    ]

    selected = ShapExplanationService._select_class_values(values, 1)

    assert selected.tolist() == [0.2, -0.1]
