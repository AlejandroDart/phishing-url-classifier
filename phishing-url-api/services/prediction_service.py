from dataclasses import dataclass
from datetime import datetime, timezone
from itertools import combinations
from math import factorial
from typing import Any, Callable
from urllib.parse import quote

import numpy as np
import pandas as pd

from database.prediction_repository import save_prediction
from services.feature_extractor_top25 import (
    extract_top25_features,
    load_feature_names,
    scale_top25_features,
)
from services.model_registry_service import ModelRuntime, model_registry
from services.shap_explanation_service import ShapExplanationService
from services.sensitivity_service import resolve_sensitivity_threshold
from models.heuristic_engine import analyze_url_heuristics


class KerasProbabilityAdapter:
    """Adapta una salida sigmoide a la interfaz de probabilidad de SHAP."""

    classes_ = np.array([0, 1])

    def __init__(self, model):
        self.model = model

    def predict_proba(self, values):
        probabilities = np.asarray(
            self.model.predict(values, verbose=0)
        ).reshape(-1)
        return np.column_stack([1 - probabilities, probabilities])


@dataclass(frozen=True)
class PredictionResult:
    url: str
    label: str
    probability: float
    explanation: dict[str, Any]
    model_id: str
    model_name: str
    sensitivity_profile: str
    base_threshold: float
    effective_threshold: float
    stored_global: bool
    analyzed_at: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "url": self.url,
            "label": self.label,
            "probability": round(self.probability, 6),
            "explanation": self.explanation,
            "model_id": self.model_id,
            "model_name": self.model_name,
            "sensitivity_profile": self.sensitivity_profile,
            "base_threshold": round(self.base_threshold, 6),
            "effective_threshold": round(self.effective_threshold, 6),
            "stored_global": self.stored_global,
        }


