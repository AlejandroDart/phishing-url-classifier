import os
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

import warnings
import joblib
import pandas as pd
import tensorflow as tf
from flask import Blueprint, request, jsonify

from services.feature_extractor import extract_features_url_analyze
from database.prediction_repository import save_prediction

warnings.filterwarnings("ignore", category=UserWarning, module="keras")

prediction_bp = Blueprint("prediction", __name__)

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

MODEL_PATH = os.path.join(BASE_DIR, "models", "bm_phishing.keras")
SCALER_PATH = os.path.join(BASE_DIR, "models", "bm_scaler.pkl")

model = tf.keras.models.load_model(MODEL_PATH)
scaler = joblib.load(SCALER_PATH)

FEATURE_COLUMNS = [
    "google_index", "nb_qm", "nb_www", "ratio_digits_host", "nb_hyperlinks",
    "nb_hyphens", "domain_in_title", "nb_dots", "nb_eq", "length_hostname",
    "domain_age", "ratio_digits_url", "domain_with_copyright", "https_token",
    "whois_registered_domain", "tld_in_subdomain", "dns_record", "prefix_suffix"
]

API_KEY = os.getenv("API_KEY", "aB7!xZ9$ePqT3@rWuLfC%12yJkNvQdX5")


def verificar_api_key():
    api_key = request.headers.get("X-API-KEY")
    return api_key == API_KEY


@prediction_bp.route("/predict", methods=["POST"])
def predict():
    try:
        if not verificar_api_key():
            return jsonify({"error": "Acceso no autorizado"}), 403

        data = request.get_json()

        if not data:
            return jsonify({"error": "Body JSON inválido"}), 400

        url = data.get("url")

        if not url:
            return jsonify({"error": "No se proporcionó ninguna URL"}), 400

        features = extract_features_url_analyze(url)
        df = pd.DataFrame([features], columns=FEATURE_COLUMNS)
        features_scaled = scaler.transform(df)

        probability = float(model.predict(features_scaled, verbose=0)[0][0])
        label = "phishing" if probability >= 0.5 else "no-phishing"

        save_prediction(url, label, probability)

        return jsonify({
            "url": url,
            "label": label,
            "probability": round(probability, 6)
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500