# CONTEXTO_PROYECTO.md

## 1. Objetivo actual

El proyecto corresponde a una aplicación orientada a apoyar la detección y comprensión de URLs potencialmente asociadas a phishing.

La aplicación ya cuenta con capacidades previamente desarrolladas. La etapa actual del trabajo académico requiere evolucionar el módulo conversacional hacia una arquitectura multiagente, manteniendo el detector técnico de phishing como una capacidad independiente y reutilizable.

El propósito NO es reconstruir toda la aplicación. El objetivo es incorporar agentes especializados al chatbot y posteriormente evaluar su comportamiento colectivo mediante pruebas, registros, trazas e indicadores.

## 2. Estado conceptual definido

La arquitectura multiagente se incorpora específicamente al chatbot.

El mecanismo principal de análisis de URLs existente debe permanecer independiente. Cuando el usuario solicite un análisis desde el chatbot, un agente especializado utilizará dicha funcionalidad como servicio.

El modelo de lenguaje no debe clasificar técnicamente la URL. Su función es explicar resultados y responder consultas utilizando el contexto disponible.

## 3. Componentes existentes que Codex debe localizar

Antes de programar, revisar el repositorio e identificar:

- frontend o aplicación cliente;
- módulo/pantalla del chatbot;
- backend del chatbot;
- integración con Ollama;
- implementación actual de RAG;
- PDF o base documental utilizada por RAG;
- endpoint, función o servicio actual de análisis de URLs;
- modelo de clasificación y forma en que es invocado;
- API existente;
- base de datos;
- tablas o estructuras relacionadas con predicciones/historial;
- almacenamiento local si existe;
- manejo actual de sesiones o historial del chatbot;
- configuración y variables de entorno relevantes.

No asumir nombres de archivos. Descubrirlos en el repositorio.

## 4. Agentes definidos

### Agente Coordinador

Rol: orquestador y supervisor del flujo conversacional.

Tareas:
- recibir la solicitud;
- identificar intención;
- decidir si es consulta general, análisis de URL o consulta posterior;
- activar únicamente los agentes necesarios;
- coordinar el flujo;
- mantener referencia de interacción;
- recuperar contexto cuando corresponda.

### Agente de Análisis

Rol: especialista técnico en evaluación de URLs.

Tareas:
- recibir URL;
- utilizar el detector existente;
- recuperar clasificación, probabilidad/score e indicadores;
- validar la respuesta;
- estructurar el resultado;
- entregarlo al Agente de Decisión.

Importante: no reimplementa el detector.

### Agente de Decisión

Rol: evaluador y selector de acciones conversacionales.

Tareas:
- recibir resultado técnico;
- considerar clasificación, probabilidad/score e indicadores;
- determinar nivel de riesgo;
- seleccionar una acción conversacional;
- entregar dicha decisión al agente explicativo.

La decisión conversacional no reemplaza la clasificación técnica.

### Agente de Conocimiento y Explicabilidad

Rol: comunicador y especialista en conocimiento.

Tareas:
- responder consultas generales;
- utilizar Ollama;
- utilizar RAG/base documental cuando corresponda;
- recibir resultado técnico + decisión;
- generar explicación comprensible;
- entregar recomendaciones;
- mantener intacta la clasificación original.

## 5. Flujos definidos

### Flujo A: consulta general

```text
Usuario
  ↓
Agente Coordinador
  ↓
Agente de Conocimiento y Explicabilidad
  ↓
Ollama + RAG/base documental
  ↓
Respuesta
```

Este flujo debe conservar, en lo posible, el comportamiento actual del chatbot.

### Flujo B: análisis de URL

```text
Usuario
  ↓
Agente Coordinador
  ↓
Agente de Análisis
  ↓
Detector existente
  ↓
Agente de Decisión
  ↓
Agente de Conocimiento y Explicabilidad
  ↓
Respuesta
```

### Flujo C: pregunta posterior

```text
Usuario: Analiza esta URL.
Sistema: [ejecuta flujo B]

Usuario: ¿Por qué apareció como peligrosa?
  ↓
Agente Coordinador
  ↓
Memoria de corto plazo
  ↓
Agente de Conocimiento y Explicabilidad
  ↓
Respuesta contextual
```

