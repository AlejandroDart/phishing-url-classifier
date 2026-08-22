"""Valida carga, inferencia y explicación para todo el catálogo activo."""

import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from services.model_registry_service import model_registry
from services.prediction_service import prediction_service


URL = "https://secure-account-verify.example/login"
results = []
for option in model_registry.list_models()["models"]:
    started = time.perf_counter()
    result = prediction_service.analyze(
        URL,
        model_id=option["id"],
        use_network_features=False,
        store_global=False,
    )
    explanation = result.explanation.get("shap", {})
    row = {
        "model_id": option["id"],
        "family": option["family"],
        "probability": result.probability,
        "label": result.label,
        "explanation_available": explanation.get("available", False),
        "explanation_method": explanation.get("method"),
        "elapsed_ms": round((time.perf_counter() - started) * 1000, 2),
    }
    if not row["explanation_available"]:
        raise RuntimeError(f"Explicación no disponible para {option['id']}: {explanation}")
    results.append(row)
    print(json.dumps(row, ensure_ascii=False), flush=True)

assert len(results) == len(model_registry.list_models()["models"])
print("VALIDATED_MODELS=", len(results))
