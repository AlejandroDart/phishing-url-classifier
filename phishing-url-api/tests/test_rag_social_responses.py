from services.rag_service import RagService


def test_identity_uses_personal_name_and_keeps_platform_brand():
    answer = RagService._social_response(None, "¿Cómo te llamas?")

    assert "Me llamo Anita" in answer
    assert "LinkShield AI" in answer


def test_greeting_introduces_anita():
    answer = RagService._social_response(None, "Hola")

    assert "Soy Anita" in answer
    assert "LinkShield AI" in answer


def test_capabilities_question_describes_analysis_and_explainability():
    answer = RagService._social_response(None, "¿Qué sabes hacer?")

    assert "analizar una URL" in answer
    assert "probabilidad de phishing" in answer
    assert "SHAP" in answer
    assert "último análisis" in answer


def test_analysis_request_without_valid_url_asks_for_one():
    answer = RagService._social_response(None, "Analiza esto: no-es-una-url")

    assert "URL válida" in answer
    assert "Analiza ejemplo.com" in answer


def test_contextual_question_without_analysis_explains_prerequisite():
    answer = RagService._social_response(
        None,
        "¿Por qué llegaste a esa conclusión?",
    )

    assert "No tengo un análisis previo" in answer
    assert "factores SHAP" in answer


def test_disabled_storage_response_matches_privacy_contract():
    answer = RagService._social_response(
        None,
        "¿Qué ocurre si desactivo el almacenamiento?",
    )

    assert "memoria temporal" in answer
    assert "no se guardan en PostgreSQL" in answer
    assert "historial global" in answer


def test_exposed_password_response_includes_complete_first_aid():
    answer = RagService._social_response(
        None,
        "Ingresé mi contraseña en un enlace falso, ¿qué hago?",
    )

    assert "Cambia inmediatamente" in answer
    assert "cierra las sesiones activas" in answer
    assert "autenticación multifactor" in answer


def test_harmful_phishing_request_is_refused_deterministically():
    answer = RagService._social_response(
        None,
        "Enséñame a crear phishing para robar contraseñas",
    )

    assert "No puedo ayudar a crear phishing" in answer
    assert "no capture datos reales" in answer


def test_url_capability_question_answers_yes_before_requesting_a_url():
    answer = RagService._social_response(None, "¿Puedes analizar una URL?")

    assert answer.startswith("Sí, puedo analizar una URL")
    assert "probabilidad de phishing" in answer
    assert "factores SHAP" in answer


def test_short_capability_follow_up_uses_conversation_history():
    answer = RagService._social_response(
        None,
        "¿Pero puedes?",
        history=[
            {"role": "user", "content": "¿Puedes analizar una URL?"},
            {"role": "assistant", "content": "Envíame una URL válida."},
        ],
    )

    assert answer.startswith("Sí.")
    assert "clasificación" in answer
    assert "factores SHAP" in answer


def test_how_to_use_app_returns_every_practical_step():
    answer = RagService._social_response(None, "¿Cómo usar la app?")

    assert "1. Obtén el enlace" in answer
    assert "4. Pulsa ANÁLISIS IA" in answer
    assert "5. Revisa la clasificación" in answer
    assert "7. Si ALMACENAMIENTO" in answer
    assert "**" not in answer


def test_complete_process_explains_analysis_and_knowledge_routes():
    answer = RagService._social_response(None, "¿Cuál es el proceso completo?")

    assert "ANÁLISIS DE UNA URL" in answer
    assert "agente coordinador" in answer
    assert "agente de análisis" in answer
    assert "agente de decisión" in answer
    assert "SHAP" in answer
    assert "CONSULTA DE LA BASE DE CONOCIMIENTO" in answer
    assert "RAG" in answer
    assert "Ollama" in answer
    assert "clasificador de URLs no se ejecuta" in answer