## 6. Memoria definida

### Memoria de corto plazo

Objetivo: conservar el contexto inmediato de la conversación.

Posibles datos:
- última URL analizada;
- clasificación;
- score/probabilidad;
- riesgo;
- indicadores;
- decisión;
- interaction_id.

Efectos esperados:
- continuidad conversacional;
- menor repetición;
- coherencia entre preguntas relacionadas;
- evitar repetir todo el análisis cuando solo se solicita una explicación.

### Memoria persistente

Objetivo: mantener historial después de finalizar la conversación.

Posibles datos:
- URL;
- fecha y hora;
- clasificación;
- probabilidad/score;
- nivel de riesgo;
- indicadores;
- decisión;
- interaction_id.

Efectos esperados:
- recuperación histórica;
- trazabilidad;
- evidencia de ejecución;
- apoyo a la evaluación.

Importante: un resultado histórico no debe sustituir automáticamente un nuevo análisis cuando el usuario solicita una evaluación actual.

## 7. Comunicación definida

### Comunicación síncrona

Se utilizará en dependencias secuenciales donde un componente necesita la respuesta del anterior.

```text
Coordinador
→ Análisis
→ Detector
→ Decisión
→ Explicabilidad
```

### Comunicación mediante mensajes/eventos

Utilizar estructuras identificables para representar intercambios.

Ejemplos:
```text
SOLICITUD_ANALISIS
RESULTADO_ANALISIS
DECISION_RIESGO
SOLICITUD_EXPLICACION
RESPUESTA_GENERADA
CONSULTA_GENERAL
ERROR_ANALISIS
```

Datos deseables:
```text
event_id
interaction_id
timestamp
emisor
receptor
tipo
payload/resumen
estado
```

No se requiere infraestructura de mensajería distribuida. Los eventos pueden implementarse internamente.

## 8. Trazabilidad

Las interacciones deberán producir registros que permitan reconstruir el flujo.

Ejemplo:

```text
[interaction_id=abc123]
Coordinador -> SOLICITUD_ANALISIS
Análisis -> detector_invocado
Análisis -> RESULTADO_ANALISIS
Decisión -> DECISION_RIESGO
Explicabilidad -> RESPUESTA_GENERADA
Coordinador -> respuesta_entregada
```

Esta información se utilizará posteriormente en el informe como evidencia observable.

## 9. Estado del informe académico

### I. Descripción general del sistema multiagente
Desarrollada.

### II. Organización del sistema multiagente
Desarrollada:
1. Agentes participantes.
2. Roles.
3. Tareas.
4. Jerarquía.
5. Relación y coordinación entre agentes.
6. Impacto de la estructura en el comportamiento colectivo.

### III. Mecanismos de memoria y comunicación
Desarrollada conceptualmente:
1. Memoria de corto plazo.
2. Memoria persistente.
3. Comunicación síncrona.
4. Comunicación mediante mensajes/eventos.
5. Efecto de los mecanismos de memoria.
6. Efecto de los mecanismos de comunicación.
7. Impacto en la coherencia y efectividad del comportamiento colectivo.

### IV. Implementación del sistema multiagente

Esta es la fase que comienza ahora.

Estructura prevista:
1. Integración con el chatbot existente.
2. Implementación del Agente Coordinador.
3. Implementación del Agente de Análisis.
4. Implementación del Agente de Decisión.
5. Implementación del Agente de Conocimiento y Explicabilidad.
6. Implementación de memoria de corto plazo.
7. Implementación de memoria persistente.
8. Implementación de comunicación entre agentes.
9. Registro de eventos y trazabilidad.
10. Flujo completo de funcionamiento.

El contenido definitivo debe escribirse después de implementar, para describir lo que realmente se construyó.

### V. Evaluación del sistema multiagente

Se desarrollará con el sistema funcionando:
1. Metodología de prueba.
2. Escenarios de simulación.
3. Indicadores de desempeño.
4. Registros y trazas de ejecución.
5. Resultados obtenidos.
6. Análisis de resultados.
7. Conclusiones sobre desempeño.
8. Fortalezas.
9. Limitaciones.
10. Oportunidades de mejora.

