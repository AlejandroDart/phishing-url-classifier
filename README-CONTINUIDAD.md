# LinkShield AI: continuidad del proyecto

**Autor:** Alejandro Mayró Lena. LinkShield AI analiza URLs y explica el riesgo de phishing. La app está en [`phishing-url-app`](phishing-url-app/README.md), la API Flask en [`phishing-url-api`](phishing-url-api/README.md) y los modelos en [`phishing-url-ai`](phishing-url-ai/README.md).

## Últimos cambios

- **Preferencias:** textos más claros para tema y almacenamiento, descripciones de sensibilidad en una línea y descripciones de los modelos justificadas. No cambió el cálculo del umbral.
- **Anita:** encabezado «Anita / LinkShield AI» y campo «Tu pregunta» en una línea.
- **Conexión:** la IP y la clave de pruebas se configuran por equipo. No están en el código publicado.

## Arrancar en otro PC

1. Clona este repositorio o actualiza `main` con `git pull --ff-only`. Instala las dependencias según los README de la [API](phishing-url-api/README.md) y la [app](phishing-url-app/README.md).
2. En `phishing-url-api`, crea un `.env` local con una `API_KEY` de desarrollo. Para Android físico, inicia la API en la IP del PC accesible desde el teléfono: `python -m flask --app app run --host IP_DEL_PC --port 5000 --no-reload`. Usa una red de pruebas y confirma desde el teléfono que abre `http://IP_DEL_PC:5000/`.
3. En `phishing-url-app`, crea `.vscode/api.local.json` con la misma clave de la API y la IP **del nuevo PC**:

   ```json
   {
     "API_BASE_URL": "http://IP_DEL_PC:5000",
     "API_KEY": "CLAVE_DE_DESARROLLO"
   }
   ```

4. Conecta el teléfono por USB y selecciona **Android**, no Chrome. Desde la carpeta de la app, ejecuta:

   ```powershell
   flutter pub get
   flutter devices
   flutter run -d ID_DEL_TELEFONO --dart-define-from-file=.vscode/api.local.json
   ```

   Para iniciar con `F5` de forma habitual, agrega `"dart.flutterRunAdditionalArgs": ["--dart-define-from-file=.vscode/api.local.json"]` a los ajustes de la carpeta en VS Code. No hace falta crear un perfil de lanzamiento.

PostgreSQL se configura aparte para estadísticas y persistencia global. El cliente envía la clave también para las estadísticas. Si sirves Flutter Web por la red local, configura `CORS_ALLOWED_ORIGINS` en Flask con el origen exacto del sitio. Android nativo no usa CORS. Si el teléfono llega a la API pero no carga los modelos, revisa que ambas claves coincidan. Si cambias la IP o la clave, detén y vuelve a ejecutar la app. Android `release` requiere HTTPS.

Para iOS y web, sigue la [guía por plataforma](phishing-url-app/README.md). La versión de semana 7 incluye OCR en Chrome, el objetivo mínimo de iOS 15.0 y OCR nativo para iOS y Android. El autor confirmó el funcionamiento de la aplicación en sus dispositivos Android e iOS el 17 de noviembre de 2026. Para nuevas compilaciones se requiere Xcode o el SDK de Android, según la plataforma.

## Retomar en un chat nuevo

> Estoy continuando LinkShield AI desde `main`. Lee este README y revisa `git status` antes de editar. En el corte de semana 7 se reforzaron el contrato de la API, los seguimientos de Anita y el soporte de OCR. Los modelos exportados y sus umbrales se conservaron. La configuración local de pruebas se mantiene fuera del repositorio.

[Tablero del proyecto](https://github.com/users/AlejandroDart/projects/1) · [Cronograma Gantt](https://github.com/users/AlejandroDart/projects/1/views/5)
