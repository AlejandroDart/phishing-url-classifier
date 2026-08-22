from __future__ import annotations

import json
import threading
from copy import deepcopy
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import joblib


BASE_DIR = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST_PATH = BASE_DIR / "models" / "model_registry.json"


class UnknownModelError(ValueError):
    pass


@dataclass(frozen=True)
class ModelRuntime:
    model_id: str
    display_name: str
    model: Any
    feature_names: list[str]
    background: Any
    metadata: dict[str, Any]
    artifact_path: Path | None
    family: str = "machine_learning"
    runtime_type: str = "sklearn"
    entry: dict[str, Any] | None = None


class ModelRegistryService:
    """Registro inmutable y carga diferida de clasificadores exportados."""

    def __init__(self, manifest_path: Path = DEFAULT_MANIFEST_PATH):
        self.manifest_path = Path(manifest_path)
        self.base_dir = self.manifest_path.parent
        self._lock = threading.RLock()
        self._manifest = self._load_manifest()
        self._models = {
            entry["id"]: entry for entry in self._manifest.get("models", [])
        }
        self._runtime_cache: dict[str, ModelRuntime] = {}
        if self.default_model_id not in self._models:
            raise ValueError("El modelo predeterminado no existe en el registro")

    def _load_manifest(self) -> dict[str, Any]:
        if not self.manifest_path.exists():
            raise FileNotFoundError("No se encontró el registro de modelos")
        with self.manifest_path.open("r", encoding="utf-8") as file:
            manifest = json.load(file)
        if not isinstance(manifest.get("models"), list) or not manifest["models"]:
            raise ValueError("El registro de modelos está vacío")
        return manifest

    @property
    def default_model_id(self) -> str:
        return str(self._manifest.get("default_model_id", "random_forest"))

    def normalize_model_id(self, model_id: str | None) -> str:
        resolved = (model_id or self.default_model_id).strip().lower()
        if resolved not in self._models:
            raise UnknownModelError(f"Modelo no disponible: {resolved}")
        return resolved

    def _safe_path(self, relative_path: str) -> Path:
        path = (self.base_dir / relative_path).resolve()
        if self.base_dir.resolve() not in path.parents:
            raise ValueError("Ruta de artefacto inválida")
        return path

    def _public_summary(self, entry: dict[str, Any]) -> dict[str, Any]:
        metrics = entry.get("metrics", {})
        return {
            "id": entry["id"],
            "display_name": entry.get("display_name", entry["id"]),
            "technical_name": entry.get("technical_name", "-"),
            "description": entry.get("description", ""),
            "family": entry.get("family", "machine_learning"),
            "runtime_type": entry.get("runtime_type", "sklearn"),
            "recommended": bool(entry.get("recommended", False)),
            "threshold": float(entry.get("threshold", 0.5)),
            "explainer": entry.get("explainer", "unknown"),
            "metrics": {
                key: float(metrics.get(key, 0))
                for key in ("accuracy", "precision", "recall", "f1", "roc_auc")
            },
        }

    def list_models(self) -> dict[str, Any]:
        return {
            "default_model_id": self.default_model_id,
            "models": [
                self._public_summary(entry)
                for entry in self._manifest.get("models", [])
            ],
        }

    def model_summary(self, model_id: str | None) -> dict[str, Any]:
        resolved = self.normalize_model_id(model_id)
        return self._public_summary(self._models[resolved])

    def _metadata(self, entry: dict[str, Any]) -> dict[str, Any]:
        dataset = entry.get("dataset", self._manifest.get("dataset", {}))
        matrix = entry.get("confusion_matrix", {})
        metrics = dict(entry.get("metrics", {}))
        metrics.update({
            "dataset": dataset.get("name"),
            "rows": dataset.get("total_rows", 0),
            "train_rows": dataset.get("train_rows", 0),
            "test_rows": dataset.get("test_rows", 0),
            "tn": matrix.get("tn", 0),
            "fp": matrix.get("fp", 0),
            "fn": matrix.get("fn", 0),
            "tp": matrix.get("tp", 0),
        })
        return {
            "model_id": entry["id"],
            "display_name": entry.get("display_name"),
            "description": entry.get("description"),
            "recommended": bool(entry.get("recommended", False)),
            "created_at": entry.get("trained_at"),
            "artifact_id": entry.get("artifact_id"),
            "sklearn_version": entry.get("framework_version"),
            "framework": entry.get("framework", "scikit-learn"),
            "framework_version": entry.get("framework_version"),
            "family": entry.get("family", "machine_learning"),
            "runtime_type": entry.get("runtime_type", "sklearn"),
            "technical_name": entry.get("technical_name"),
            "features": list(entry.get("features", [])),
            "continuous_features": list(
                entry.get("continuous_features", [])
            ),
            "continuous_feature_count": int(
                len(entry.get("continuous_features", []))
            ),
            "model_params": deepcopy(entry.get("params", {})),
            "metrics": metrics,
            "class_distribution": {
                "legitimate": dataset.get("legitimate_rows", 0),
                "phishing": dataset.get("phishing_rows", 0),
            },
            "dataset": deepcopy(dataset),
            "threshold": float(entry.get("threshold", 0.5)),
            "explainer": entry.get("explainer", "unknown"),
            "branches": deepcopy(entry.get("branches", [])),
            "meta_coefficients": deepcopy(entry.get("meta_coefficients", {})),
        }

    def _load_keras(self, path: Path):
        from tensorflow import keras

        return keras.models.load_model(path)

    def _load_hybrid(self, entry: dict[str, Any]) -> dict[str, Any]:
        artifacts = entry.get("artifacts", {})
        return {
            "random_forest": joblib.load(self._safe_path(artifacts["random_forest"])),
            "mlp_regularized": self._load_keras(self._safe_path(artifacts["mlp_regularized"])),
            "cnn_1d": self._load_keras(self._safe_path(artifacts["cnn_1d"])),
            "gru": self._load_keras(self._safe_path(artifacts["gru"])),
            "meta_classifier": joblib.load(self._safe_path(artifacts["meta_classifier"])),
        }

    def get_runtime(self, model_id: str | None = None) -> ModelRuntime:
        resolved = self.normalize_model_id(model_id)
        with self._lock:
            cached = self._runtime_cache.get(resolved)
            if cached is not None:
                return cached

            entry = self._models[resolved]
            runtime_type = entry.get("runtime_type", "sklearn")
            artifact_path = (
                self._safe_path(entry["artifact"])
                if entry.get("artifact")
                else None
            )
            if runtime_type == "sklearn":
                model = joblib.load(artifact_path)
            elif runtime_type in {"keras_tabular", "keras_sequence"}:
                model = self._load_keras(artifact_path)
            elif runtime_type == "hybrid":
                model = self._load_hybrid(entry)
            elif runtime_type == "heuristic":
                model = None
            else:
                raise ValueError(f"Tipo de runtime no soportado: {runtime_type}")
            if hasattr(model, "n_jobs"):
                model.n_jobs = 1
            feature_names = list(entry.get("features", []))
            runtime_features = list(getattr(model, "feature_names_in_", feature_names))
            if runtime_type == "sklearn" and runtime_features != feature_names:
                raise ValueError(
                    f"El artefacto {resolved} no coincide con las variables registradas"
                )
            background_path = entry.get("background")
            runtime = ModelRuntime(
                model_id=resolved,
                display_name=entry.get("display_name", resolved),
                model=model,
                feature_names=feature_names,
                background=(
                    joblib.load(self._safe_path(background_path))
                    if background_path
                    else None
                ),
                metadata=self._metadata(entry),
                artifact_path=artifact_path,
                family=entry.get("family", "machine_learning"),
                runtime_type=runtime_type,
                entry=deepcopy(entry),
            )
            self._runtime_cache[resolved] = runtime
            return runtime


model_registry = ModelRegistryService()
