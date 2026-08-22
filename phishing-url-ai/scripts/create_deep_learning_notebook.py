"""Genera el notebook reproducible de modelos deep learning Top 25."""

from pathlib import Path

import nbformat as nbf


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "09_modelos_deep_learning_top25.ipynb"


def code(source: str):
    return nbf.v4.new_code_cell(source.strip())


def markdown(source: str):
    return nbf.v4.new_markdown_cell(source.strip())


notebook = nbf.v4.new_notebook()
notebook["metadata"] = {
    "kernelspec": {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    },
    "language_info": {"name": "python", "version": "3.12"},
}
notebook["cells"] = [
    markdown(
        """
# 09. Modelos de Deep Learning para detección de phishing

Este notebook entrena, compara y exporta modelos neuronales para clasificación binaria de URLs utilizando las mismas **25 características Top Global** del sistema LinkShield AI.

Objetivos:

1. Mantener una separación reproducible entre entrenamiento, validación y prueba.
2. Comparar tres arquitecturas de redes densas para datos tabulares.
3. Evaluar accuracy, precision, recall, F1-score, ROC-AUC y matriz de confusión.
4. Exportar todos los modelos y registrar el mejor candidato.
5. Comparar el mejor modelo neuronal con el Random Forest actualmente recomendado.

> El conjunto de prueba se utiliza solamente para la evaluación final. La selección durante el entrenamiento se realiza con validación.
"""
    ),
    code(
        """
import os
os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
os.environ["TF_ENABLE_ONEDNN_OPTS"] = "0"

import hashlib
import json
import random
import shutil
from datetime import datetime, timezone
from pathlib import Path

import joblib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import sklearn
import tensorflow as tf
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split
from tensorflow import keras
from tensorflow.keras import layers, regularizers

DATASET_PATH = Path("dataset-phishing-final-top25.csv")
OUTPUT_DIR = Path("models/deep_learning")
TARGET_COLUMN = "status"
RANDOM_STATE = 42
TEST_SIZE = 0.20
VALIDATION_SIZE_FROM_TRAIN = 0.20
BATCH_SIZE = 64
MAX_EPOCHS = 80
THRESHOLD = 0.50

RANDOM_FOREST_REFERENCE = {
    "id": "random_forest",
    "display_name": "Random Forest Top 25",
    "accuracy": 0.9488188976377953,
    "precision": 0.9430051813471503,
    "recall": 0.9553805774278216,
    "f1": 0.9491525423728814,
    "roc_auc": 0.986329738091575,
}

sns.set_theme(style="whitegrid")
pd.set_option("display.max_columns", None)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
print("TensorFlow:", tf.__version__)
print("Keras:", keras.__version__)
print("scikit-learn:", sklearn.__version__)
"""
    ),
    markdown(
        """
## 1. Reproducibilidad y hardware

Se fijan las semillas de Python, NumPy y TensorFlow. En Windows nativo, TensorFlow moderno utiliza CPU; esto no afecta la validez de las métricas, solamente el tiempo de entrenamiento.
"""
    ),
    code(
        """
random.seed(RANDOM_STATE)
np.random.seed(RANDOM_STATE)
tf.keras.utils.set_random_seed(RANDOM_STATE)
try:
    tf.config.experimental.enable_op_determinism()
except Exception:
    pass

physical_gpus = tf.config.list_physical_devices("GPU")
print("GPU disponibles:", physical_gpus if physical_gpus else "Ninguna; entrenamiento en CPU")
"""
    ),
    markdown(
        """
## 2. Carga y validación del dataset

El archivo contiene 25 variables predictoras ya preparadas por el pipeline anterior y una columna objetivo `status`, donde `0` representa una URL legítima y `1` phishing.
"""
    ),
    code(
        """
dataframe = pd.read_csv(DATASET_PATH)
assert TARGET_COLUMN in dataframe.columns, "No se encontró la variable objetivo"
assert not dataframe.isna().any().any(), "El dataset contiene valores faltantes"

feature_names = [column for column in dataframe.columns if column != TARGET_COLUMN]
assert len(feature_names) == 25, f"Se esperaban 25 variables y se encontraron {len(feature_names)}"

X = dataframe[feature_names].astype("float32")
y = dataframe[TARGET_COLUMN].astype("int32")
assert set(y.unique()) == {0, 1}, "La variable objetivo debe ser binaria"

display(dataframe.head())
print("Dimensiones:", dataframe.shape)
print("Variables:", len(feature_names))
display(y.value_counts().rename(index={0: "Legítima", 1: "Phishing"}).to_frame("muestras"))
"""
    ),
    markdown(
        """
## 3. División entrenamiento, validación y prueba

- **64 % entrenamiento:** actualización de pesos.
- **16 % validación:** early stopping y reducción de learning rate.
- **20 % prueba:** comparación final no utilizada durante el ajuste.

Todas las divisiones son estratificadas para conservar el equilibrio de clases.
"""
    ),
    code(
        """
X_train_full, X_test, y_train_full, y_test = train_test_split(
    X,
    y,
    test_size=TEST_SIZE,
    random_state=RANDOM_STATE,
    stratify=y,
)
X_train, X_val, y_train, y_val = train_test_split(
    X_train_full,
    y_train_full,
    test_size=VALIDATION_SIZE_FROM_TRAIN,
    random_state=RANDOM_STATE,
    stratify=y_train_full,
)

split_summary = pd.DataFrame({
    "partición": ["Entrenamiento", "Validación", "Prueba"],
    "muestras": [len(X_train), len(X_val), len(X_test)],
    "legítimas": [(y_train == 0).sum(), (y_val == 0).sum(), (y_test == 0).sum()],
    "phishing": [(y_train == 1).sum(), (y_val == 1).sum(), (y_test == 1).sum()],
})
display(split_summary)
"""
    ),
    markdown(
        """
## 4. Arquitecturas candidatas

Se comparan tres redes diseñadas para datos tabulares:

1. **MLP compacta:** referencia neuronal de baja complejidad.
2. **MLP regularizada:** mayor capacidad, normalización por lotes, dropout y regularización L2.
3. **Red residual densa:** bloque residual para facilitar la propagación de gradientes.

Todas producen una probabilidad de phishing mediante una salida sigmoide.
"""
    ),
    code(
        """
def compile_binary_model(model):
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=1e-3),
        loss="binary_crossentropy",
        metrics=[
            keras.metrics.BinaryAccuracy(name="accuracy"),
            keras.metrics.Precision(name="precision"),
            keras.metrics.Recall(name="recall"),
            keras.metrics.AUC(name="roc_auc"),
        ],
    )
    return model


def build_compact_mlp(input_dim):
    inputs = keras.Input(shape=(input_dim,), name="top25_features")
    x = layers.Dense(64, activation="relu")(inputs)
    x = layers.Dropout(0.20)(x)
    x = layers.Dense(32, activation="relu")(x)
    x = layers.Dropout(0.10)(x)
    outputs = layers.Dense(1, activation="sigmoid", name="phishing_probability")(x)
    return compile_binary_model(keras.Model(inputs, outputs, name="mlp_compact"))


def build_regularized_mlp(input_dim):
    inputs = keras.Input(shape=(input_dim,), name="top25_features")
    x = layers.Dense(128, kernel_regularizer=regularizers.l2(1e-4))(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.Activation("relu")(x)
    x = layers.Dropout(0.30)(x)
    x = layers.Dense(64, kernel_regularizer=regularizers.l2(1e-4))(x)
    x = layers.BatchNormalization()(x)
    x = layers.Activation("relu")(x)
    x = layers.Dropout(0.25)(x)
    x = layers.Dense(32, activation="relu")(x)
    outputs = layers.Dense(1, activation="sigmoid", name="phishing_probability")(x)
    return compile_binary_model(keras.Model(inputs, outputs, name="mlp_regularized"))


def build_residual_mlp(input_dim):
    inputs = keras.Input(shape=(input_dim,), name="top25_features")
    x = layers.Dense(64)(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.Activation("relu")(x)
    shortcut = x
    x = layers.Dropout(0.20)(x)
    x = layers.Dense(64)(x)
    x = layers.BatchNormalization()(x)
    x = layers.Add()([shortcut, x])
    x = layers.Activation("relu")(x)
    x = layers.Dropout(0.20)(x)
    x = layers.Dense(32, activation="relu")(x)
    outputs = layers.Dense(1, activation="sigmoid", name="phishing_probability")(x)
    return compile_binary_model(keras.Model(inputs, outputs, name="mlp_residual"))


model_builders = {
    "mlp_compact": {
        "display_name": "MLP Compacta",
        "description": "Red densa ligera con dos capas ocultas.",
        "builder": build_compact_mlp,
    },
    "mlp_regularized": {
        "display_name": "MLP Regularizada",
        "description": "Red profunda con Batch Normalization, Dropout y regularización L2.",
        "builder": build_regularized_mlp,
    },
    "mlp_residual": {
        "display_name": "MLP Residual",
        "description": "Red densa con conexión residual y normalización por lotes.",
        "builder": build_residual_mlp,
    },
}

for model_id, config in model_builders.items():
    preview = config["builder"](len(feature_names))
    print(model_id, "parámetros:", preview.count_params())
    del preview
keras.backend.clear_session()
"""
    ),
    markdown(
        """
## 5. Entrenamiento

Cada candidato utiliza:

- `EarlyStopping` sobre `val_loss` para recuperar los mejores pesos.
- `ReduceLROnPlateau` para disminuir el learning rate cuando la validación se estanca.
- Hasta 80 épocas, aunque el entrenamiento puede finalizar antes.
"""
    ),
    code(
        """
models = {}
histories = {}
training_rows = []

for index, (model_id, config) in enumerate(model_builders.items()):
    tf.keras.utils.set_random_seed(RANDOM_STATE + index)
    model = config["builder"](len(feature_names))
    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor="val_loss",
            patience=10,
            min_delta=1e-4,
            restore_best_weights=True,
            verbose=1,
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor="val_loss",
            factor=0.5,
            patience=4,
            min_lr=1e-5,
            verbose=1,
        ),
    ]
    print("\\n" + "=" * 72)
    print("ENTRENANDO:", config["display_name"])
    print("=" * 72)
    history = model.fit(
        X_train,
        y_train,
        validation_data=(X_val, y_val),
        epochs=MAX_EPOCHS,
        batch_size=BATCH_SIZE,
        callbacks=callbacks,
        verbose=2,
        shuffle=True,
    )
    models[model_id] = model
    histories[model_id] = history.history
    training_rows.append({
        "model_id": model_id,
        "epochs_completed": len(history.history["loss"]),
        "best_epoch": int(np.argmin(history.history["val_loss"]) + 1),
        "best_val_loss": float(np.min(history.history["val_loss"])),
    })

display(pd.DataFrame(training_rows))
"""
    ),
    markdown("## 6. Curvas de aprendizaje"),
    code(
        """
fig, axes = plt.subplots(len(histories), 2, figsize=(13, 4 * len(histories)))
for row, (model_id, history) in enumerate(histories.items()):
    display_name = model_builders[model_id]["display_name"]
    axes[row, 0].plot(history["loss"], label="Entrenamiento")
    axes[row, 0].plot(history["val_loss"], label="Validación")
    axes[row, 0].set_title(f"Loss - {display_name}")
    axes[row, 0].set_xlabel("Época")
    axes[row, 0].legend()
    axes[row, 1].plot(history["accuracy"], label="Entrenamiento")
    axes[row, 1].plot(history["val_accuracy"], label="Validación")
    axes[row, 1].set_title(f"Accuracy - {display_name}")
    axes[row, 1].set_xlabel("Época")
    axes[row, 1].legend()
plt.tight_layout()
plt.show()
"""
    ),
    markdown(
        """
## 7. Evaluación final

La selección del mejor modelo neuronal se realiza por **F1-score**, porque equilibra precision y recall en la detección de phishing.
"""
    ),
    code(
        """
evaluation_rows = []
confusion_matrices = {}

for model_id, model in models.items():
    probabilities = model.predict(X_test, batch_size=256, verbose=0).reshape(-1)
    predictions = (probabilities >= THRESHOLD).astype("int32")
    tn, fp, fn, tp = confusion_matrix(y_test, predictions, labels=[0, 1]).ravel()
    confusion_matrices[model_id] = np.array([[tn, fp], [fn, tp]])
    row = {
        "model_id": model_id,
        "modelo": model_builders[model_id]["display_name"],
        "accuracy": accuracy_score(y_test, predictions),
        "precision": precision_score(y_test, predictions),
        "recall": recall_score(y_test, predictions),
        "f1": f1_score(y_test, predictions),
        "roc_auc": roc_auc_score(y_test, probabilities),
        "tn": int(tn),
        "fp": int(fp),
        "fn": int(fn),
        "tp": int(tp),
    }
    evaluation_rows.append(row)
    print("\\n", model_builders[model_id]["display_name"])
    print(classification_report(y_test, predictions, target_names=["Legítima", "Phishing"]))

results_df = pd.DataFrame(evaluation_rows).sort_values("f1", ascending=False).reset_index(drop=True)
metric_columns = ["accuracy", "precision", "recall", "f1", "roc_auc"]
display(results_df.assign(**{column: results_df[column].round(4) for column in metric_columns}))
"""
    ),
    markdown("## 8. Matrices de confusión"),
    code(
        """
fig, axes = plt.subplots(1, len(confusion_matrices), figsize=(16, 4.5))
for axis, (model_id, matrix) in zip(axes, confusion_matrices.items()):
    sns.heatmap(
        matrix,
        annot=True,
        fmt="d",
        cmap="Blues",
        cbar=False,
        xticklabels=["Legítima", "Phishing"],
        yticklabels=["Legítima", "Phishing"],
        ax=axis,
    )
    axis.set_title(model_builders[model_id]["display_name"])
    axis.set_xlabel("Predicción")
    axis.set_ylabel("Valor real")
plt.tight_layout()
plt.show()
"""
    ),
    markdown(
        """
## 9. Comparación con el modelo recomendado actual

El mejor candidato neuronal se compara con el Random Forest Top 25. El modelo recomendado para la aplicación solamente cambia si supera objetivamente su F1-score.
"""
    ),
    code(
        """
best_row = results_df.iloc[0]
best_model_id = best_row["model_id"]
best_dl_f1 = float(best_row["f1"])
rf_f1 = RANDOM_FOREST_REFERENCE["f1"]
recommended_for_application = (
    best_model_id if best_dl_f1 > rf_f1 else RANDOM_FOREST_REFERENCE["id"]
)

comparison = pd.DataFrame([
    {
        "modelo": best_row["modelo"],
        "tipo": "Deep Learning",
        "accuracy": best_row["accuracy"],
        "precision": best_row["precision"],
        "recall": best_row["recall"],
        "f1": best_row["f1"],
        "roc_auc": best_row["roc_auc"],
    },
    {
        "modelo": RANDOM_FOREST_REFERENCE["display_name"],
        "tipo": "Machine Learning",
        **{key: RANDOM_FOREST_REFERENCE[key] for key in ("accuracy", "precision", "recall", "f1", "roc_auc")},
    },
]).sort_values("f1", ascending=False)
display(comparison.assign(**{
    column: comparison[column].round(4)
    for column in ("accuracy", "precision", "recall", "f1", "roc_auc")
}))
print("Mejor modelo Deep Learning:", model_builders[best_model_id]["display_name"])
print("Modelo recomendado para la aplicación:", recommended_for_application)
"""
    ),
    markdown(
        """
## 10. Exportación de modelos y metadatos

Se exportan:

- Los tres modelos `.keras`.
- Una copia del ganador como `mejor_modelo_deep_learning.keras`.
- Métricas CSV y registro JSON.
- Orden de características y scaler compartido.
- Muestra de referencia para explicabilidad SHAP futura.
"""
    ),
    code(
        """
def artifact_hash(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()[:12]


exported_at = datetime.now(timezone.utc).isoformat()
artifacts = []
for _, result in results_df.iterrows():
    model_id = result["model_id"]
    artifact_path = OUTPUT_DIR / f"{model_id}.keras"
    models[model_id].save(artifact_path)
    artifacts.append({
        "id": model_id,
        "display_name": model_builders[model_id]["display_name"],
        "description": model_builders[model_id]["description"],
        "technical_name": models[model_id].name,
        "artifact": artifact_path.name,
        "artifact_id": artifact_hash(artifact_path),
        "recommended_deep_learning": model_id == best_model_id,
        "recommended_for_application": model_id == recommended_for_application,
        "threshold": THRESHOLD,
        "parameter_count": int(models[model_id].count_params()),
        "metrics": {key: float(result[key]) for key in ("accuracy", "precision", "recall", "f1", "roc_auc")},
        "confusion_matrix": {key: int(result[key]) for key in ("tn", "fp", "fn", "tp")},
        "training": next(row for row in training_rows if row["model_id"] == model_id),
    })

best_artifact = OUTPUT_DIR / f"{best_model_id}.keras"
shutil.copy2(best_artifact, OUTPUT_DIR / "mejor_modelo_deep_learning.keras")
joblib.dump(feature_names, OUTPUT_DIR / "features_deep_learning_top25.pkl")
joblib.dump(X_train.sample(n=50, random_state=RANDOM_STATE), OUTPUT_DIR / "shap_background_top25.pkl")
source_scaler = Path("scaler_top.pkl")
if source_scaler.exists():
    shutil.copy2(source_scaler, OUTPUT_DIR / "scaler_top.pkl")

results_df.to_csv(OUTPUT_DIR / "metricas_deep_learning_top25.csv", index=False)
for model_id, history in histories.items():
    (OUTPUT_DIR / f"history_{model_id}.json").write_text(
        json.dumps({key: [float(value) for value in values] for key, values in history.items()}, indent=2),
        encoding="utf-8",
    )

registry = {
    "schema_version": 1,
    "exported_at": exported_at,
    "framework": "TensorFlow/Keras",
    "tensorflow_version": tf.__version__,
    "keras_version": keras.__version__,
    "dataset": {
        "name": DATASET_PATH.name,
        "total_rows": len(dataframe),
        "train_rows": len(X_train),
        "validation_rows": len(X_val),
        "test_rows": len(X_test),
        "test_legitimate_rows": int((y_test == 0).sum()),
        "test_phishing_rows": int((y_test == 1).sum()),
    },
    "features": feature_names,
    "best_deep_learning_model_id": best_model_id,
    "application_recommended_model_id": recommended_for_application,
    "random_forest_reference": RANDOM_FOREST_REFERENCE,
    "models": artifacts,
}
(OUTPUT_DIR / "deep_learning_registry.json").write_text(
    json.dumps(registry, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
(OUTPUT_DIR / "metadata_mejor_modelo_deep_learning.json").write_text(
    json.dumps(next(item for item in artifacts if item["id"] == best_model_id), ensure_ascii=False, indent=2),
    encoding="utf-8",
)
print("Artefactos exportados en:", OUTPUT_DIR.resolve())
print("Ganador Deep Learning:", best_model_id)
print("Recomendado para aplicación:", recommended_for_application)
"""
    ),
    markdown("## 11. Verificación de artefactos exportados"),
    code(
        """
loaded_model = keras.models.load_model(OUTPUT_DIR / "mejor_modelo_deep_learning.keras")
loaded_features = joblib.load(OUTPUT_DIR / "features_deep_learning_top25.pkl")
assert loaded_features == feature_names
sample_probability = float(loaded_model.predict(X_test.iloc[[0]], verbose=0)[0, 0])
original_probability = float(models[best_model_id].predict(X_test.iloc[[0]], verbose=0)[0, 0])
assert abs(sample_probability - original_probability) < 1e-6
print("Modelo recargado correctamente")
print("Entrada:", loaded_model.input_shape, "Salida:", loaded_model.output_shape)
print("Probabilidad de prueba:", round(sample_probability, 6))
"""
    ),
    markdown(
        """
## Conclusión

El registro exportado permite integrar posteriormente estos modelos en la API y en el selector de la aplicación. La decisión recomendada queda fundamentada en el F1-score del mismo conjunto de prueba usado para comparar los modelos clásicos.

Para producción deben conservarse juntos el modelo, el orden de características, el scaler y los metadatos. La probabilidad neuronal deberá acompañarse de explicabilidad compatible antes de habilitar el modelo en Anita y en los historiales.
"""
    ),
]

nbf.write(notebook, OUTPUT)
print(OUTPUT)
