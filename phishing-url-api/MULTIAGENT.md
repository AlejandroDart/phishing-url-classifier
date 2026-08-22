# Sistema multiagente del chatbot

El endpoint `POST /chat` mantiene los campos compatibles `answer`, `sources` y
`model`, y agrega `interaction_id`, `conversation_id`, `intent`, `agents`,
`analysis`, `decision`, `trace` y `persisted`.

## Agentes

- `CoordinatorAgent`: identifica consulta general, análisis de URL o seguimiento.
- `AnalysisAgent`: usa `PredictionService`, el mismo clasificador de `/predict`.
- `DecisionAgent`: calcula utilidades conversacionales sin cambiar la clasificación.
- `ExplainabilityAgent`: usa RAG y Ollama; si Ollama falla durante un análisis,
  entrega una explicación determinista basada en el resultado técnico.

`PredictionService` calcula una explicación local con SHAP `TreeExplainer` para
la probabilidad de phishing. El bloque `explanation.shap` incluye probabilidad
base, verificación aditiva, principales factores y contribuciones de las 25
variables. `AnalysisAgent` entrega ese mismo bloque al agente explicativo.
Los valores, signos y magnitudes se renderizan de forma determinista para evitar
que el modelo de lenguaje altere la explicación. Ollama y RAG solo pueden aportar
una recomendación preventiva que pasa validaciones antes de incorporarse.

## Memoria y trazabilidad

La memoria corta usa `conversation_id`, TTL de dos horas y un máximo de 500
conversaciones. PostgreSQL conserva las interacciones y eventos en
`agent_interactions` y `agent_events`. Las tablas se crean al primer uso; también
existe la migración `database/migrations/001_multiagent_memory.sql`.

La persistencia PostgreSQL depende de `store_global`. Cuando vale `false`, el
chatbot no guarda la conversación, URL, resultado, SHAP, decisión ni eventos en
el servidor y tampoco recupera historial persistente; solo utiliza memoria corta
durante la sesión. Cuando vale `true`, se guardan tanto la predicción como la
interacción multiagente y sus trazas.

## Compatibilidad y reversión

El flujo está activo por defecto. Para volver temporalmente al chatbot RAG previo:

```env
MULTI_AGENT_CHAT_ENABLED=false
```

Ejemplo de análisis:

```json
{
  "question": "Analiza https://example.com/login",
  "conversation_id": "mobile-session-1",
  "history": [],
  "store_global": false
}
```
