import pytest
import requests

from services.rag_service import OllamaUnavailableError, RagService


@pytest.mark.parametrize("model_available", [False, True])
def test_relevant_knowledge_is_available_without_ollama(monkeypatch, model_available):
    service = RagService()

    def unavailable(*args, **kwargs):
        raise requests.ConnectionError()

    def select_model():
        if model_available:
            return "mock-model"
        raise OllamaUnavailableError("unavailable")

    monkeypatch.setattr(service, "_select_model", select_model)
    monkeypatch.setattr(requests, "post", unavailable)
    result = service.answer("¿Qué es el smishing?")

    assert result["generation_mode"] == "knowledge_excerpt"
    assert result["model"] is None
    assert "SMS" in result["answer"]
    assert result["sources"] == ["Tipos de phishing y suplantacion"]
