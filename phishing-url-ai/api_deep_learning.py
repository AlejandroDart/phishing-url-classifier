import os
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"  # Desactiva optimizaciones de oneDNN

from flask import Flask, request, jsonify
from tensorflow.keras.models import load_model # type: ignore
import pandas as pd
from flask_cors import CORS
import joblib

# Cargar el modelo guardado
model = load_model("modelo_phishing.keras")

# Suponiendo que ya tienes el escalador guardado, cárgalo también
# Cargar el escalador ajustado
scaler = joblib.load("scaler.pkl")

# Nombres de las columnas utilizadas en el modelo
nombres_columnas = [
    'google_index', 'nb_qm', 'nb_www', 'ratio_digits_host', 'nb_hyperlinks',
    'nb_hyphens', 'domain_in_title', 'nb_dots', 'nb_eq', 'length_hostname',
    'domain_age', 'ratio_digits_url', 'domain_with_copyright', 'https_token',
    'whois_registered_domain', 'tld_in_subdomain', 'dns_record', 'prefix_suffix'
]

# Importar las funciones de extracción de características
from metodos_caracteristicas_mejorado2 import extract_features_url_analyze

# Crear la aplicación Flask
app = Flask(__name__)
CORS(app)

@app.route('/predict', methods=['POST'])
def predict():
    try:
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
            "probability": float(probabilidad)
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Ejecutar la aplicación Flask
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
