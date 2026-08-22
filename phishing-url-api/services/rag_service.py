import json
import os
import re
import threading
import unicodedata
from pathlib import Path

import requests
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity


SPANISH_STOP_WORDS = [
    "a", "al", "algo", "como", "con", "cual", "cuando", "de", "del",
    "desde", "donde", "el", "ella", "en", "entre", "es", "esa", "ese",
    "esta", "este", "esto", "la", "las", "lo", "los", "me", "mi", "no",
    "o", "para", "pero", "por", "porque", "que", "se", "sin", "sobre",
    "son", "su", "sus", "te", "tu", "un", "una", "uno", "y", "ya",
]


class OllamaUnavailableError(RuntimeError):
    pass


class RagService:
    def __init__(self):
        self.knowledge_path = Path(
            os.getenv(
                "CHATBOT_KNOWLEDGE_PATH",
                Path(__file__).resolve().parent.parent
                / "chatbot"
                / "conocimiento_phishing.txt",
            )
        )
        self.ollama_url = os.getenv(
            "OLLAMA_BASE_URL", "http://127.0.0.1:11434"
        ).rstrip("/")
        self.configured_model = os.getenv("OLLAMA_CHAT_MODEL", "").strip()
        self._lock = threading.RLock()
        self._knowledge_mtime = None
        self._chunks = []
        self._vectorizer = None
        self._matrix = None

    def _split_knowledge(self, text):
        sections = re.split(r"(?m)^##\s+", text)
        chunks = []

        for section in sections:
            section = section.strip()
            if not section:
                continue

            lines = section.splitlines()
            title = lines[0].strip("# ")
            body = "\n".join(lines[1:]).strip() if len(lines) > 1 else title
            paragraphs = [
                paragraph.strip()
                for paragraph in re.split(r"\n\s*\n", body)
                if paragraph.strip()
            ]

            current = []
            current_length = 0
            for paragraph in paragraphs:
                if current and current_length + len(paragraph) > 1400:
                    chunks.append({
                        "title": title,
                        "text": f"{title}\n" + "\n\n".join(current),
                    })
                    current = current[-1:]
                    current_length = sum(len(item) for item in current)

                current.append(paragraph)
                current_length += len(paragraph)

            if current:
                chunks.append({
                    "title": title,
                    "text": f"{title}\n" + "\n\n".join(current),
                })

        return chunks

    def _ensure_index(self):
        if not self.knowledge_path.exists():
            raise FileNotFoundError(
                f"No existe la base de conocimiento: {self.knowledge_path}"
            )

        mtime = self.knowledge_path.stat().st_mtime
        with self._lock:
            if self._knowledge_mtime == mtime and self._matrix is not None:
                return

            text = self.knowledge_path.read_text(encoding="utf-8")
            chunks = self._split_knowledge(text)
            if not chunks:
                raise ValueError("La base de conocimiento esta vacia")

            vectorizer = TfidfVectorizer(
                strip_accents="unicode",
                lowercase=True,
                ngram_range=(1, 2),
                sublinear_tf=True,
                stop_words=SPANISH_STOP_WORDS,
            )
            matrix = vectorizer.fit_transform(
                [chunk["text"] for chunk in chunks]
            )

            self._chunks = chunks
            self._vectorizer = vectorizer
            self._matrix = matrix
            self._knowledge_mtime = mtime

    def _retrieve(self, question, limit=4):
        self._ensure_index()
        question_vector = self._vectorizer.transform([question])
        scores = cosine_similarity(question_vector, self._matrix)[0]
        ranked_indices = scores.argsort()[::-1]

        matches = []
        for index in ranked_indices[:limit]:
            score = float(scores[index])
            if score <= 0:
                continue
            chunk = self._chunks[index]
            matches.append({**chunk, "score": score})

        return matches

    def _social_response(self, question, history=None):
        normalized = unicodedata.normalize("NFKD", question.lower())
        normalized = "".join(
            character for character in normalized
            if not unicodedata.combining(character)
        )
        words = set(re.findall(r"[a-z0-9]+", normalized))

        greetings = {"hola", "buenas", "saludos", "hey", "holi"}
        farewells = {"adios", "chao", "chau", "hasta", "vemos"}
        thanks = {"gracias", "agradecido", "agradecida"}

        identity_phrases = (
            "como te llamas",
            "cual es tu nombre",
            "quien eres",
            "dime tu nombre",
            "nombre del chatbot",
        )
        if any(phrase in normalized for phrase in identity_phrases):
            return (
                "Me llamo Anita. Soy la asistente virtual de ciberseguridad "
                "de la aplicación LinkShield AI."
            )

        wellbeing_phrases = (
            "como estas",
            "como te encuentras",
            "que tal estas",
            "todo bien",
        )
        if any(phrase in normalized for phrase in wellbeing_phrases):
            return (
                "¡Estoy muy bien y listo para ayudarte! Puedes preguntarme "
                "sobre LinkShield AI, phishing o seguridad de enlaces."
            )

        exposed_password_phrases = (
            "entregue mi contrasena",
            "ingrese mi contrasena",
            "introduje mi contrasena",
            "di mi contrasena",
            "escribi mi contrasena",
            "comparti mi contrasena",
            "robaron mi contrasena",
        )
        if any(phrase in normalized for phrase in exposed_password_phrases):
            return (
                "Cambia inmediatamente esa contraseña desde el sitio oficial, "
                "cierra las sesiones activas y habilita autenticación "
                "multifactor. Si la reutilizabas, cámbiala también en los demás "
                "servicios."
            )

        harmful_phrases = (
            "crear una pagina de phishing",
            "crear phishing",
            "robar contrasenas",
            "capturar credenciales",
            "robar credenciales",
        )
        if any(phrase in normalized for phrase in harmful_phrases):
            return (
                "No puedo ayudar a crear phishing ni a obtener credenciales. Sí puedo "
                "explicar cómo reconocer esas técnicas, prevenirlas o preparar una "
                "demostración defensiva que no capture datos reales."
            )

        full_process_phrases = (
            "cual es el proceso completo",
            "proceso completo",
            "flujo completo",
            "como funciona el sistema",
            "como funciona el analisis",
            "como trabajan los agentes",
            "flujo de los agentes",
            "proceso multiagente",
        )
        if any(phrase in normalized for phrase in full_process_phrases):
            return (
                "El sistema tiene dos flujos principales:\n\n"
                "ANÁLISIS DE UNA URL\n"
                "1. El usuario envía la URL desde el chat o el ESCÁNER.\n"
                "2. El agente coordinador reconoce la solicitud y activa el flujo técnico.\n"
                "3. El agente de análisis extrae 25 características y ejecuta el clasificador.\n"
                "4. El agente de decisión evalúa la probabilidad y selecciona una acción por utilidad.\n"
                "5. El agente de conocimiento y explicabilidad incorpora SHAP y prepara la recomendación.\n"
                "6. Anita presenta clasificación, probabilidad, factores influyentes y medidas preventivas.\n"
                "7. El resultado solo se guarda globalmente si ALMACENAMIENTO está activado.\n\n"
                "CONSULTA DE LA BASE DE CONOCIMIENTO\n"
                "1. El usuario realiza una pregunta sobre phishing, ciberseguridad o la aplicación.\n"
                "2. El agente coordinador la identifica como consulta general.\n"
                "3. El agente de conocimiento usa el diccionario técnico o recupera contenido mediante RAG.\n"
                "4. Cuando corresponde, Ollama redacta la respuesta usando únicamente ese contexto.\n"
                "5. Anita presenta la respuesta; el clasificador de URLs no se ejecuta en esta ruta."
            )

        how_to_use_phrases = (
            "como usar la app",
            "como uso la app",
            "como usar la aplicacion",
            "como uso linkshield",
            "como se usa linkshield",
        )
        if any(phrase in normalized for phrase in how_to_use_phrases):
            return (
                "Para analizar un enlace con LinkShield AI:\n"
                "1. Obtén el enlace sin abrirlo: cópialo, compártelo o captúralo con ESCANEO VISUAL.\n"
                "2. Abre ESCÁNER y pega o revisa la URL detectada.\n"
                "3. Comprueba que el dominio y sus caracteres sean correctos.\n"
                "4. Pulsa ANÁLISIS IA para ejecutar el clasificador.\n"
                "5. Revisa la clasificación, la probabilidad y los factores explicados con SHAP.\n"
                "6. Verifica por un canal oficial cualquier solicitud de credenciales, dinero o datos.\n"
                "7. Si ALMACENAMIENTO está activo, el resultado aparecerá en el historial global; "
                "el historial local permanece en el dispositivo."
            )

        missing_analysis_phrases = (
            "por que llegaste a esa conclusion",
            "analisis anterior",
            "resultado anterior",
            "cual fue la probabilidad",
            "que caracteristica influyo mas",
            "que factor influyo mas",
        )
        if any(phrase in normalized for phrase in missing_analysis_phrases):
            return (
                "No tengo un análisis previo en esta conversación. Envíame una URL "
                "completa o escribe, por ejemplo, «Analiza ejemplo.com»; después podré "
                "explicar su probabilidad y sus factores SHAP."
            )

        url_capability_phrases = (
            "puedes analizar una url",
            "puedes analizar url",
            "puedes analizar un enlace",
            "puedes revisar una url",
            "puedes revisar un enlace",
            "eres capaz de analizar una url",
        )
        if any(phrase in normalized for phrase in url_capability_phrases):
            return (
                "Sí, puedo analizar una URL con el clasificador, calcular su "
                "probabilidad de phishing y explicar qué factores SHAP "
                "influyeron. Envíamela con o sin protocolo, por ejemplo: "
                "«Analiza ejemplo.com»."
            )

        capability_confirmation_phrases = (
            "pero puedes",
            "entonces puedes",
            "puedes o no",
            "de verdad puedes",
        )
        if any(phrase in normalized for phrase in capability_confirmation_phrases):
            previous_text = " ".join(
                str(item.get("content", ""))
                for item in (history or [])[-4:]
                if isinstance(item, dict)
            )
            previous_normalized = unicodedata.normalize(
                "NFKD", previous_text.casefold()
            )
            previous_normalized = "".join(
                character for character in previous_normalized
                if not unicodedata.combining(character)
            )
            if "analiz" in previous_normalized and any(
                term in previous_normalized for term in ("url", "enlace", "link")
            ):
                return (
                    "Sí. Envíame la URL y la analizaré; te entregaré la clasificación, "
                    "la probabilidad de phishing y los factores SHAP que más influyeron."
                )

        analysis_request_terms = ("analiza", "analizar", "revisa", "evaluar", "evalua")
        if any(term in words for term in analysis_request_terms):
            return (
                "Necesito una URL válida para ejecutar el clasificador. Puedes escribirla "
                "con o sin protocolo, por ejemplo: «Analiza https://ejemplo.com» o "
                "«Analiza ejemplo.com»."
            )

        storage_disabled_phrases = (
            "desactivo el almacenamiento",
            "desactivar el almacenamiento",
            "almacenamiento desactivado",
            "sin almacenamiento",
        )
        if any(phrase in normalized for phrase in storage_disabled_phrases):
            return (
                "Con el almacenamiento desactivado, el análisis y su explicación SHAP "
                "solo permanecen en la memoria temporal de la conversación; no se guardan "
                "en PostgreSQL ni aparecen en el historial global."
            )

        capability_phrases = (
            "que puedes hacer",
            "que sabes hacer",
            "que sabes",
            "en que ayudas",
            "sobre que puedo preguntar",
            "que te puedo preguntar",
            "cual es tu funcion",
            "cuales son tus capacidades",
        )
        if any(phrase in normalized for phrase in capability_phrases):
            return (
                "Puedo analizar una URL con el clasificador, indicar su probabilidad "
                "de phishing y explicar con SHAP qué características influyeron. "
                "También puedo definir esos indicadores, responder preguntas sobre "
                "phishing y prevención, recordar el último análisis de la conversación "
                "y orientarte sobre el uso, privacidad e historial de LinkShield AI."
            )

        knowledge_terms = {
            "phishing", "url", "link", "enlace", "app", "linkshield",
            "riesgo", "analisis", "seguro", "sospechoso", "historial",
            "ciberseguridad", "contrasena", "password", "malware", "qr",
            "smishing", "vishing", "spoofing", "fraude", "estafa",
        }
        if words & knowledge_terms:
            return None

        if words & greetings and len(words) <= 6:
            return (
                "¡Hola! Soy Anita, la asistente de ciberseguridad de LinkShield AI. "
                "Puedes preguntarme sobre "
                "phishing, enlaces sospechosos o cómo usar la app."
            )

        if words & farewells and len(words) <= 8:
            return (
                "¡Hasta luego! Recuerda verificar los enlaces sospechosos "
                "antes de abrirlos."
            )

        if words & thanks and len(words) <= 8:
            return (
                "¡De nada! Estoy aquí para ayudarte a reconocer enlaces "
                "sospechosos y usar LinkShield AI con mayor seguridad."
            )

        return None

    def _brief_answer(self, answer):
        answer = answer.replace("**", "").strip()
        if re.search(r"(?:^|\n)\s*\d+[.)]\s+", answer):
            words = answer.split()
            return (
                answer if len(words) <= 140
                else " ".join(words[:140]).rstrip(".,;:") + "…"
            )

        sentences = re.split(r"(?<=[.!?])\s+", answer)
        brief = " ".join(sentences[:2]).strip()
        words = brief.split()
        if len(words) > 70:
            brief = " ".join(words[:70]).rstrip(".,;:") + "…"
        return brief

    def _available_models(self):
        try:
            response = requests.get(
                f"{self.ollama_url}/api/tags",
                timeout=5,
            )
            response.raise_for_status()
            return [
                item.get("name", "")
                for item in response.json().get("models", [])
                if item.get("name")
            ]
        except requests.RequestException as error:
            raise OllamaUnavailableError(
                "Ollama no esta disponible. Abre Ollama y vuelve a intentarlo."
            ) from error

    def _select_model(self):
        models = self._available_models()
        if not models:
            raise OllamaUnavailableError(
                "Ollama esta activo, pero no tiene un modelo de chat instalado."
            )

        if self.configured_model:
            matching = [
                model for model in models
                if model == self.configured_model
                or model.split(":")[0] == self.configured_model
            ]
            if not matching:
                raise OllamaUnavailableError(
                    f"El modelo configurado '{self.configured_model}' no esta instalado."
                )
            return matching[0]

        preferred_terms = ("qwen", "llama", "gemma", "mistral", "phi")
        for term in preferred_terms:
            for model in models:
                if term in model.lower() and "embed" not in model.lower():
                    return model

        non_embedding = [
            model for model in models if "embed" not in model.lower()
        ]
        return non_embedding[0] if non_embedding else models[0]

    def answer(self, question, history=None):
        social_response = self._social_response(question, history=history)
        if social_response:
            return {
                "answer": social_response,
                "sources": [],
                "model": None,
            }

        matches = self._retrieve(question)
        if not matches or matches[0]["score"] < 0.06:
            return {
                "answer": (
                    "No tengo información sobre ese tema. Puedes preguntarme "
                    "sobre LinkShield AI, phishing, enlaces, privacidad, "
                    "prevención, respuesta ante incidentes y conceptos "
                    "relacionados de ciberseguridad."
                ),
                "sources": [],
                "model": None,
            }

        model = self._select_model()
        context = "\n\n---\n\n".join(match["text"] for match in matches)
        safe_history = [
            {"role": item["role"], "content": item["content"]}
            for item in (history or [])[-10:]
            if item.get("role") in {"user", "assistant"}
            and isinstance(item.get("content"), str)
        ]
        system_prompt = (
            "Eres el asistente de ciberseguridad de LinkShield AI. "
            "Tu nombre es Anita. Mantén una personalidad "
            "cordial, profesional, tranquila y cercana. "
            "Responde en español claro, breve y útil. Usa como máximo dos "
            "frases y 60 palabras; si explicas pasos, usa hasta cuatro puntos. "
            "Usa exclusivamente el "
            "CONTEXTO proporcionado. No inventes datos ni uses conocimientos "
            "externos. Si el contexto no permite responder, explica brevemente "
            "que solo puedes ayudar sobre phishing, enlaces y LinkShield AI. "
            "No afirmes que un enlace es seguro "
            "sin analizarlo con la aplicacion. Conserva exactamente los nombres "
            "de botones y pantallas escritos en mayusculas en el contexto."
        )

        try:
            response = requests.post(
                f"{self.ollama_url}/api/chat",
                json={
                    "model": model,
                    "stream": False,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        *safe_history,
                        {
                            "role": "user",
                            "content": (
                                f"CONTEXTO:\n{context}\n\n"
                                f"PREGUNTA:\n{question}"
                            ),
                        },
                    ],
                    "options": {"temperature": 0.15, "num_predict": 180},
                },
                timeout=120,
            )
            response.raise_for_status()
            answer = response.json().get("message", {}).get("content", "").strip()
        except requests.RequestException as error:
            raise OllamaUnavailableError(
                "Ollama no pudo generar la respuesta. Revisa que siga activo."
            ) from error

        if not answer:
            raise OllamaUnavailableError("Ollama devolvio una respuesta vacia.")

        answer = self._brief_answer(answer)

        sources = list(dict.fromkeys(match["title"] for match in matches))
        return {"answer": answer, "sources": sources, "model": model}

    def answer_with_analysis(
        self,
        question,
        *,
        analysis,
        decision,
        history=None,
        follow_up=False,
    ):
        matches = self._retrieve(
            f"{question} phishing URL indicadores riesgo prevención análisis"
        )
        model = self._select_model()
        knowledge = "\n\n---\n\n".join(match["text"] for match in matches)
        indicators = analysis.get("indicators", {})
        shap_explanation = analysis.get("shap_explanation", {})
        relevant_names = (
            "phish_hints",
            "ip",
            "nb_hyphens",
            "nb_dots",
            "ratio_digits_url",
            "ratio_extRedirection",
            "domain_age",
            "google_index",
        )
        relevant_indicators = {
            name: indicators[name]
            for name in relevant_names
            if name in indicators
        }
        technical_context = {
            "url": analysis.get("url"),
            "technical_classification": analysis.get("classification"),
            "phishing_probability": round(
                float(analysis.get("probability", 0.0)), 6
            ),
            "technical_indicators": relevant_indicators,
            "shap_explanation": {
                "method": shap_explanation.get("method"),
                "base_probability": shap_explanation.get("base_probability"),
                "top_factors": shap_explanation.get("top_factors", [])[:8],
                "supporting_phishing": shap_explanation.get(
                    "supporting_phishing", []
                )[:5],
                "supporting_legitimate": shap_explanation.get(
                    "supporting_legitimate", []
                )[:5],
            },
            "conversational_risk": decision.get("risk_level"),
            "recommended_action": decision.get("action"),
        }
        safe_history = [
            {"role": item["role"], "content": item["content"]}
            for item in (history or [])[-10:]
            if item.get("role") in {"user", "assistant"}
            and isinstance(item.get("content"), str)
        ]
        system_prompt = (
            "Eres el Agente de Conocimiento y Explicabilidad de LinkShield AI. "
            "Redacta únicamente una recomendación preventiva, clara y profesional, "
            "coherente con el nivel de riesgo y la acción indicada. No menciones la "
            "URL, clasificación, probabilidad, SHAP, factores técnicos ni números; "
            "esos datos serán incorporados por un renderizador verificable. No "
            "inventes hechos sobre el sitio. Escribe una sola frase de hasta 25 palabras, "
            "sin listas, títulos ni saltos de línea."
        )
        user_prompt = (
            f"TIPO: {'consulta posterior' if follow_up else 'nuevo análisis'}\n"
            f"RESULTADO TECNICO:\n{json.dumps(technical_context, ensure_ascii=False, default=str)}\n\n"
            f"CONOCIMIENTO AUTORIZADO:\n{knowledge}\n\n"
            f"SOLICITUD DEL USUARIO:\n{question}"
        )

        try:
            response = requests.post(
                f"{self.ollama_url}/api/chat",
                json={
                    "model": model,
                    "stream": False,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        *safe_history,
                        {"role": "user", "content": user_prompt},
                    ],
                    "options": {"temperature": 0.1, "num_predict": 240},
                },
                timeout=120,
            )
            response.raise_for_status()
            answer = response.json().get("message", {}).get("content", "").strip()
        except requests.RequestException as error:
            raise OllamaUnavailableError(
                "Ollama no pudo explicar el resultado del análisis."
            ) from error

        if not answer:
            raise OllamaUnavailableError("Ollama devolvio una respuesta vacia.")

        answer = re.sub(r"\s+", " ", answer).strip()
        answer = self._brief_answer(answer)
        top_factor_names = [
            str(item.get("display_name", "")).casefold()
            for item in shap_explanation.get("top_factors", [])[:3]
            if item.get("display_name")
        ]
        if any(name in answer.casefold() for name in top_factor_names):
            raise OllamaUnavailableError(
                "Ollama intentó modificar la explicación técnica."
            )
        forbidden_terms = ("probabilidad", "shap", "factor", "clasific", "url")
        if any(term in answer.casefold() for term in forbidden_terms):
            raise OllamaUnavailableError("Ollama incluyó contenido técnico reservado.")
        if any(character.isdigit() for character in answer) or len(answer.split()) > 25:
            raise OllamaUnavailableError("Ollama devolvio una recomendación no válida.")

        return {
            "answer": answer,
            "sources": [
                *list(dict.fromkeys(match["title"] for match in matches)),
            ],
            "model": model,
            "generation_mode": "rag_ollama",
        }

    def health(self):
        try:
            self._ensure_index()
            models = self._available_models()
            selected_model = self._select_model() if models else None
            return {
                "status": "ok",
                "knowledge_file": self.knowledge_path.name,
                "knowledge_chunks": len(self._chunks),
                "ollama_available": True,
                "models": models,
                "selected_model": selected_model,
            }
        except OllamaUnavailableError as error:
            return {
                "status": "degraded",
                "knowledge_file": self.knowledge_path.name,
                "knowledge_chunks": len(self._chunks),
                "ollama_available": False,
                "error": str(error),
            }
        except Exception as error:
            return {"status": "error", "error": str(error)}


rag_service = RagService()
