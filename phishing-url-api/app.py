import sys
sys.dont_write_bytecode = True

import os
os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "3"
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

import logging
logging.getLogger("tensorflow").setLevel(logging.ERROR)
logging.getLogger("absl").setLevel(logging.ERROR)

from flask import Flask
from flask_cors import CORS
from dotenv import load_dotenv

load_dotenv()

from routes.chatbot_routes import chatbot_bp
from routes.prediction_routes import prediction_bp
from routes.stats_routes import stats_bp


app = Flask(__name__)

CORS(app)

app.register_blueprint(prediction_bp)
app.register_blueprint(stats_bp)
app.register_blueprint(chatbot_bp)


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
