import hashlib
import json
from copy import deepcopy
from pathlib import Path
from typing import Any

from services.feature_knowledge import FEATURE_KNOWLEDGE


BASE_DIR = Path(__file__).resolve().parent.parent
DEFAULT_METADATA_PATH = (
    BASE_DIR / "models" / "ml" / "metadata_reentrenamiento_top25.json"
)
DEFAULT_MODEL_PATH = BASE_DIR / "models" / "ml" / "mejor_modelo_ml.pkl"


class ModelInfoService:
    """Builds a public, validated view of the active classifier metadata."""

    def __init__(
        self,
        model,
        feature_names,
        *,
        metadata: dict[str, Any] | None = None,
        metadata_path: Path = DEFAULT_METADATA_PATH,
        model_path: Path = DEFAULT_MODEL_PATH,
    ):
        self.model = model
        self.feature_names = list(feature_names)
        self.metadata_path = Path(metadata_path)
        self.model_path = Path(model_path) if model_path is not None else None
        self.metadata = deepcopy(metadata) if metadata is not None else None
        self._cached: dict[str, Any] | None = None

    def _load_metadata(self) -> dict[str, Any]:
        if self.metadata is not None:
            return deepcopy(self.metadata)
        if not self.metadata_path.exists():
            raise FileNotFoundError("No se encontraron los metadatos del modelo")
        with self.metadata_path.open("r", encoding="utf-8") as metadata_file:
            return json.load(metadata_file)

    def _artifact_id(self) -> str | None:
        if self.metadata is not None and self.metadata.get("artifact_id"):
            return str(self.metadata["artifact_id"])
        if self.model_path is None or not self.model_path.exists():
            return None
        digest = hashlib.sha256()
        with self.model_path.open("rb") as model_file:
            for chunk in iter(lambda: model_file.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()[:12]

    def _feature_info(
        self,
        continuous_features: set[str],
    ) -> list[dict[str, Any]]:
        features = []
        for index, key in enumerate(self.feature_names, start=1):
            knowledge = FEATURE_KNOWLEDGE.get(key, {})
            features.append({
                "position": index,
                "key": key,
                "label": knowledge.get("label", key),
                "description": knowledge.get(
                    "description",
                    "Característica utilizada por el clasificador.",
                ),
                "kind": knowledge.get("kind", "numeric"),
                "continuous": key in continuous_features,
            })
        return features

    def get_info(self) -> dict[str, Any]:
        if self._cached is not None:
            return deepcopy(self._cached)

        metadata = self._load_metadata()
        metrics = metadata.get("metrics", {})
        metadata_features = list(metadata.get("features", []))
        continuous_features = set(metadata.get("continuous_features", []))
        feature_order_matches = metadata_features == self.feature_names

        tn = int(metrics.get("tn", 0))
        fp = int(metrics.get("fp", 0))
        fn = int(metrics.get("fn", 0))
        tp = int(metrics.get("tp", 0))
        test_rows = int(metrics.get("test_rows", tn + fp + fn + tp))
        train_rows = int(metrics.get("train_rows", 0))
        total_rows = int(metrics.get("rows", train_rows + test_rows))
        legitimate_rows = int(
            metadata.get("class_distribution", {}).get("legitimate", 0)
        )
        phishing_rows = int(
            metadata.get("class_distribution", {}).get("phishing", 0)
        )

        model_type = metadata.get("technical_name") or type(self.model).__name__
        model_module = (
            type(self.model).__module__
            if self.model is not None
            else "linkshield.rules"
        )
        model_params = metadata.get("model_params", {})
        runtime_feature_count = int(
            getattr(self.model, "n_features_in_", len(self.feature_names))
        )
        status = (
            "ready"
            if feature_order_matches and runtime_feature_count == len(self.feature_names)
            else "warning"
        )

        payload = {
            "status": status,
            "validated": status == "ready",
            "model": {
                "id": metadata.get("model_id", "random_forest"),
                "display_name": metadata.get(
                    "display_name", "LinkShield Random Forest Top 25"
                ),
                "description": metadata.get("description", ""),
                "recommended": bool(metadata.get("recommended", False)),
                "technical_name": model_type,
                "module": model_module,
                "version": str(metadata.get("created_at") or "")[:10],
                "trained_at": metadata.get("created_at"),
                "artifact_id": self._artifact_id(),
                "framework": metadata.get("framework", "scikit-learn"),
                "framework_version": (
                    metadata.get("framework_version")
                    or metadata.get("sklearn_version")
                ),
                "family": metadata.get("family", "machine_learning"),
                "runtime_type": metadata.get("runtime_type", "sklearn"),
                "threshold": float(metadata.get("threshold", 0.5)),
                "estimators": int(
                    getattr(
                        self.model,
                        "n_estimators",
                        model_params.get("n_estimators", 0),
                    )
                ),
                "criterion": getattr(
                    self.model,
                    "criterion",
                    model_params.get("criterion"),
                ),
                "class_weight": getattr(
                    self.model,
                    "class_weight",
                    model_params.get("class_weight"),
                ),
                "max_features": getattr(
                    self.model,
                    "max_features",
                    model_params.get("max_features"),
                ),
                "random_state": getattr(
                    self.model,
                    "random_state",
                    model_params.get("random_state"),
                ),
                "feature_count": len(self.feature_names),
                "continuous_feature_count": int(
                    metadata.get("continuous_feature_count", len(continuous_features))
                ),
            },
            "dataset": {
                "name": metrics.get("dataset", "dataset no informado"),
                "total_rows": total_rows,
                "train_rows": train_rows,
                "test_rows": test_rows,
                "train_ratio": train_rows / total_rows if total_rows else 0,
                "test_ratio": test_rows / total_rows if total_rows else 0,
                "legitimate_rows": legitimate_rows,
                "phishing_rows": phishing_rows,
                "test_legitimate_rows": tn + fp,
                "test_phishing_rows": fn + tp,
            },
            "metrics": {
                "accuracy": float(metrics.get("accuracy", 0)),
                "precision": float(metrics.get("precision", 0)),
                "recall": float(metrics.get("recall", 0)),
                "f1": float(metrics.get("f1", 0)),
                "roc_auc": float(metrics.get("roc_auc", 0)),
            },
            "confusion_matrix": {
                "tn": tn,
                "fp": fp,
                "fn": fn,
                "tp": tp,
                "total": tn + fp + fn + tp,
                "correct": tn + tp,
                "errors": fp + fn,
                "actual_labels": ["Legítima", "Phishing"],
                "predicted_labels": ["Legítima", "Phishing"],
            },
            "features": self._feature_info(continuous_features),
            "branches": metadata.get("branches", []),
            "meta_coefficients": metadata.get("meta_coefficients", {}),
            "validation": {
                "feature_order_matches": feature_order_matches,
                "runtime_feature_count": runtime_feature_count,
                "metadata_feature_count": len(metadata_features),
                "source": "training_metadata",
            },
            "notes": [
                "Las métricas corresponden al conjunto de prueba del último entrenamiento.",
                "La matriz usa la clase phishing como positiva.",
                "El rendimiento histórico no garantiza el resultado de una URL individual.",
            ],
        }
        self._cached = payload
        return deepcopy(payload)
