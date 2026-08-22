import pytest

from services.model_registry_service import UnknownModelError, model_registry


def test_registry_exposes_all_exported_classifiers():
    catalog = model_registry.list_models()
    identifiers = {item["id"] for item in catalog["models"]}

    assert catalog["default_model_id"] == "hybrid_ensemble"
    assert identifiers == {
        "logistic_regression",
        "decision_tree",
        "random_forest",
        "gradient_boosting",
        "knn",
        "svm",
        "mlp_compact",
        "mlp_regularized",
        "mlp_residual",
        "cnn_1d",
        "bilstm",
        "gru",
        "heuristic",
        "hybrid_ensemble",
    }
    assert sum(item["recommended"] for item in catalog["models"]) == 1
    assert next(item for item in catalog["models"] if item["recommended"])["id"] == "hybrid_ensemble"


def test_registry_loads_models_lazily_and_rejects_unknown_identifier():
    runtime = model_registry.get_runtime("logistic_regression")

    assert runtime.model_id == "logistic_regression"
    assert len(runtime.feature_names) == 25
    assert runtime.metadata["metrics"]["accuracy"] > 0.9

    with pytest.raises(UnknownModelError):
        model_registry.get_runtime("modelo_inexistente")
