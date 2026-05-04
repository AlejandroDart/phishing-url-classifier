import os
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"

from flask import Flask
from flask_cors import CORS

from routes.prediction_routes import prediction_bp
from routes.stats_routes import stats_bp

app = Flask(__name__)

# Permitir CORS
CORS(app)

# Registrar blueprints
app.register_blueprint(prediction_bp)
app.register_blueprint(stats_bp)

# Ruta principal
@app.route("/")
def home():
    return {"message": "Phishing Detection API running"}

# Evitar error 404 del favicon
@app.route("/favicon.ico")
def favicon():
    return "", 204

# Ejecutar servidor
if __name__ == "__main__":
    app.run(
        host="0.0.0.0",
        port=5000,
        debug=True
    )