import os

from flask import Blueprint, jsonify, request

from multiagent.orchestrator import multiagent_enabled, multiagent_orchestrator
from services.rag_service import OllamaUnavailableError, rag_service


chatbot_bp = Blueprint("chatbot", __name__)
API_KEY = os.getenv("API_KEY")
MAX_QUESTION_LENGTH = 1000
MAX_HISTORY_MESSAGES = 10


def verificar_api_key():
    api_key = request.headers.get("X-API-KEY")
    return bool(API_KEY) and api_key == API_KEY


@chatbot_bp.route("/chat", methods=["POST"])
def chat():
    if not verificar_api_key():
        return jsonify({"error": "Acceso no autorizado"}), 403

    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Body JSON invalido"}), 400

    question = data.get("question")
    if not isinstance(question, str) or not question.strip():
        return jsonify({"error": "Debes enviar una pregunta"}), 400

    question = question.strip()
    if len(question) > MAX_QUESTION_LENGTH:
        return jsonify({
            "error": f"La pregunta no puede superar {MAX_QUESTION_LENGTH} caracteres"
        }), 400

    raw_history = data.get("history", [])
    if not isinstance(raw_history, list):
        return jsonify({"error": "history debe ser una lista"}), 400

    history = []
    for item in raw_history[-MAX_HISTORY_MESSAGES:]:
        if not isinstance(item, dict):
            continue
        role = item.get("role")
        content = item.get("content")
        if role not in {"user", "assistant"} or not isinstance(content, str):
            continue
        content = content.strip()[:MAX_QUESTION_LENGTH]
        if content:
            history.append({"role": role, "content": content})

    conversation_id = data.get("conversation_id")
    if conversation_id is not None:
        if not isinstance(conversation_id, str) or not conversation_id.strip():
            return jsonify({"error": "conversation_id debe ser texto no vacio"}), 400
        conversation_id = conversation_id.strip()
        if len(conversation_id) > 128:
            return jsonify({"error": "conversation_id no puede superar 128 caracteres"}), 400

    store_global = data.get("store_global", False)
    if not isinstance(store_global, bool):
        return jsonify({"error": "store_global debe ser un valor booleano"}), 400

    model_id = data.get("model_id")
    if model_id is not None and not isinstance(model_id, str):
        return jsonify({"error": "model_id debe ser texto"}), 400

    sensitivity_profile = data.get("sensitivity_profile")

    try:
        if multiagent_enabled():
            result = multiagent_orchestrator.handle(
                question,
                history=history,
                conversation_id=conversation_id,
                store_global=store_global,
                model_id=model_id,
                sensitivity_profile=sensitivity_profile,
            )
        else:
            result = rag_service.answer(question, history=history)
        return jsonify(result)
    except ValueError as error:
        return jsonify({"error": str(error)}), 400
    except OllamaUnavailableError as error:
        return jsonify({"error": str(error)}), 503
    except Exception as error:
        return jsonify({"error": f"No fue posible responder: {error}"}), 500


@chatbot_bp.route("/chat/health", methods=["GET"])
def chat_health():
    if not verificar_api_key():
        return jsonify({"error": "Acceso no autorizado"}), 403

    health = rag_service.health()
    health.update({
        "multiagent_enabled": multiagent_enabled(),
        "agents": [
            "coordinator_agent",
            "analysis_agent",
            "decision_agent",
            "explainability_agent",
        ],
        "communication": "synchronous_structured_events",
        "short_term_memory": "enabled",
        "persistent_memory": "best_effort_postgresql",
    })
    return jsonify(health)