class PredictionService:
    """Single entry point for the existing technical URL classifier."""

    def __init__(
        self,
        model=None,
        feature_names=None,
        extractor: Callable = extract_top25_features,
        scaler: Callable = scale_top25_features,
        repository: Callable = save_prediction,
        shap_service=None,
        registry=None,
    ):
        self.registry = registry or model_registry
        self._fixed_model = model
        if model is None:
            self.model = None
            self.feature_names = load_feature_names()
        else:
            self.model = model
            self.feature_names = (
                list(feature_names) if feature_names is not None else load_feature_names()
            )
        self.extractor = extractor
        self.scaler = scaler
        self.repository = repository
        self.shap_service = (
            shap_service or ShapExplanationService(self.model)
            if self._fixed_model is not None
            else None
        )
        self._shap_services: dict[str, ShapExplanationService] = {}
        self._hybrid_feature_shap_services: dict[str, ShapExplanationService] = {}

    def _runtime(self, model_id: str | None) -> ModelRuntime:
        if self._fixed_model is not None:
            return ModelRuntime(
                model_id=model_id or "test_model",
                display_name=type(self._fixed_model).__name__,
                model=self._fixed_model,
                feature_names=self.feature_names,
                background=None,
                metadata={"explainer": "tree"},
                artifact_path=None,
                family="machine_learning",
                runtime_type="sklearn",
            )
        return self.registry.get_runtime(model_id)

    def _shap_for(self, runtime: ModelRuntime) -> ShapExplanationService:
        if self._fixed_model is not None:
            return self.shap_service
        if runtime.model_id not in self._shap_services:
            model = runtime.model
            strategy = runtime.metadata.get("explainer", "tree")
            if runtime.runtime_type == "keras_tabular":
                model = KerasProbabilityAdapter(runtime.model)
                strategy = "permutation"
            self._shap_services[runtime.model_id] = ShapExplanationService(
                model,
                background=runtime.background,
                strategy=strategy,
            )
        return self._shap_services[runtime.model_id]

    @staticmethod
    def _phishing_probability(model, scaled_features) -> float:
        if hasattr(model, "predict_proba"):
            classes = list(model.classes_)
            probabilities = model.predict_proba(scaled_features)[0]
            if 1 in classes:
                return float(probabilities[classes.index(1)])

        return float(int(model.predict(scaled_features)[0]))

    @staticmethod
    def _normalized_sequence(url: str) -> str:
        return quote(
            str(url).strip(),
            safe=":/?#[]@!$&'()*+,;=%-._~",
        )

    @staticmethod
    def _keras_tabular_probability(model, scaled_features) -> float:
        return float(np.asarray(
            model.predict(scaled_features, verbose=0)
        ).reshape(-1)[0])

    @classmethod
    def _keras_sequence_probabilities(cls, model, urls: list[str]) -> np.ndarray:
        import tensorflow as tf

        values = [cls._normalized_sequence(url) for url in urls]
        return np.asarray(model(tf.constant(values), training=False)).reshape(-1)

    def _predict_runtime(self, runtime, url, scaled_features):
        if runtime.runtime_type == "sklearn":
            return self._phishing_probability(runtime.model, scaled_features), {}
        if runtime.runtime_type == "keras_tabular":
            return self._keras_tabular_probability(runtime.model, scaled_features), {}
        if runtime.runtime_type == "keras_sequence":
            probability = float(self._keras_sequence_probabilities(runtime.model, [url])[0])
            return probability, {}
        if runtime.runtime_type == "heuristic":
            result = analyze_url_heuristics(url)
            return result.probability, {"heuristic": result.to_dict()}
        if runtime.runtime_type == "hybrid":
            models = runtime.model
            heuristic = analyze_url_heuristics(url)
            components = {
                "random_forest": self._phishing_probability(models["random_forest"], scaled_features),
                "mlp_regularized": self._keras_tabular_probability(models["mlp_regularized"], scaled_features),
                "cnn_1d": float(self._keras_sequence_probabilities(models["cnn_1d"], [url])[0]),
                "gru": float(self._keras_sequence_probabilities(models["gru"], [url])[0]),
                "heuristic": heuristic.probability,
            }
            frame = pd.DataFrame([components], columns=runtime.entry["branches"])
            probability = float(models["meta_classifier"].predict_proba(frame)[0, 1])
            return probability, {
                "components": {key: round(value, 8) for key, value in components.items()},
                "heuristic": heuristic.to_dict(),
            }
        raise ValueError(f"Runtime no soportado: {runtime.runtime_type}")

    @staticmethod
    def _factor_payload(name, display_name, description, value, impact):
        direction = "increases_phishing" if impact > 0 else "decreases_phishing"
        return {
            "feature": name,
            "display_name": display_name,
            "description": description,
            "raw_value": value,
            "model_value": value,
            "shap_value": round(float(impact), 8),
            "absolute_impact": round(abs(float(impact)), 8),
            "direction": direction if abs(impact) > 1e-12 else "neutral",
            "effect": "supports_phishing" if impact > 0 else "supports_legitimate",
            "raw_value_meaning": description,
        }

    def _sequence_explanation(self, runtime, url, probability):
        normalized = self._normalized_sequence(url)
        chunk_size = max(8, int(np.ceil(len(normalized) / 10)))
        variants = []
        chunks = []
        for start in range(0, len(normalized), chunk_size):
            end = min(len(normalized), start + chunk_size)
            chunks.append((start, end, normalized[start:end]))
            variants.append(normalized[:start] + normalized[end:])
        masked = self._keras_sequence_probabilities(runtime.model, variants) if variants else np.array([])
        factors = [
            self._factor_payload(
                f"url_segment_{index + 1}",
                f"Fragmento: {fragment}",
                "Impacto estimado al ocultar este fragmento de la URL.",
                fragment,
                probability - float(masked[index]),
            )
            for index, (_, _, fragment) in enumerate(chunks)
        ]
        ranked = sorted(factors, key=lambda item: item["absolute_impact"], reverse=True)
        return {
            "available": True,
            "method": "CharacterOcclusion",
            "explained_output": "phishing_probability",
            "base_probability": None,
            "predicted_probability": round(probability, 8),
            "top_factors": ranked[:8],
            "supporting_phishing": [item for item in ranked if item["shap_value"] > 0][:5],
            "supporting_legitimate": [item for item in ranked if item["shap_value"] < 0][:5],
            "all_contributions": factors,
        }

    def _heuristic_explanation(self, details, probability):
        rules = details["heuristic"].get("rules", [])
        base = analyze_url_heuristics("").probability
        delta = probability - base
        total_weight = sum(float(rule["weight"]) for rule in rules) or 1
        factors = [
            self._factor_payload(
                rule["id"], rule["label"], rule["description"],
                rule["evidence"], delta * float(rule["weight"]) / total_weight,
            )
            for rule in rules
        ]
        ranked = sorted(factors, key=lambda item: item["absolute_impact"], reverse=True)
        return {
            "available": True, "method": "HeuristicRules",
            "explained_output": "phishing_probability",
            "base_probability": round(base, 8),
            "predicted_probability": round(probability, 8),
            "reconstructed_probability": round(base + sum(item["shap_value"] for item in factors), 8),
            "top_factors": ranked[:8],
            "supporting_phishing": [item for item in ranked if item["shap_value"] > 0][:5],
            "supporting_legitimate": [], "all_contributions": factors,
        }

    def _hybrid_feature_factors(
        self,
        runtime,
        details,
        scaled_features,
        raw_features,
    ):
        factors = []
        all_factors = []
        cache_key = f"{runtime.model_id}:random_forest"

        try:
            if cache_key not in self._hybrid_feature_shap_services:
                self._hybrid_feature_shap_services[cache_key] = (
                    ShapExplanationService(runtime.model["random_forest"])
                )
            random_forest_explanation = self._hybrid_feature_shap_services[
                cache_key
            ].explain(
                scaled_features,
                raw_features,
                details["components"]["random_forest"],
            )
            for factor in random_forest_explanation.get("all_contributions", []):
                enriched = dict(factor)
                enriched.update({
                    "source": "random_forest",
                    "source_name": "Random Forest Top 25",
                    "scope": "branch_probability",
                })
                all_factors.append(enriched)
            factors.extend(sorted(
                all_factors,
                key=lambda item: item.get("absolute_impact", 0),
                reverse=True,
            )[:5])
        except Exception:
            pass

        heuristic_details = details.get("heuristic", {})
        for rule in heuristic_details.get("rules", [])[:3]:
            heuristic_factor = {
                "feature": rule.get("id", "heuristic_rule"),
                "display_name": rule.get("label", "Regla heuristica"),
                "description": rule.get(
                    "description",
                    "Senal lexica observada directamente en la URL.",
                ),
                "raw_value": rule.get("evidence"),
                "raw_value_meaning": (
                    f"Evidencia observada: {rule.get('evidence')}"
                    if rule.get("evidence")
                    else "Regla activada por la URL analizada."
                ),
                "shap_value": float(rule.get("weight", 0)) / 100,
                "absolute_impact": abs(float(rule.get("weight", 0))) / 100,
                "direction": "increases_phishing",
                "effect": "supports_phishing",
                "source": "heuristic",
                "source_name": "Motor heuristico",
                "scope": "observed_rule",
            }
            factors.append(heuristic_factor)
            all_factors.append(heuristic_factor)

        return {
            "top_factors": sorted(
                factors,
                key=lambda item: item.get("absolute_impact", 0),
                reverse=True,
            )[:8],
            "all_contributions": sorted(
                all_factors,
                key=lambda item: item.get("absolute_impact", 0),
                reverse=True,
            ),
        }

    def _hybrid_explanation(
        self,
        runtime,
        details,
        probability,
        scaled_features,
        raw_features,
    ):
        names = list(runtime.entry["branches"])
        values = details["components"]
        model = runtime.model["meta_classifier"]
        baseline = {name: 0.5 for name in names}

        def value_of(active):
            row = {name: values[name] if name in active else baseline[name] for name in names}
            frame = pd.DataFrame([row], columns=names)
            return float(model.predict_proba(frame)[0, 1])

        contributions = {name: 0.0 for name in names}
        n = len(names)
        for name in names:
            others = [item for item in names if item != name]
            for size in range(len(others) + 1):
                weight = factorial(size) * factorial(n - size - 1) / factorial(n)
                for subset in combinations(others, size):
                    active = set(subset)
                    contributions[name] += weight * (value_of(active | {name}) - value_of(active))

        labels = {
            "random_forest": "Random Forest Top 25", "mlp_regularized": "MLP regularizada",
            "cnn_1d": "CNN 1D por caracteres", "gru": "GRU por caracteres",
            "heuristic": "Motor heurístico",
        }
        factors = [self._factor_payload(
            name, labels[name], "Contribución de esta rama a la probabilidad híbrida.",
            values[name], contributions[name],
        ) for name in names]
        ranked = sorted(factors, key=lambda item: item["absolute_impact"], reverse=True)
        base = value_of(set())
        feature_explanation = self._hybrid_feature_factors(
            runtime,
            details,
            scaled_features,
            raw_features,
        )
        return {
            "available": True, "method": "ExactBranchShapley",
            "explained_output": "phishing_probability",
            "base_probability": round(base, 8),
            "predicted_probability": round(probability, 8),
            "reconstructed_probability": round(base + sum(contributions.values()), 8),
            "additivity_error": round(abs(base + sum(contributions.values()) - probability), 10),
            "top_factors": ranked, "supporting_phishing": [item for item in ranked if item["shap_value"] > 0],
            "supporting_legitimate": [item for item in ranked if item["shap_value"] < 0],
            "all_contributions": factors,
            "feature_factors": feature_explanation["top_factors"],
            "all_feature_contributions": feature_explanation["all_contributions"],
            "feature_factor_scope": "branch_diagnostics",
        }

    def analyze(
        self,
        url: str,
        *,
        store_global: bool = False,
        use_network_features: bool = True,
        model_id: str | None = None,
        sensitivity_profile: str | None = None,
    ) -> PredictionResult:
        runtime = self._runtime(model_id)
        needs_top25 = runtime.runtime_type in {"sklearn", "keras_tabular", "hybrid"}
        raw_features = None
        scaled_features = None
        if needs_top25:
            raw_features = self.extractor(url, use_network_features=use_network_features)
            scaled_features = self.scaler(raw_features)

        if runtime.runtime_type == "sklearn" and hasattr(runtime.model, "feature_names_in_"):
            if list(runtime.model.feature_names_in_) != list(scaled_features.columns):
                raise ValueError("El orden de features no coincide con el modelo")

        probability, runtime_details = self._predict_runtime(runtime, url, scaled_features)
        sensitivity = resolve_sensitivity_threshold(
            float(runtime.metadata.get("threshold", 0.5)),
            sensitivity_profile,
        )
        label = (
            "phishing"
            if probability >= sensitivity.effective_threshold
            else "no-phishing"
        )
        raw_features_dict = {}
        if raw_features is not None:
            raw_features_dict = {
                key: value.item() if hasattr(value, "item") else value
                for key, value in raw_features.iloc[0].to_dict().items()
            }
        explanation = {
            "message": f"Top25 feature extraction with {runtime.display_name}",
            "model": {
                "id": runtime.model_id,
                "name": runtime.display_name,
                "technical_name": type(runtime.model).__name__,
                "threshold": sensitivity.effective_threshold,
                "base_threshold": sensitivity.base_threshold,
                "effective_threshold": sensitivity.effective_threshold,
                "sensitivity_profile": sensitivity.profile,
                "family": runtime.family,
            },
            "features": raw_features_dict,
            "feature_order": runtime.feature_names,
            **runtime_details,
        }
        try:
            if runtime.runtime_type in {"sklearn", "keras_tabular"}:
                explanation["shap"] = self._shap_for(runtime).explain(scaled_features, raw_features, probability)
            elif runtime.runtime_type == "keras_sequence":
                explanation["shap"] = self._sequence_explanation(runtime, url, probability)
            elif runtime.runtime_type == "heuristic":
                explanation["shap"] = self._heuristic_explanation(runtime_details, probability)
            else:
                explanation["shap"] = self._hybrid_explanation(
                    runtime,
                    runtime_details,
                    probability,
                    scaled_features,
                    raw_features,
                )
        except Exception as error:
            explanation["shap"] = {
                "available": False,
                "method": runtime.metadata.get("explainer", "unknown"),
                "error": f"No fue posible calcular SHAP: {type(error).__name__}",
            }

        if store_global:
            self.repository(
                url,
                label,
                probability,
                explanation,
                runtime.model_id,
                sensitivity.profile,
                sensitivity.base_threshold,
                sensitivity.effective_threshold,
            )

        return PredictionResult(
            url=url,
            label=label,
            probability=probability,
            explanation=explanation,
            model_id=runtime.model_id,
            model_name=runtime.display_name,
            sensitivity_profile=sensitivity.profile,
            base_threshold=sensitivity.base_threshold,
            effective_threshold=sensitivity.effective_threshold,
            stored_global=store_global,
            analyzed_at=datetime.now(timezone.utc).isoformat(),
        )

    def explain_stored_features(
        self,
        features: dict[str, Any],
        model_id: str | None = None,
    ) -> dict[str, Any]:
        runtime = self._runtime(model_id)
        if runtime.runtime_type not in {"sklearn", "keras_tabular"}:
            raise ValueError("Este modelo requiere la URL original para recalcular su explicación")
        missing = [name for name in self.feature_names if name not in features]
        if missing:
            raise ValueError(
                "Faltan características para calcular SHAP: " + ", ".join(missing)
            )

        raw_features = pd.DataFrame([
            {name: features[name] for name in self.feature_names}
        ])
        for column in self.feature_names:
            raw_features[column] = pd.to_numeric(
                raw_features[column], errors="coerce"
            ).fillna(0)

        scaled_features = self.scaler(raw_features)
        probability, _ = self._predict_runtime(runtime, "", scaled_features)
        shap_explanation = self._shap_for(runtime).explain(
            scaled_features,
            raw_features,
            probability,
        )
        return {
            "label": "phishing" if probability >= 0.5 else "no-phishing",
            "probability": round(probability, 6),
            "shap": shap_explanation,
            "model_id": runtime.model_id,
            "model_name": runtime.display_name,
        }


prediction_service = PredictionService()
