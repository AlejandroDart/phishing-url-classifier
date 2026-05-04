import os
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"  # Desactiva optimizaciones de oneDNN

from flask import Flask, request, jsonify
from tensorflow.keras.models import load_model  # type: ignore
import pandas as pd
from flask_cors import CORS
import joblib

# Cargar el modelo guardado
model = load_model("modelo_phishing.keras")

# Suponiendo que ya tienes el escalador guardado, cárgalo también
scaler = joblib.load("scaler.pkl")

# Nombres de las columnas utilizadas en el modelo
nombres_columnas = [
    'google_index', 'nb_qm', 'nb_www', 'ratio_digits_host', 'nb_hyperlinks',
    'nb_hyphens', 'domain_in_title', 'nb_dots', 'nb_eq', 'length_hostname',
    'domain_age', 'ratio_digits_url', 'domain_with_copyright', 'https_token',
    'whois_registered_domain', 'tld_in_subdomain', 'dns_record', 'prefix_suffix'
]

# Importar las funciones de extracción de características
from metodos_caracteristicas_mejorado3 import extract_features_url_analyze

# Definir clave API secreta
API_KEY = os.getenv("API_KEY", "aB7!xZ9$ePqT3@rWuLfC%12yJkNvQdX5")

# Crear la aplicación Flask
app = Flask(__name__)
CORS(app)

def verificar_api_key():
    """Verifica si la clave API es válida."""
    api_key = request.headers.get("X-API-KEY")
    if api_key != API_KEY:
        return False
    return True

@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Verificar la clave API
        if not verificar_api_key():
            return jsonify({"error": "Acceso no autorizado"}), 403
        
        # Obtener la URL enviada en la solicitud
        data = request.get_json()
        url = data.get('url', None)
        
        if not url:
            return jsonify({"error": "No se proporcionó ninguna URL"}), 400
        
        # Extraer características de la URL
        caracteristicas = extract_features_url_analyze(url)
        
        # Convertir a DataFrame y escalar las características
        caracteristicas_df = pd.DataFrame([caracteristicas], columns=nombres_columnas)
        caracteristicas_escaladas = scaler.transform(caracteristicas_df)
        
        # Hacer la predicción
        probabilidad = model.predict(caracteristicas_escaladas)[0][0]
        etiqueta = "phishing" if probabilidad >= 0.5 else "no-phishing"
        
        # Retornar la respuesta como JSON
        return jsonify({
            "url": url,
            "label": etiqueta,
            "probability": round(float(probabilidad), 6)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Ejecutar la aplicación Flask
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
