# AGENTS.md

## Propósito

Este repositorio contiene una aplicación orientada a la detección preliminar de URLs potencialmente asociadas a phishing. La aplicación ya dispone de un flujo principal de análisis de URLs y de un chatbot con integración de Ollama y RAG sobre una base de conocimiento documental.

La tarea actual consiste en incorporar una arquitectura multiagente específicamente al módulo conversacional, reutilizando las funcionalidades existentes y evitando modificar innecesariamente el flujo principal de detección.

## Regla principal

Antes de modificar código:

1. Analiza la estructura completa del proyecto.
2. Identifica el chatbot, la integración con Ollama, RAG, el detector de URLs, las API existentes, la persistencia y cualquier mecanismo actual de historial o sesión.
3. Explica qué archivos y componentes participan actualmente en cada flujo.
4. Propón un plan de modificación mínimo y compatible con la arquitectura existente.
5. No realices cambios hasta haber entendido las dependencias principales.

## Restricciones de arquitectura

- NO reimplementar el detector de phishing.
- NO reemplazar el flujo principal existente de análisis de URLs.
- NO utilizar el LLM para decidir técnicamente si una URL es phishing.
- NO alterar el funcionamiento normal de las consultas generales del chatbot salvo que sea necesario para integrar la orquestación.
- Reutilizar las funciones, servicios y API existentes siempre que sea posible.
- Mantener separación entre clasificación técnica, decisión conversacional y explicación al usuario.
- Priorizar cambios pequeños, modulares y trazables.
- Evitar frameworks multiagente complejos si no son necesarios.
- La solución puede implementarse mediante clases, servicios o módulos especializados adaptados al proyecto real.

## Arquitectura multiagente objetivo

### Agente Coordinador

Responsabilidades:
- recibir la solicitud del usuario desde el chatbot;
- identificar la intención principal;
- diferenciar consulta general, análisis de URL y consulta posterior relacionada con un análisis previo;
- determinar qué agentes deben intervenir;
- coordinar la secuencia del flujo;
- mantener o recuperar la referencia de la interacción cuando sea necesario.

La detección inicial de intención puede resolverse mediante reglas determinísticas o una solución simple y verificable. El uso de Ollama para intención es opcional.

### Agente de Análisis

Responsabilidades:
- recibir una URL desde el Agente Coordinador;
- invocar el mecanismo EXISTENTE de detección de phishing;
- no duplicar la lógica del clasificador;
- validar la respuesta técnica;
- estructurar el resultado para los agentes posteriores.

Debe devolver, según lo que ya produzca el sistema:
- URL analizada;
- clasificación;
- probabilidad o score;
- indicadores técnicos;
- identificador de interacción;
- fecha/hora cuando corresponda.

### Agente de Decisión

Responsabilidades:
- recibir el resultado técnico del Agente de Análisis;
- determinar el nivel de riesgo o la acción conversacional;
- mantener separada esta decisión de la clasificación técnica original;
- aplicar lógica explícita y verificable.

Ejemplos conceptuales:
- riesgo reducido -> informar;
- escenario intermedio -> recomendar precaución;
- riesgo elevado -> generar advertencia prioritaria.

Los umbrales reales deberán definirse a partir de lo que entregue actualmente el detector.

### Agente de Conocimiento y Explicabilidad

Responsabilidades:
- mantener la funcionalidad actual de consultas generales;
- utilizar Ollama y RAG cuando corresponda;
- recibir resultados técnicos y decisiones;
- transformarlos en explicaciones claras;
- incorporar recomendaciones coherentes;
- no modificar la clasificación técnica;
- no asumir el rol del clasificador.

## Flujos esperados

### Consulta general

Usuario -> Agente Coordinador -> Agente de Conocimiento y Explicabilidad -> Ollama + RAG -> Respuesta

### Análisis de URL