## 10. Evidencias que necesitaremos

Durante implementación y pruebas conservar:
- capturas relevantes;
- logs;
- trazas por interaction_id;
- tiempos de inicio y fin;
- resultados de cada agente;
- errores controlados;
- ejemplos de memoria;
- evidencia de recuperación de contexto;
- evidencia de consulta general;
- evidencia de análisis de URL;
- evidencia de consulta posterior;
- cantidad de agentes activados por escenario.

## 11. Indicadores a preparar

Registrar datos que permitan calcular:
- tiempo total de respuesta;
- tiempo por etapa/agente;
- tasa de finalización correcta del flujo;
- cantidad de agentes activados;
- eventos generados;
- recuperación correcta de contexto;
- recuperación correcta de historial;
- errores detectados/manejados;
- consistencia entre clasificación técnica y explicación.

Los indicadores definitivos se ajustarán después de revisar la implementación real.

## 12. Principios de implementación

1. Reutilizar antes de reescribir.
2. Mantener el detector independiente.
3. No permitir que Ollama determine la clasificación técnica.
4. Mantener consultas generales operativas.
5. Separar claramente responsabilidades.
6. Evitar dependencias innecesarias.
7. Implementar logs desde el comienzo.
8. Asignar identificadores a las interacciones.
9. Tratar la memoria histórica como historial, no como verdad actual.
10. Manejar errores de cada etapa.
11. Priorizar un prototipo funcional y demostrable.
12. No agregar complejidad que no aporte a la evaluación académica.

## 13. Primera tarea para Codex

Antes de modificar archivos, realizar un diagnóstico del proyecto y responder:

1. ¿Cuál es la estructura principal del repositorio?
2. ¿Dónde está implementado el chatbot?
3. ¿Dónde se integra Ollama?
4. ¿Dónde está implementado RAG?
5. ¿Cómo se carga/consulta la base documental?
6. ¿Dónde está el detector de URLs?
7. ¿Cómo se invoca actualmente?
8. ¿Qué datos devuelve?
9. ¿Qué persistencia existe?
10. ¿Cómo se comunica frontend y backend?
11. ¿Existe memoria conversacional?
12. ¿Existe logging útil?
13. ¿Qué archivos deberían modificarse?
14. ¿Qué componentes pueden reutilizarse?
15. ¿Qué riesgos de regresión existen?

Después del diagnóstico, proponer un plan incremental.

NO modificar código durante esta primera revisión.

## 14. Prompt inicial sugerido para Codex

```text
Lee primero AGENTS.md y CONTEXTO_PROYECTO.md completos.

No modifiques código todavía.

Analiza el proyecto actual y localiza específicamente:
- chatbot;
- integración con Ollama;
- RAG y base documental;
- detector existente de URLs;
- API/backend;
- persistencia/base de datos;
- historial o memoria conversacional;
- logs existentes.

Luego explícame cómo funciona actualmente el flujo del chatbot y el flujo de análisis de URLs, indicando los archivos involucrados.

Después compara la arquitectura actual con la arquitectura multiagente definida en CONTEXTO_PROYECTO.md y propón un plan incremental para implementar los cuatro agentes, las dos memorias, la comunicación síncrona, los mensajes/eventos y la trazabilidad.

Restricciones:
- no reimplementar el detector;
- no modificar innecesariamente el flujo principal de análisis;
- Ollama no debe decidir técnicamente si una URL es phishing;
- reutilizar al máximo lo que ya funciona;
- no agregar frameworks complejos si no son necesarios;
- no hagas cambios hasta que revisemos primero tu diagnóstico y plan.
```

## 15. Resultado esperado

Al finalizar la implementación, el proyecto debe conservar sus funcionalidades actuales y añadir una capa multiagente observable y evaluable dentro del chatbot.

El sistema deberá permitir demostrar que agentes especializados colaboran mediante información estructurada, memoria y mecanismos de comunicación para resolver consultas generales y análisis de URLs, generando además registros suficientes para evaluar posteriormente su comportamiento colectivo.
