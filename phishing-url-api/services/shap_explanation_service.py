import threading
from typing import Any, Callable

import numpy as np
import shap

from services.feature_knowledge import FEATURE_KNOWLEDGE, describe_feature_value


class ShapExplanationService:
    """Produces local attributions for the phishing probability."""

    def __init__(
        self,
        model,
        *,
        explainer_factory: Callable | None = None,
        background=None,
        strategy: str | None = None,
        top_limit: int = 8,
    ):
        self.model = model
        self.explainer_factory = explainer_factory
        self.background = background
        self.strategy = strategy or "tree"
        self.top_limit = top_limit
        self._explainer = None
        self._lock = threading.RLock()

    def _get_explainer(self):
        with self._lock:
            if self._explainer is None:
                if self.explainer_factory is not None:
                    self._explainer = self.explainer_factory(self.model)
                elif self.strategy == "tree":
                    self._explainer = shap.TreeExplainer(
                        self.model,
                        feature_perturbation="tree_path_dependent",
                    )
                else:
                    if self.background is None:
                        raise ValueError(
                            "El explicador por permutación requiere datos de referencia"
                        )
                    masker = shap.maskers.Independent(
                        self.background,
                        max_samples=min(50, len(self.background)),
                    )
                    self._explainer = shap.Explainer(
                        self.model.predict_proba,
                        masker,
                        algorithm="permutation",
                        feature_names=list(self.background.columns),
                    )
            return self._explainer

    def _phishing_class_index(self) -> int:
        classes = list(getattr(self.model, "classes_", [0, 1]))
        return classes.index(1) if 1 in classes else len(classes) - 1

    @staticmethod
    def _select_class_values(values, class_index: int) -> np.ndarray:
        if isinstance(values, list):
            return np.asarray(values[class_index])[0]

        array = np.asarray(values)
        if array.ndim == 3:
            return array[0, :, class_index]
        if array.ndim == 2:
            return array[0]
        if array.ndim == 1:
            return array
        raise ValueError(f"Formato SHAP no compatible: {array.shape}")

    @staticmethod
    def _select_base_value(expected_value, class_index: int) -> float:
        values = np.asarray(expected_value).reshape(-1)
        if values.size == 1:
            return float(values[0])
        return float(values[class_index])

    def explain(self, scaled_features, raw_features, probability: float) -> dict[str, Any]:
        explainer = self._get_explainer()
        class_index = self._phishing_class_index()
        if self.strategy == "tree" or self.explainer_factory is not None:
            with self._lock:
                shap_values = explainer.shap_values(
                    scaled_features,
                    check_additivity=True,
                )
            contributions = self._select_class_values(shap_values, class_index)
            base_value = self._select_base_value(
                explainer.expected_value,
                class_index,
            )
            method = "TreeExplainer"
        else:
            with self._lock:
                explanation = explainer(
                    scaled_features,
                    max_evals=max(2 * scaled_features.shape[1] + 1, 51),
                    silent=True,
                )
            contributions = self._select_class_values(
                explanation.values,
                class_index,
            )
            base_value = self._select_base_value(
                explanation.base_values,
                class_index,
            )
            method = "PermutationExplainer"
        feature_names = list(scaled_features.columns)
        raw_row = raw_features.iloc[0]
        scaled_row = scaled_features.iloc[0]

        factors = []
        for index, feature in enumerate(feature_names):
            shap_value = float(contributions[index])
            if shap_value > 1e-12:
                direction = "increases_phishing"
                effect = "supports_phishing"
            elif shap_value < -1e-12:
                direction = "decreases_phishing"
                effect = "supports_legitimate"
            else:
                direction = "neutral"
                effect = "neutral"

            raw_value = raw_row.get(feature, 0)
            model_value = scaled_row.get(feature, 0)
            factors.append({
                "feature": feature,
                "display_name": FEATURE_KNOWLEDGE.get(feature, {}).get(
                    "label", feature
                ),
                "description": FEATURE_KNOWLEDGE.get(feature, {}).get(
                    "description", "Característica técnica utilizada por el modelo."
                ),
                "raw_value": raw_value.item() if hasattr(raw_value, "item") else raw_value,
                "model_value": (
                    model_value.item() if hasattr(model_value, "item") else model_value
                ),
                "shap_value": round(shap_value, 8),
                "absolute_impact": round(abs(shap_value), 8),
                "direction": direction,
                "effect": effect,
                "raw_value_meaning": describe_feature_value(feature, raw_value),
            })

        ranked = sorted(factors, key=lambda item: item["absolute_impact"], reverse=True)
        supporting_phishing = sorted(
            (item for item in factors if item["shap_value"] > 0),
            key=lambda item: item["shap_value"],
            reverse=True,
        )[:5]
        supporting_legitimate = sorted(
            (item for item in factors if item["shap_value"] < 0),
            key=lambda item: item["shap_value"],
        )[:5]
        reconstructed = base_value + float(np.sum(contributions))

        return {
            "available": True,
            "method": method,
            "explained_output": "phishing_probability",
            "base_probability": round(base_value, 8),
            "predicted_probability": round(float(probability), 8),
            "reconstructed_probability": round(reconstructed, 8),
            "additivity_error": round(abs(reconstructed - float(probability)), 10),
            "top_factors": ranked[: self.top_limit],
            "supporting_phishing": supporting_phishing,
            "supporting_legitimate": supporting_legitimate,
            "all_contributions": factors,
        }
