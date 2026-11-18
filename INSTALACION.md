# Instalación y ejecución de LinkShield AI

LinkShield AI integra una aplicación Flutter, una API Flask y un catálogo de modelos de detección de phishing. Esta guía describe la configuración de desarrollo, la conexión entre componentes y las comprobaciones iniciales.

## Requisitos

- Python 3.12.
- Flutter 3.38 o superior y Dart 3.10 o superior, dentro de la versión admitida por `pubspec.yaml`.
- Android SDK y JDK 17 para Android.
- Xcode y CocoaPods para iOS, con objetivo mínimo iOS 15.0.
- Chrome para la versión web.
- PostgreSQL para habilitar el historial global y las estadísticas.
- Ollama y un modelo local instalado para las respuestas generativas opcionales de Anita.

Los comandos parten de la raíz del repositorio, salvo donde se indique otra carpeta. Los ejemplos utilizan el puerto `5058` para la API; cualquier cambio de puerto debe reflejarse en `API_BASE_URL`.

## Preparación de la API

En macOS o Linux:

```bash
cd phishing-url-api
python3.12 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

En Windows PowerShell:

```powershell
cd phishing-url-api
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

Crea `phishing-url-api/.env` con los parámetros del entorno:

```dotenv
API_KEY=REEMPLAZAR_CON_UNA_CLAVE_DE_DESARROLLO
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=REEMPLAZAR_CON_LA_CONTRASENA_DE_POSTGRESQL
DB_NAME=phishing_detector
MULTI_AGENT_CHAT_ENABLED=true
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_CHAT_MODEL=NOMBRE_DEL_MODELO_INSTALADO
```

La misma `API_KEY` debe configurarse en el cliente Flutter. El archivo `.env` y la configuración local del cliente están excluidos del control de versiones. `PREDICTION_NETWORK_FEATURES=false` permite realizar pruebas con enlaces controlados sin consultar recursos externos; para utilizar las señales externas se habilita esa opción según el entorno.

## Base de datos

Con PostgreSQL en ejecución, crea una base vacía y aplica las migraciones desde `phishing-url-api`:

```bash
createdb -U postgres phishing_detector
psql -U postgres -d phishing_detector -f database/migrations/000_predictions.sql
psql -U postgres -d phishing_detector -f database/migrations/001_multiagent_memory.sql
psql -U postgres -d phishing_detector -f database/migrations/002_prediction_model.sql
psql -U postgres -d phishing_detector -f database/migrations/003_prediction_sensitivity.sql
```

Las predicciones pueden ejecutarse sin PostgreSQL cuando el almacenamiento global está desactivado. Las estadísticas globales y la memoria persistente de Anita requieren una conexión válida a la base de datos.

## Inicio de la API

Desde `phishing-url-api`, con el entorno virtual activo:

```bash
python -m flask --app app run --host 127.0.0.1 --port 5058 --no-reload
```

Abre `http://127.0.0.1:5058/` para comprobar el servicio. El catálogo, la predicción, las estadísticas y Anita requieren el encabezado `X-API-KEY` con la clave configurada.

Para pruebas con un dispositivo móvil en la misma red, inicia la API con `--host 0.0.0.0` y configura en Flutter la dirección del servidor accesible desde ese dispositivo. `127.0.0.1` dentro del teléfono corresponde al propio teléfono. El servidor de desarrollo se utiliza para pruebas locales; un despliegue público requiere HTTPS, un servidor WSGI y autenticación de usuarios.

## Configuración de Flutter

Crea `phishing-url-app/.vscode/api.local.json`:

```json
{
  "API_BASE_URL": "http://127.0.0.1:5058",
  "API_KEY": "REEMPLAZAR_CON_LA_MISMA_CLAVE_DE_LA_API"
}
```

Para Android o iOS físicos, sustituye la dirección de bucle local por la dirección del servidor en la red de pruebas. La IP y el puerto deben coincidir con el servicio Flask. En web, configura `CORS_ALLOWED_ORIGINS` en la API con el origen exacto del cliente, incluido su puerto.

Desde `phishing-url-app`:

```bash
flutter pub get
flutter devices
flutter run -d ID_DEL_DISPOSITIVO --dart-define-from-file=.vscode/api.local.json
```

Para ejecutar en Chrome, utiliza `-d chrome`. Para iOS, utiliza el identificador del iPhone o simulador y concede los permisos de red local y cámara cuando correspondan.

## APK de pruebas

Desde `phishing-url-app`:

```bash
flutter build apk --profile --dart-define-from-file=.vscode/api.local.json
```

El archivo se genera en `build/app/outputs/flutter-apk/app-profile.apk`. La compilación de pruebas admite HTTP en una red local. La compilación móvil `release` requiere una dirección HTTPS. Las credenciales incluidas en una compilación son recuperables, por lo que la distribución pública requiere mantener las credenciales de servicio en el backend.

## Comprobaciones

Desde `phishing-url-api`:

```bash
python -m pytest -q
```

Desde `phishing-url-app`:

```bash
flutter analyze
flutter test
```

La verificación funcional incluye ingresar una URL controlada, analizarla, revisar la explicación y consultar el historial. La persistencia global se comprueba al habilitar expresamente el almacenamiento en el servidor.

## Documentación

- [Descripción y resultados del proyecto](README.md).
- [API REST y variables de entorno](phishing-url-api/README.md).
- [Aplicación Flutter y plataformas](phishing-url-app/README.md).
- [Modelos, notebooks y métricas](phishing-url-ai/README.md).
- [Arquitectura conversacional de Anita](phishing-url-api/MULTIAGENT.md).