Usuario -> Agente Coordinador -> Agente de Análisis -> detector existente -> Agente de Decisión -> Agente de Conocimiento y Explicabilidad -> Respuesta

### Consulta posterior

Ejemplo:
1. Usuario: "Analiza esta URL".
2. El sistema procesa la URL.
3. Usuario: "¿Por qué apareció como peligrosa?"
4. El Agente Coordinador recupera el contexto del análisis anterior.
5. El Agente de Conocimiento y Explicabilidad responde usando ese contexto.

## Memoria

### Memoria de corto plazo

Conservar temporalmente el contexto de la conversación actual:
- última URL analizada;
- clasificación;
- probabilidad o score;
- nivel de riesgo;
- indicadores;
- decisión;
- interaction_id.

Debe permitir resolver consultas posteriores sin repetir todo el flujo cuando no sea necesario.

### Memoria persistente

Conservar historial de análisis más allá de la sesión actual, reutilizando la persistencia existente cuando sea razonable.

Datos deseables:
- interaction_id;
- URL;
- fecha/hora;
- clasificación;
- probabilidad o score;
- riesgo;
- indicadores;
- decisión;
- estado.

La memoria persistente representa historial. No debe tratar automáticamente un resultado histórico como una evaluación actual si el usuario solicita un nuevo análisis.

## Comunicación

### Comunicación síncrona

Usar llamadas directas o solicitudes a servicios/API cuando un componente deba esperar la respuesta del anterior.

### Mensajes/eventos estructurados

Representar explícitamente los intercambios relevantes mediante objetos, estructuras o registros.

Eventos sugeridos:
- SOLICITUD_ANALISIS
- RESULTADO_ANALISIS
- DECISION_RIESGO
- SOLICITUD_EXPLICACION
- RESPUESTA_GENERADA
- CONSULTA_GENERAL
- ERROR_ANALISIS

No es obligatorio usar RabbitMQ, Kafka ni infraestructura externa. Una implementación interna es suficiente si permite identificar emisor, receptor, contenido, interacción y momento del evento.

## Trazabilidad

Registrar eventos suficientes para reconstruir una interacción, idealmente con:
- timestamp;
- interaction_id;
- agente emisor;
- agente receptor;
- tipo de evento;
- estado;
- resumen del contenido;
- duración cuando corresponda.

Los logs deberán servir posteriormente como evidencia para evaluar el comportamiento colectivo.

## Estrategia de cambios

Trabajar en etapas:
1. Diagnóstico del proyecto actual.
2. Mapeo de componentes existentes.
3. Integración del Agente Coordinador.
4. Encapsulación del detector existente mediante el Agente de Análisis.
5. Implementación del Agente de Decisión.
6. Adaptación del componente Ollama/RAG como Agente de Conocimiento y Explicabilidad.
7. Memoria de corto plazo.
8. Memoria persistente.
9. Mensajes/eventos y logs.
10. Pruebas.
11. Evidencias para el informe.

## Pruebas mínimas esperadas

- consulta general sin URL;
- análisis de una URL;
- consulta posterior sobre la última URL;
- recuperación de un análisis anterior;
- manejo de URL inválida;
- manejo de indisponibilidad del detector;
- continuidad del chatbot general;
- generación de logs/trazas;
- medición del tiempo total de respuesta.

Utilizar ejemplos seguros o sintéticos durante las pruebas.

## Criterios de calidad

- No romper funcionalidades existentes.
- Código modular y legible.
- Responsabilidades separadas.
- Manejo explícito de errores.
- Logs útiles.
- Evitar duplicación.
- Mantener compatibilidad con la arquitectura actual.
- Documentar cualquier decisión que difiera del diseño conceptual.

## Entrega de cada etapa

Después de cada cambio importante:
1. Indicar archivos modificados.
2. Explicar qué se cambió.
3. Explicar por qué.
4. Mostrar cómo probarlo.
5. Informar limitaciones.
6. No declarar una función como terminada sin validación razonable.
