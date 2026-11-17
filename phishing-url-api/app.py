import sys
sys.dont_write_bytecode = True

import os
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

import logging
import re
logging.getLogger("tensorflow").setLevel(logging.ERROR)
logging.getLogger("absl").setLevel(logging.ERROR)

from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

from routes.access import require_api_key
from routes.chatbot_routes import chatbot_bp
from routes.prediction_routes import prediction_bp
from routes.stats_routes import stats_bp


app = Flask(__name__)

app.config["API_KEY"] = os.getenv("API_KEY", "").strip()
app.config["PREDICTION_NETWORK_FEATURES"] = (
    os.getenv("PREDICTION_NETWORK_FEATURES", "true").lower() == "true"
)

origins = os.getenv("CORS_ALLOWED_ORIGINS")
allowed_origins = (
    [re.compile(r"^https?://(?:localhost|127\.0\.0\.1)(?::\d+)?$")]
    if origins is None
    else [re.compile(r"^" + re.escape(origin.strip()) + r"$")
          for origin in origins.split(",") if origin.strip()]
)
CORS(app, origins=allowed_origins, allow_headers=["Content-Type", "X-API-KEY"])

for blueprint in (prediction_bp, stats_bp, chatbot_bp):
    blueprint.before_request(require_api_key)
    app.register_blueprint(blueprint)


@app.route("/")
def home():
    return {"message": "Phishing Detection API running"}


@app.route("/favicon.ico")
def favicon():
    return "", 204


if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=False,
        use_reloader=False
    )
