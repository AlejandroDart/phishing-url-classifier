<div align="center">
  <img src="phishing-url-app/assets/images/app_icon.png" alt="Logo de LinkShield AI" width="104">
  <h1>LinkShield AI</h1>
  <p><strong>Plataforma inteligente, explicable y multiplataforma para analizar URLs y detectar phishing.</strong></p>
  <p>
    <img src="https://img.shields.io/badge/Flutter-Android%20%7C%20iOS%20%7C%20Web-02569B?logo=flutter&logoColor=white" alt="Flutter">
    <img src="https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white" alt="Python">
    <img src="https://img.shields.io/badge/API-Flask-000000?logo=flask&logoColor=white" alt="Flask">
    <img src="https://img.shields.io/badge/Modelos-14-0EA5E9" alt="14 modelos">
    <img src="https://img.shields.io/badge/F1%20h%C3%ADbrido-95.00%25-159957" alt="F1 híbrido 95.00%">
  </p>
  <p>Desarrollado por <strong>Alejandro Mayró Lena</strong></p>
  <p><a href="https://github.com/users/AlejandroDart/projects/1"><strong>Planificación y seguimiento</strong></a> | <a href="https://github.com/users/AlejandroDart/projects/1/views/5"><strong>Cronograma Gantt</strong></a></p>
</div>

---

## Descripción

LinkShield AI es una solución académica de ciberseguridad que analiza una URL, estima su probabilidad de phishing y explica las señales que influyeron en el resultado. La plataforma combina modelos de machine learning, deep learning tabular, redes secuenciales de caracteres y reglas heurísticas en un ensamble híbrido calibrado.

El sistema está organizado como una arquitectura cliente-servidor: una aplicación Flutter consume una API REST desarrollada con Flask, mientras que los artefactos de inteligencia artificial se mantienen en un módulo independiente y reproducible mediante notebooks.

## Capacidades principales

- Análisis manual de URLs y captura visual mediante OCR.
- Catálogo seleccionable de 14 modelos de clasificación.
- Modelo recomendado `LinkShield Hybrid Ensemble` con F1-score de **95.00 %**.
- Explicabilidad adaptada a cada familia: SHAP, permutación, oclusión de caracteres y reglas auditables.
- Perfiles de sensibilidad agresivo, equilibrado y pasivo sin alterar la probabilidad del modelo.
- Historial local con SQLite en Android e iOS e IndexedDB en navegador.
- Almacenamiento global opcional y condicionado por consentimiento.
- Dashboard, métricas, matriz de confusión e información del modelo activo.
- Asistente Anita con arquitectura multiagente, RAG y soporte local mediante Ollama.
- Interfaz adaptable con temas claro y oscuro.

## Arquitectura

```mermaid
flowchart LR
    U["Usuario"] --> A["Aplicación Flutter<br/>Android, iOS y web"]
    A -->|"JSON + X-API-KEY"| B["API REST Flask"]
    B --> R["Registro de 14 modelos"]
    R --> H["Ensamble híbrido"]
    H --> X["Explicabilidad"]
    B --> C["Anita: sistema multiagente"]
    C --> K["RAG + Ollama"]
    A --> L["Historial local<br/>SQLite / IndexedDB"]
    B -->|"store_global = true"| P["PostgreSQL"]
```

## Estructura del repositorio

| Módulo | Responsabilidad | Documentación |
|---|---|---|
| `phishing-url-ai` | Datos, entrenamiento, evaluación y exportación de modelos | [Modelos de IA](phishing-url-ai/README.md) |
| `phishing-url-api` | Inferencia, explicabilidad, persistencia y sistema multiagente | [API REST](phishing-url-api/README.md) |
| `phishing-url-app` | Aplicación Flutter para Android, iOS y navegador | [Aplicación](phishing-url-app/README.md) |

La [documentación de Anita](phishing-url-api/MULTIAGENT.md) detalla los agentes, la memoria conversacional, la persistencia y las trazas.

## Modelo recomendado

El modelo predeterminado es **LinkShield Hybrid Ensemble**. Integra cinco ramas y utiliza una regresión logística como meta-clasificador:

1. Random Forest sobre 25 características.
2. MLP regularizada sobre la entrada tabular.
3. CNN 1D sobre caracteres de la URL.
4. GRU sobre secuencias de caracteres.
5. Motor heurístico con reglas auditables.

| Métrica | Resultado |
|---|---:|
| Accuracy | 95.01 % |
| Precision | 95.25 % |
| Recall | 94.75 % |
| F1-score | 95.00 % |
| ROC-AUC | 0.9877 |

La matriz de confusión sobre 2,286 observaciones contiene 1,089 verdaderos negativos, 1,083 verdaderos positivos, 54 falsos positivos y 60 falsos negativos.

## Inicio rápido

La [guía de instalación y ejecución](INSTALACION.md) describe la configuración de la API, PostgreSQL, Flutter y las pruebas por plataforma.

### Requisitos

- Python 3.12.
- Flutter 3.38 o superior y Dart `^3.10.0`.
- PostgreSQL para persistencia global opcional.
- Ollama para respuestas generativas locales opcionales.

