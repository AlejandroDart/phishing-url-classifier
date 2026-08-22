"""Exporta los seis clasificadores Top 25 usados por LinkShield AI."""

from __future__ import annotations

import hashlib
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

import joblib
import pandas as pd
import sklearn
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split
from sklearn.neighbors import KNeighborsClassifier
from sklearn.svm import SVC
from sklearn.tree import DecisionTreeClassifier


ROOT = Path(__file__).resolve().parents[2]
API_MODELS = ROOT / "phishing-url-api" / "models" / "ml"
DATASET = ROOT / "phishing-url-ai" / "dataset-phishing-final-top25.csv"
ACTIVE_RANDOM_FOREST = API_MODELS / "mejor_modelo_ml.pkl"
SCALER_PATH = ROOT / "phishing-url-api" / "models" / "scaler_top.pkl"
OUTPUT_DIR = API_MODELS / "registry"
MANIFEST_PATH = API_MODELS / "model_registry.json"
TARGET = "status"
RANDOM_STATE = 42
TEST_SIZE = 0.2


MODEL_SPECS = {
    "logistic_regression": {
        "display_name": "Regresión Logística",
        "description": "Modelo lineal rápido e interpretable para establecer una referencia.",
        "factory": lambda: LogisticRegression(max_iter=1000, random_state=RANDOM_STATE),
        "explainer": "permutation",
    },
    "decision_tree": {
        "display_name": "Árbol de Decisión",
        "description": "Clasificador basado en reglas y divisiones sucesivas de las variables.",
        "factory": lambda: DecisionTreeClassifier(
            random_state=RANDOM_STATE,
            class_weight="balanced",
        ),
        "explainer": "tree",
    },
    "random_forest": {
        "display_name": "Random Forest Top 25",
        "description": "Modelo recomendado y de mejor F1-score en la evaluación comparativa.",
        "factory": None,
        "explainer": "tree",
        "recommended": True,
    },
    "gradient_boosting": {
        "display_name": "Gradient Boosting",
        "description": "Ensamble secuencial que corrige progresivamente los errores anteriores.",
        "factory": lambda: GradientBoostingClassifier(random_state=RANDOM_STATE),
        "explainer": "permutation",
    },
    "knn": {
        "display_name": "K-Nearest Neighbors",
        "description": "Clasifica comparando la URL con sus cinco muestras más cercanas.",
        "factory": lambda: KNeighborsClassifier(n_neighbors=5),
        "explainer": "permutation",
    },
    "svm": {
        "display_name": "Support Vector Machine",
        "description": "Clasificador de margen máximo con kernel radial y probabilidades calibradas.",
        "factory": lambda: SVC(
            kernel="rbf",
            probability=True,
            random_state=RANDOM_STATE,
            class_weight="balanced",
        ),
        "explainer": "permutation",
    },
}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()[:12]


def _json_value(value):
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    return str(value)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    dataframe = pd.read_csv(DATASET)
    features = [column for column in dataframe.columns if column != TARGET]
    X = dataframe[features]
    y = dataframe[TARGET]
    X_train, X_test, y_train, y_test = train_test_split(
        X,
        y,
        test_size=TEST_SIZE,
        random_state=RANDOM_STATE,
        stratify=y,
    )

    background_path = OUTPUT_DIR / "shap_background_top25.pkl"
    joblib.dump(X_train.sample(n=50, random_state=RANDOM_STATE), background_path)
    continuous_features = list(joblib.load(SCALER_PATH).feature_names_in_)

    exported_at = datetime.now(timezone.utc).isoformat()
    entries = []
    for model_id, spec in MODEL_SPECS.items():
        if model_id == "random_forest":
            model = joblib.load(ACTIVE_RANDOM_FOREST)
        else:
            model = spec["factory"]()
            model.fit(X_train, y_train)

        if hasattr(model, "n_jobs"):
            model.n_jobs = 1

        artifact_path = OUTPUT_DIR / f"{model_id}.pkl"
        joblib.dump(model, artifact_path)
        predictions = model.predict(X_test)
        probabilities = model.predict_proba(X_test)[:, list(model.classes_).index(1)]
        tn, fp, fn, tp = confusion_matrix(y_test, predictions, labels=[0, 1]).ravel()
        params = {
            key: _json_value(value)
            for key, value in model.get_params(deep=False).items()
        }

        entries.append({
            "id": model_id,
            "display_name": spec["display_name"],
            "description": spec["description"],
            "recommended": spec.get("recommended", False),
            "artifact": f"registry/{artifact_path.name}",
            "artifact_id": _sha256(artifact_path),
            "technical_name": type(model).__name__,
            "explainer": spec["explainer"],
            "threshold": 0.5,
            "trained_at": exported_at,
            "params": params,
            "metrics": {
                "accuracy": accuracy_score(y_test, predictions),
                "precision": precision_score(y_test, predictions),
                "recall": recall_score(y_test, predictions),
                "f1": f1_score(y_test, predictions),
                "roc_auc": roc_auc_score(y_test, probabilities),
            },
            "confusion_matrix": {
                "tn": int(tn),
                "fp": int(fp),
                "fn": int(fn),
                "tp": int(tp),
            },
        })
        print(f"Exportado {spec['display_name']}: {artifact_path.name}")

    manifest = {
        "schema_version": 1,
        "default_model_id": "random_forest",
        "exported_at": exported_at,
        "framework": "scikit-learn",
        "framework_version": sklearn.__version__,
        "dataset": {
            "name": DATASET.name,
            "total_rows": len(dataframe),
            "train_rows": len(X_train),
            "test_rows": len(X_test),
            "train_ratio": 1 - TEST_SIZE,
            "test_ratio": TEST_SIZE,
            "legitimate_rows": int((y == 0).sum()),
            "phishing_rows": int((y == 1).sum()),
            "test_legitimate_rows": int((y_test == 0).sum()),
            "test_phishing_rows": int((y_test == 1).sum()),
        },
        "features": features,
        "continuous_features": continuous_features,
        "continuous_feature_count": len(continuous_features),
        "background": "registry/shap_background_top25.pkl",
        "models": entries,
    }
    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    shutil.copy2(MANIFEST_PATH, ROOT / "phishing-url-ai" / "models" / "ml" / MANIFEST_PATH.name)
    print(f"Registro creado: {MANIFEST_PATH}")


if __name__ == "__main__":
    main()
