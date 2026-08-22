"""Genera el notebook de Deep Learning secuencial para URLs."""

from pathlib import Path

import nbformat as nbf


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "10_modelos_deep_learning_secuencial.ipynb"


def code(source: str):
    return nbf.v4.new_code_cell(source.strip())


def markdown(source: str):
    return nbf.v4.new_markdown_cell(source.strip())


nb = nbf.v4.new_notebook()
nb["metadata"] = {
    "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
    "language_info": {"name": "python", "version": "3.12"},
}
nb["cells"] = [
    markdown(
        """
# 10. Deep Learning secuencial para clasificación de URLs

Este notebook continúa el pipeline de LinkShield AI utilizando la URL original de
`dataset-phishing-clean.csv`. Entrena y compara tres arquitecturas independientes:

- **CNN 1D**, especializada en patrones locales de caracteres.
- **BiLSTM**, orientada a relaciones bidireccionales dentro de la secuencia.
- **GRU**, alternativa recurrente compacta.

La partición separa entrenamiento, validación, calibración y prueba. El conjunto de
calibración queda reservado para el modelo híbrido del notebook 11 y el conjunto de
prueba permanece intacto para la evaluación final.
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
from urllib.parse import quote

import matplotlib.pyplot as plt
import nbformat
import numpy as np
import pandas as pd
import seaborn as sns
import sklearn
import tensorflow as tf
from IPython.display import Image, display
from sklearn.metrics import (
    accuracy_score, classification_report, confusion_matrix, f1_score,
    precision_score, recall_score, roc_auc_score,
)
from sklearn.model_selection import train_test_split
from tensorflow import keras
from tensorflow.keras import layers

DATASET_PATH = Path("dataset-phishing-clean.csv")
OUTPUT_DIR = Path("models/sequential")
PLOT_DIR = OUTPUT_DIR / "plots"
RANDOM_STATE = 42
MAX_LENGTH = 200
EMBEDDING_DIM = 24
BATCH_SIZE = 128
MAX_EPOCHS = 16

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
PLOT_DIR.mkdir(parents=True, exist_ok=True)
sns.set_theme(style="whitegrid")
print("TensorFlow:", tf.__version__)
print("Keras:", keras.__version__)
"""
    ),
    markdown("## 1. Reproducibilidad"),
    code(
        """
random.seed(RANDOM_STATE)
np.random.seed(RANDOM_STATE)
tf.keras.utils.set_random_seed(RANDOM_STATE)
try:
    tf.config.experimental.enable_op_determinism()
except Exception:
    pass
"""
    ),
    markdown("## 2. Dataset y secuencias"),
    code(
        """
dataframe = pd.read_csv(DATASET_PATH)
assert {"url", "status"}.issubset(dataframe.columns)
dataframe = dataframe.dropna(subset=["url", "status"]).reset_index(drop=True)
def normalize_url_sequence(value):
    return quote(str(value).strip(), safe=":/?#[]@!$&'()*+,;=%-._~")

dataframe["url"] = dataframe["url"].map(normalize_url_sequence)
dataframe["status"] = dataframe["status"].astype("int32")
assert set(dataframe["status"].unique()) == {0, 1}
assert dataframe["url"].map(lambda value: all(ord(char) < 128 for char in value)).all()

lengths = dataframe["url"].str.len()
display(dataframe[["url", "status"]].head())
display(lengths.describe(percentiles=[0.90, 0.95, 0.975, 0.99]).to_frame("longitud"))
print("Muestras:", len(dataframe), "Balance:", dataframe["status"].value_counts().to_dict())
"""
    ),
    markdown("## 3. Partición común sin fuga de datos"),
    code(
        """
all_indices = np.arange(len(dataframe))
y_all = dataframe["status"].to_numpy()
development_indices, test_indices = train_test_split(
    all_indices, test_size=0.20, random_state=RANDOM_STATE, stratify=y_all,
)
train_validation_indices, calibration_indices = train_test_split(
    development_indices,
    test_size=0.125,
    random_state=RANDOM_STATE,
    stratify=y_all[development_indices],
)
train_indices, validation_indices = train_test_split(
    train_validation_indices,
    test_size=1 / 7,
    random_state=RANDOM_STATE,
    stratify=y_all[train_validation_indices],
)

split_indices = {
    "train": np.sort(train_indices),
    "validation": np.sort(validation_indices),
    "calibration": np.sort(calibration_indices),
    "test": np.sort(test_indices),
}
np.savez(OUTPUT_DIR / "split_indices.npz", **split_indices)

def split_values(name):
    indices = split_indices[name]
    return dataframe.loc[indices, "url"].to_numpy(dtype=str), y_all[indices]

X_train, y_train = split_values("train")
X_validation, y_validation = split_values("validation")
X_calibration, y_calibration = split_values("calibration")
X_test, y_test = split_values("test")

split_table = pd.DataFrame([
    {"partición": name, "muestras": len(indices),
     "legítimas": int((y_all[indices] == 0).sum()),
     "phishing": int((y_all[indices] == 1).sum())}
    for name, indices in split_indices.items()
])
display(split_table)
assert sum(len(value) for value in split_indices.values()) == len(dataframe)
"""
    ),
    markdown("## 4. Vectorización por caracteres"),
    code(
        """
vectorizer = layers.TextVectorization(
    standardize=None,
    split="character",
    output_mode="int",
    output_sequence_length=MAX_LENGTH,
    name="character_vectorizer",
)
vectorizer.adapt(tf.data.Dataset.from_tensor_slices(X_train).batch(256))
vocabulary = vectorizer.get_vocabulary()
(OUTPUT_DIR / "character_vocabulary.json").write_text(
    json.dumps(vocabulary, ensure_ascii=False, indent=2), encoding="utf-8"
)
print("Vocabulario:", len(vocabulary), "Longitud máxima:", MAX_LENGTH)

def cloned_vectorizer():
    layer = layers.TextVectorization.from_config(vectorizer.get_config())
    layer.set_vocabulary(vocabulary)
    return layer

def dataset_for(urls, labels=None, shuffle=False):
    if labels is None:
        dataset = tf.data.Dataset.from_tensor_slices(urls)
    else:
        dataset = tf.data.Dataset.from_tensor_slices((urls, labels))
    if shuffle:
        dataset = dataset.shuffle(len(urls), seed=RANDOM_STATE, reshuffle_each_iteration=True)
    return dataset.batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)

train_dataset = dataset_for(X_train, y_train, shuffle=True)
validation_dataset = dataset_for(X_validation, y_validation)
test_dataset = dataset_for(X_test, y_test)
"""
    ),
    markdown("## 5. Arquitecturas"),
    code(
        """
def compile_model(model):
    model.compile(
        optimizer=keras.optimizers.Adam(1e-3),
        loss="binary_crossentropy",
        metrics=[
            keras.metrics.BinaryAccuracy(name="accuracy"),
            keras.metrics.Precision(name="precision"),
            keras.metrics.Recall(name="recall"),
            keras.metrics.AUC(name="roc_auc"),
        ],
    )
    return model

def base_input():
    inputs = keras.Input(shape=(), dtype=tf.string, name="url")
    tokens = cloned_vectorizer()(inputs)
    embedded = layers.Embedding(len(vocabulary), EMBEDDING_DIM, mask_zero=False)(tokens)
    return inputs, embedded

def build_cnn():
    inputs, x = base_input()
    x = layers.SeparableConv1D(64, 5, padding="same", activation="relu")(x)
    x = layers.MaxPooling1D(2)(x)
    x = layers.SeparableConv1D(96, 3, padding="same", activation="relu")(x)
    x = layers.GlobalMaxPooling1D()(x)
    x = layers.Dense(48, activation="relu")(x)
    x = layers.Dropout(0.25)(x)
    return compile_model(keras.Model(inputs, layers.Dense(1, activation="sigmoid")(x), name="cnn_1d_url"))

def build_bilstm():
    inputs, x = base_input()
    x = layers.Bidirectional(layers.LSTM(24))(x)
    x = layers.Dense(32, activation="relu")(x)
    x = layers.Dropout(0.25)(x)
    return compile_model(keras.Model(inputs, layers.Dense(1, activation="sigmoid")(x), name="bilstm_url"))

def build_gru():
    inputs, x = base_input()
    x = layers.GRU(40)(x)
    x = layers.Dense(32, activation="relu")(x)
    x = layers.Dropout(0.20)(x)
    return compile_model(keras.Model(inputs, layers.Dense(1, activation="sigmoid")(x), name="gru_url"))

builders = {
    "cnn_1d": ("CNN 1D por caracteres", build_cnn),
    "bilstm": ("BiLSTM por caracteres", build_bilstm),
    "gru": ("GRU por caracteres", build_gru),
}
for model_id, (display_name, builder) in builders.items():
    preview = builder()
    print(model_id, display_name, preview.count_params(), "parámetros")
    del preview
keras.backend.clear_session()
"""
    ),
    markdown("## 6. Entrenamiento"),
    code(
        """
models = {}
histories = {}
training_rows = []
for index, (model_id, (display_name, builder)) in enumerate(builders.items()):
    tf.keras.utils.set_random_seed(RANDOM_STATE + index)
    model = builder()
    callbacks = [
        keras.callbacks.EarlyStopping(monitor="val_loss", patience=3, min_delta=1e-4, restore_best_weights=True, verbose=1),
        keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=2, min_lr=1e-5, verbose=1),
    ]
    print("\\n" + "=" * 72, "\\nENTRENANDO:", display_name, "\\n" + "=" * 72)
    history = model.fit(
        train_dataset,
        validation_data=validation_dataset,
        epochs=MAX_EPOCHS,
        callbacks=callbacks,
        verbose=2,
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
    markdown("## 7. Curvas de aprendizaje"),
    code(
        """
fig, axes = plt.subplots(len(histories), 2, figsize=(13, 4 * len(histories)))
for row, (model_id, history) in enumerate(histories.items()):
    axes[row, 0].plot(history["loss"], label="Entrenamiento")
    axes[row, 0].plot(history["val_loss"], label="Validación")
    axes[row, 0].set_title(f"Loss - {builders[model_id][0]}")
    axes[row, 0].legend()
    axes[row, 1].plot(history["accuracy"], label="Entrenamiento")
    axes[row, 1].plot(history["val_accuracy"], label="Validación")
    axes[row, 1].set_title(f"Accuracy - {builders[model_id][0]}")
    axes[row, 1].legend()
plt.tight_layout()
curves_path = PLOT_DIR / "curvas_secuenciales.png"
plt.savefig(curves_path, dpi=140, bbox_inches="tight")
plt.close(fig)
display(Image(filename=str(curves_path)))
"""
    ),
    markdown("## 8. Umbrales y evaluación final"),
    code(
        """
def best_threshold(labels, probabilities):
    candidates = np.linspace(0.20, 0.80, 121)
    scores = [f1_score(labels, probabilities >= threshold) for threshold in candidates]
    return float(candidates[int(np.argmax(scores))])

evaluation_rows = []
confusion_matrices = {}
thresholds = {}
for model_id, model in models.items():
    validation_probabilities = model.predict(dataset_for(X_validation), verbose=0).reshape(-1)
    threshold = best_threshold(y_validation, validation_probabilities)
    thresholds[model_id] = threshold
    probabilities = model.predict(dataset_for(X_test), verbose=0).reshape(-1)
    predictions = (probabilities >= threshold).astype("int32")
    tn, fp, fn, tp = confusion_matrix(y_test, predictions, labels=[0, 1]).ravel()
    confusion_matrices[model_id] = np.array([[tn, fp], [fn, tp]])
    evaluation_rows.append({
        "model_id": model_id, "modelo": builders[model_id][0], "threshold": threshold,
        "accuracy": accuracy_score(y_test, predictions),
        "precision": precision_score(y_test, predictions),
        "recall": recall_score(y_test, predictions),
        "f1": f1_score(y_test, predictions),
        "roc_auc": roc_auc_score(y_test, probabilities),
        "tn": int(tn), "fp": int(fp), "fn": int(fn), "tp": int(tp),
    })
    print("\\n", builders[model_id][0])
    print(classification_report(y_test, predictions, target_names=["Legítima", "Phishing"]))

results_df = pd.DataFrame(evaluation_rows).sort_values("f1", ascending=False).reset_index(drop=True)
metric_columns = ["threshold", "accuracy", "precision", "recall", "f1", "roc_auc"]
display(results_df.assign(**{column: results_df[column].round(4) for column in metric_columns}))
"""
    ),
    markdown("## 9. Matrices de confusión"),
    code(
        """
fig, axes = plt.subplots(1, len(confusion_matrices), figsize=(16, 4.5))
for axis, (model_id, matrix) in zip(axes, confusion_matrices.items()):
    sns.heatmap(matrix, annot=True, fmt="d", cmap="Blues", cbar=False,
                xticklabels=["Legítima", "Phishing"], yticklabels=["Legítima", "Phishing"], ax=axis)
    axis.set_title(builders[model_id][0])
    axis.set_xlabel("Predicción")
    axis.set_ylabel("Valor real")
plt.tight_layout()
matrix_path = PLOT_DIR / "matrices_secuenciales.png"
plt.savefig(matrix_path, dpi=150, bbox_inches="tight")
plt.close(fig)
display(Image(filename=str(matrix_path)))
"""
    ),
    markdown("## 10. Exportación y verificación"),
    code(
        """
def artifact_id(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()[:12]

best_model_id = str(results_df.iloc[0]["model_id"])
exported_at = datetime.now(timezone.utc).isoformat()
artifacts = []
for row in results_df.to_dict("records"):
    model_id = row["model_id"]
    artifact_path = OUTPUT_DIR / f"{model_id}.keras"
    models[model_id].save(artifact_path)
    training = next(item for item in training_rows if item["model_id"] == model_id)
    artifact = {
        "id": model_id,
        "display_name": builders[model_id][0],
        "family": "deep_learning_sequential",
        "runtime_type": "keras_sequence",
        "artifact": artifact_path.name,
        "artifact_id": artifact_id(artifact_path),
        "recommended_in_family": model_id == best_model_id,
        "threshold": float(row["threshold"]),
        "parameter_count": int(models[model_id].count_params()),
        "metrics": {key: float(row[key]) for key in ("accuracy", "precision", "recall", "f1", "roc_auc")},
        "confusion_matrix": {key: int(row[key]) for key in ("tn", "fp", "fn", "tp")},
        "training": training,
    }
    artifacts.append(artifact)
    (OUTPUT_DIR / f"history_{model_id}.json").write_text(
        json.dumps({key: [float(value) for value in values] for key, values in histories[model_id].items()}, indent=2),
        encoding="utf-8",
    )

shutil.copy2(OUTPUT_DIR / f"{best_model_id}.keras", OUTPUT_DIR / "mejor_modelo_secuencial.keras")
results_df.to_csv(OUTPUT_DIR / "metricas_modelos_secuenciales.csv", index=False)
registry = {
    "schema_version": 1,
    "exported_at": exported_at,
    "framework": "TensorFlow/Keras",
    "tensorflow_version": tf.__version__,
    "dataset": {"name": DATASET_PATH.name, "total_rows": len(dataframe),
                **{f"{name}_rows": len(indices) for name, indices in split_indices.items()}},
    "sequence": {"encoding": "character", "max_length": MAX_LENGTH, "vocabulary_size": len(vocabulary)},
    "best_model_id": best_model_id,
    "models": artifacts,
}
(OUTPUT_DIR / "sequential_registry.json").write_text(json.dumps(registry, ensure_ascii=False, indent=2), encoding="utf-8")

for artifact in artifacts:
    loaded = keras.models.load_model(OUTPUT_DIR / artifact["artifact"])
    sample = loaded.predict(dataset_for(X_test[:2]), verbose=0).reshape(-1)
    assert sample.shape == (2,) and np.isfinite(sample).all()
    print(artifact["id"], "recargado:", np.round(sample, 5).tolist())
print("Mejor modelo secuencial:", best_model_id)
"""
    ),
    markdown(
        """
## Conclusión

Los tres modelos quedan disponibles como clasificadores independientes. El registro y
los índices exportados permiten que el notebook 11 entrene el ensamble híbrido sobre
calibración y lo evalúe posteriormente sobre un test que ningún metaclasificador ha visto.
"""
    ),
]

nbf.write(nb, OUTPUT)
print(OUTPUT)