### 1. API

Desde la raíz del repositorio, en macOS o Linux:

```bash
cd phishing-url-api
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

Configura el archivo `.env` con una `API_KEY` de desarrollo y los parámetros de PostgreSQL según la [guía de instalación](INSTALACION.md). Con el entorno virtual activo, inicia el servicio:

```bash
python -m flask --app app run --host 127.0.0.1 --port 5058 --no-reload
```

La API queda disponible en `http://127.0.0.1:5058`. La guía incluye los comandos de preparación para Windows PowerShell.

### 2. Aplicación Flutter

Desde la raíz del repositorio:

```bash
cd phishing-url-app
flutter pub get
```

Configura `.vscode/api.local.json` con `API_BASE_URL` y la misma `API_KEY` del servidor. El archivo de configuración local está excluido del repositorio.

```bash
flutter run -d chrome --dart-define-from-file=.vscode/api.local.json
```

Para Android e iOS, selecciona el identificador del dispositivo con `flutter devices` y sigue la [documentación de la aplicación](phishing-url-app/README.md). La [guía de instalación](INSTALACION.md) detalla la conexión móvil, los orígenes web permitidos y la compilación de la APK de pruebas.

## Pruebas

```bash
# Backend
cd phishing-url-api
python -m pytest -q

# Aplicación
cd ../phishing-url-app
flutter analyze
flutter test
```

La verificación del segundo avance registró **105 pruebas backend**, **15 pruebas Flutter** y una prueba de persistencia IndexedDB ejecutada en Chrome. Se ejecutaron además 14 comprobaciones de aceptación técnica con cinco perfiles de prueba. En Chrome se verificó el flujo de selección de imagen, extracción OCR y análisis mediante la API. El 17 de noviembre de 2026, Alejandro Mayró Lena confirmó la ejecución y el funcionamiento de la aplicación en sus dispositivos Android e iOS. La auditoría de accesibilidad web forma parte de las actividades de cierre. Los requisitos de cada plataforma están en la [guía de la aplicación](phishing-url-app/README.md).

## Privacidad y seguridad

- `store_global=false` evita registrar análisis y conversaciones en el servidor.
- El historial local se conserva en el dispositivo o navegador del usuario.
- No publiques archivos `.env`, contraseñas, claves de API ni registros con datos sensibles.
- Una clave compilada en una aplicación web puede ser inspeccionada. En producción se requiere autenticación de usuarios, un proxy de backend y HTTPS.
- La clasificación es un apoyo preventivo: no reemplaza una revisión profesional ni demuestra por sí sola que un sitio sea malicioso.

## Estado del proyecto

Proyecto académico y experimental en desarrollo. La arquitectura, los modelos y las métricas están documentados para facilitar su reproducción, evaluación y evolución.

## Planificación y seguimiento

La planificación y el seguimiento de **LinkShield AI** se gestionan en GitHub Projects, donde se organizan las actividades, los hitos técnicos y académicos, las fechas y los estados de avance.

**[Ver el cronograma general (Gantt)](https://github.com/users/AlejandroDart/projects/1/views/5)**

El tablero permite revisar:

- **[Hitos del proyecto](https://github.com/users/AlejandroDart/projects/1/views/1):** resultados técnicos y compromisos de entrega.
- **[Tablero de actividades](https://github.com/users/AlejandroDart/projects/1/views/2):** implementación, integración, pruebas, seguridad y documentación, organizadas por estado.
- **[Cronograma de tareas](https://github.com/users/AlejandroDart/projects/1/views/3):** fechas de inicio y objetivo de las actividades.
- **[Entregas académicas](https://github.com/users/AlejandroDart/projects/1/views/4):** las cuatro entregas principales del proyecto.
- **[Cronograma general (Gantt)](https://github.com/users/AlejandroDart/projects/1/views/5):** hitos y actividades en una línea de tiempo para visualizar la secuencia de trabajo.

### Entregas principales de 2026

| Fecha | Hito | Entregable previsto |
|---|---|---|
| 27 de octubre | Primer informe y presentación, 70 % | MVP funcional, evidencia de pruebas y planificación actualizada. |
| 17 de noviembre | Segundo informe de avance, 90 % | Consolidación de la aplicación y resultados de rendimiento, seguridad y aceptación técnica, con prueba funcional en Android e iOS. |
| 8 de diciembre | Entrega final, 100 % | Solución y documentación finales, con resultados y evidencias del alcance aprobado. |
| 29 de diciembre | Presentación ante comisión | Defensa del proyecto, demostración y respaldo de resultados. |

Estos porcentajes corresponden a los hitos de entrega. El avance de cada actividad se registra por separado en el tablero. La planificación conserva los hitos técnicos iniciales y continúa con la consolidación, validación y cierre del proyecto.

**Responsable de la planificación y el seguimiento:** Alejandro Mayró Lena.

## Autor

**Alejandro Mayró Lena**

Proyecto desarrollado como solución de análisis y prevención de phishing.

