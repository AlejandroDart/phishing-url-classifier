import os
import warnings

from flask import Blueprint, jsonify, request

from services.prediction_service import prediction_service
from services.model_info_service import ModelInfoService
from services.model_registry_service import UnknownModelError, model_registry

warnings.filterwarnings("ignore", category=UserWarning)

prediction_bp = Blueprint("prediction", __name__)

API_KEY = os.getenv("API_KEY")
def verificar_api_key():
    api_key = request.headers.get("X-API-KEY")
    return api_key == API_KEY


@prediction_bp.route("/predict", methods=["POST"])
def predict():
    try:
        if not verificar_api_key():
            return jsonify({"error": "Acceso no autorizado"}), 403

        data = request.get_json(silent=True)

        if not data:
            return jsonify({"error": "Body JSON invalido"}), 400

        url = data.get("url")
        store_global = data.get("store_global", False)
        model_id = data.get("model_id")
        sensitivity_profile = data.get("sensitivity_profile")

        if not url:
            return jsonify({"error": "No se proporciono ninguna URL"}), 400

        if not isinstance(store_global, bool):
            return jsonify({
                "error": "store_global debe ser un valor booleano"
            }), 400

        if model_id is not None and not isinstance(model_id, str):
            return jsonify({"error": "model_id debe ser texto"}), 400

        result = prediction_service.analyze(
            url,
            store_global=store_global,
            model_id=model_id,
            sensitivity_profile=sensitivity_profile,
        )
        return jsonify(result.to_dict())

    except (UnknownModelError, ValueError) as error:
        return jsonify({"error": str(error)}), 400
    except Exception as error:
        return jsonify({"error": str(error)}), 500


@prediction_bp.route("/explain-features", methods=["POST"])
def explain_features():
    try:
        if not verificar_api_key():
            return jsonify({"error": "Acceso no autorizado"}), 403

        data = request.get_json(silent=True)
        if not data or not isinstance(data.get("features"), dict):
            return jsonify({"error": "Debes enviar un objeto features"}), 400

        model_id = data.get("model_id")
        if model_id is not None and not isinstance(model_id, str):
            return jsonify({"error": "model_id debe ser texto"}), 400
        return jsonify(prediction_service.explain_stored_features(
            data["features"],
            model_id=model_id,
        ))
    except ValueError as error:
        return jsonify({"error": str(error)}), 400
    except Exception as error:
        return jsonify({"error": f"No fue posible calcular SHAP: {error}"}), 500


@prediction_bp.route("/model/info", methods=["GET"])
def model_info():
    if not verificar_api_key():
        return jsonify({"error": "Acceso no autorizado"}), 403

    try:
        runtime = model_registry.get_runtime(request.args.get("model_id"))
        return jsonify(ModelInfoService(
            runtime.model,
            runtime.feature_names,
            metadata=runtime.metadata,
            model_path=runtime.artifact_path,
        ).get_info())
    except UnknownModelError as error:
        return jsonify({"error": str(error)}), 404
    except (FileNotFoundError, ValueError) as error:
        return jsonify({"error": str(error)}), 503
    except Exception as error:
        return jsonify({
            "error": f"No fue posible obtener la información del modelo: {error}"
        }), 500


@prediction_bp.route("/models", methods=["GET"])
def models():
    if not verificar_api_key():
        return jsonify({"error": "Acceso no autorizado"}), 403
    return jsonify(model_registry.list_models())
