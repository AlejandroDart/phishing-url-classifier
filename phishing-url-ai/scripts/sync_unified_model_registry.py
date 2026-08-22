"""Sincroniza artefactos AI y crea el catálogo multimodelo de la API."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import pandas as pd


AI_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = AI_ROOT.parent
API_MODELS = PROJECT_ROOT / "phishing-url-api" / "models"
ML_MANIFEST = API_MODELS / "ml" / "model_registry.json"


def copy_directory(source: Path, target: Path):
    target.mkdir(parents=True, exist_ok=True)
    for path in source.iterdir():
        if path.is_file():
            shutil.copy2(path, target / path.name)
        elif path.is_dir() and path.name == "plots":
            shutil.copytree(path, target / path.name, dirs_exist_ok=True)


ml = json.loads(ML_MANIFEST.read_text(encoding="utf-8"))
tabular = json.loads(
    (AI_ROOT / "models" / "deep_learning" / "deep_learning_registry.json").read_text(encoding="utf-8")
)
sequential = json.loads(
    (AI_ROOT / "models" / "sequential" / "sequential_registry.json").read_text(encoding="utf-8")
)
hybrid = json.loads(
    (AI_ROOT / "models" / "hybrid" / "hybrid_registry.json").read_text(encoding="utf-8")
)
hybrid_metrics = pd.read_csv(AI_ROOT / "models" / "hybrid" / "metricas_modelo_hibrido.csv")

copy_directory(AI_ROOT / "models" / "deep_learning", API_MODELS / "deep_learning")
copy_directory(AI_ROOT / "models" / "sequential", API_MODELS / "sequential")
copy_directory(AI_ROOT / "models" / "hybrid", API_MODELS / "hybrid")
shutil.copy2(AI_ROOT / "heuristic_engine.py", API_MODELS / "heuristic_engine.py")

entries = []
for item in ml["models"]:
    entry = dict(item)
    entry.update({
        "family": "machine_learning",
        "runtime_type": "sklearn",
        "artifact": f"ml/{item['artifact']}",
        "background": f"ml/{ml['background']}",
        "framework": "scikit-learn",
        "framework_version": ml.get("framework_version"),
        "features": ml["features"],
        "continuous_features": ml.get("continuous_features", []),
        "dataset": ml["dataset"],
        "recommended": False,
    })
    entries.append(entry)

for item in tabular["models"]:
    entries.append({
        **item,
        "family": "deep_learning_tabular",
        "runtime_type": "keras_tabular",
        "artifact": f"deep_learning/{item['artifact']}",
        "background": "deep_learning/shap_background_top25.pkl",
        "framework": "TensorFlow/Keras",
        "framework_version": tabular.get("tensorflow_version"),
        "features": tabular["features"],
        "continuous_features": ml.get("continuous_features", []),
        "dataset": tabular["dataset"],
        "trained_at": tabular["exported_at"],
        "recommended": False,
        "explainer": "permutation",
    })

for item in sequential["models"]:
    entries.append({
        **item,
        "artifact": f"sequential/{item['artifact']}",
        "framework": "TensorFlow/Keras",
        "framework_version": sequential.get("tensorflow_version"),
        "features": ["url_characters"],
        "continuous_features": [],
        "dataset": sequential["dataset"],
        "trained_at": sequential["exported_at"],
        "recommended": False,
        "explainer": "character_occlusion",
    })

heuristic_row = hybrid_metrics.loc[hybrid_metrics["model_id"] == "heuristic"].iloc[0]
entries.append({
    "id": "heuristic",
    "display_name": "Motor heurístico",
    "technical_name": "DeterministicUrlHeuristics",
    "description": "Reglas léxicas auditables que identifican señales sospechosas en la URL.",
    "family": "heuristic",
    "runtime_type": "heuristic",
    "recommended": False,
    "threshold": float(hybrid["heuristic_threshold"]),
    "explainer": "rules",
    "framework": "LinkShield Rules",
    "framework_version": "1.0",
    "artifact_id": "rules-v1",
    "trained_at": hybrid["exported_at"],
    "features": ["url"],
    "continuous_features": [],
    "dataset": hybrid["dataset"],
    "metrics": {key: float(heuristic_row[key]) for key in ("accuracy", "precision", "recall", "f1", "roc_auc")},
    "confusion_matrix": {key: int(heuristic_row[key]) for key in ("tn", "fp", "fn", "tp")},
})

entries.append({
    "id": hybrid["id"],
    "display_name": hybrid["display_name"],
    "technical_name": "StackingLogisticEnsemble",
    "description": "Fusión calibrada de Random Forest, MLP, CNN 1D, GRU y reglas heurísticas.",
    "family": "hybrid",
    "runtime_type": "hybrid",
    "recommended": bool(hybrid["recommended"]),
    "threshold": float(hybrid["threshold"]),
    "explainer": "branch_shapley",
    "framework": "scikit-learn + TensorFlow/Keras",
    "framework_version": "1.0",
    "artifact_id": hybrid["artifact_ids"]["meta_classifier"],
    "trained_at": hybrid["exported_at"],
    "features": ml["features"],
    "continuous_features": ml.get("continuous_features", []),
    "dataset": hybrid["dataset"],
    "metrics": hybrid["metrics"],
    "confusion_matrix": hybrid["confusion_matrix"],
    "branches": hybrid["branches"],
    "meta_coefficients": hybrid["meta_coefficients"],
    "artifacts": {
        "random_forest": "hybrid/hybrid_random_forest_branch.pkl",
        "mlp_regularized": "hybrid/hybrid_mlp_branch.keras",
        "meta_classifier": "hybrid/hybrid_meta_classifier.pkl",
        "cnn_1d": "sequential/cnn_1d.keras",
        "gru": "sequential/gru.keras",
    },
})

recommended_id = "hybrid_ensemble" if hybrid["recommended"] else "random_forest"
for entry in entries:
    entry["recommended"] = entry["id"] == recommended_id

catalog = {
    "schema_version": 2,
    "default_model_id": recommended_id,
    "exported_at": hybrid["exported_at"],
    "models": entries,
}
(API_MODELS / "model_registry.json").write_text(
    json.dumps(catalog, ensure_ascii=False, indent=2), encoding="utf-8"
)
print(API_MODELS / "model_registry.json")
print("Modelos:", len(entries), "Recomendado:", recommended_id)
