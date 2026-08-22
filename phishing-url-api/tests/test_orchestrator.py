from multiagent.contracts import AnalysisResult, DecisionResult
from multiagent.memory import ShortTermMemory
from multiagent.orchestrator import MultiAgentOrchestrator


class FakeRepository:
    def __init__(self):
        self.saved = []
        self.latest_calls = []

    def latest_context(self, conversation_id):
        self.latest_calls.append(conversation_id)
        return None

    def save_interaction(self, **data):
        self.saved.append(data)
        return True


class FakeAnalysisAgent:
    name = "analysis_agent"

    def analyze(self, url, interaction_id, store_global=False):
        return AnalysisResult(
            interaction_id=interaction_id,
            url=url,
            classification="phishing",
            probability=0.88,
            indicators={"phish_hints": 2},
            analyzed_at="2026-08-11T00:00:00+00:00",
            stored_global=store_global,
        )


class FakeDecisionAgent:
    name = "decision_agent"

    def decide(self, analysis):
        return DecisionResult(
            risk_level="high",
            action="priority_warning",
            utility_scores={"priority_warning": 0.9},
            rationale="test",
        )


class FakeExplainabilityAgent:
    name = "explainability_agent"

    def answer_general(self, question, history):
        return {"answer": "Respuesta general", "sources": [], "model": "fake"}

    def explain_analysis(
        self, question, analysis, decision, history, follow_up=False
    ):
        prefix = "Seguimiento" if follow_up else "Análisis"
        return {
            "answer": f"{prefix}: {analysis.classification}",
            "sources": ["Resultado del clasificador"],
            "model": "fake",
        }


def make_orchestrator():
    repository = FakeRepository()
    orchestrator = MultiAgentOrchestrator(
        analysis_agent=FakeAnalysisAgent(),
        decision_agent=FakeDecisionAgent(),
        explainability_agent=FakeExplainabilityAgent(),
        memory=ShortTermMemory(),
        repository=repository,
    )
    return orchestrator, repository


def test_url_analysis_activates_three_specialized_agents_and_persists():
    orchestrator, repository = make_orchestrator()

    result = orchestrator.handle(
        "Analiza https://example.com/login",
        conversation_id="conversation-1",
        store_global=True,
    )

    assert result["intent"] == "url_analysis"
    assert result["analysis"]["classification"] == "phishing"
    assert result["decision"]["risk_level"] == "high"
    assert result["agents"] == [
        "analysis_agent",
        "decision_agent",
        "explainability_agent",
    ]
    assert result["persisted"] is True
    assert result["persistence_mode"] == "global_postgresql"
    assert len(repository.saved) == 1


def test_disabled_global_storage_never_uses_persistent_repository():
    orchestrator, repository = make_orchestrator()

    result = orchestrator.handle(
        "Analiza https://example.com/login",
        conversation_id="private-conversation",
        store_global=False,
    )

    assert result["persisted"] is False
    assert result["persistence_mode"] == "short_term_memory_only"
    assert result["analysis"]["stored_global"] is False
    assert repository.saved == []
    assert repository.latest_calls == []


def test_follow_up_recalls_previous_analysis_from_short_term_memory():
    orchestrator, repository = make_orchestrator()
    first = orchestrator.handle(
        "Analiza https://example.com/login",
        conversation_id="conversation-1",
    )

    follow_up = orchestrator.handle(
        "¿Por qué apareció como peligrosa?",
        conversation_id="conversation-1",
    )

    assert follow_up["intent"] == "analysis_follow_up"
    assert follow_up["analysis"]["interaction_id"] == first["interaction_id"]
    assert follow_up["answer"].startswith("Seguimiento")
    assert repository.saved == []
    assert repository.latest_calls == []


def test_general_query_preserves_legacy_response_fields():
    orchestrator, _ = make_orchestrator()

    result = orchestrator.handle(
        "¿Qué es el phishing?",
        conversation_id="conversation-1",
    )

    assert result["answer"] == "Respuesta general"
    assert result["sources"] == []
    assert result["model"] == "fake"
    assert result["intent"] == "general_query"


def test_anita_returns_structured_sensitivity_action():
    orchestrator, _ = make_orchestrator()

    result = orchestrator.handle(
        "Anita, quiero el modo agresivo",
        conversation_id="configuration-conversation",
        sensitivity_profile="balanced",
    )

    assert result["intent"] == "sensitivity_change"
    assert result["action"] == {
        "type": "set_sensitivity",
        "value": "aggressive",
    }
    assert result["agents"] == ["coordinator_agent"]


def test_anita_reports_current_sensitivity_profile():
    orchestrator, _ = make_orchestrator()

    result = orchestrator.handle(
        "Que perfil de sensibilidad estoy usando?",
        conversation_id="configuration-conversation",
        sensitivity_profile="passive",
    )

    assert result["intent"] == "sensitivity_query"
    assert "Pasivo" in result["answer"]


def test_anita_returns_structured_storage_action():
    orchestrator, _ = make_orchestrator()

    result = orchestrator.handle(
        "Anita, desactiva el almacenamiento global",
        conversation_id="storage-conversation",
        store_global=True,
    )

    assert result["intent"] == "storage_change"
    assert result["action"] == {
        "type": "set_global_storage",
        "value": False,
    }
    assert result["agents"] == ["coordinator_agent"]


def test_anita_reports_current_storage_state():
    orchestrator, _ = make_orchestrator()

    result = orchestrator.handle(
        "Esta activo el almacenamiento global?",
        conversation_id="storage-conversation",
        store_global=False,
    )

    assert result["intent"] == "storage_query"
    assert "desactivado" in result["answer"]


def test_anita_does_not_treat_storage_state_question_as_activation():
    orchestrator, _ = make_orchestrator()

    result = orchestrator.handle(
        "El almacenamiento global esta activado?",
        conversation_id="storage-conversation",
        store_global=False,
    )

    assert result["intent"] == "storage_query"
    assert result.get("action") is None
    assert "desactivado" in result["answer"]


def test_anita_understands_contextual_disable_imperative():
    orchestrator, _ = make_orchestrator()

    result = orchestrator.handle(
        "Desactivalo",
        conversation_id="storage-conversation",
        store_global=True,
        history=[
            {"role": "assistant", "content": "Active el almacenamiento global."},
        ],
    )

    assert result["intent"] == "storage_change"
    assert result["action"] == {
        "type": "set_global_storage",
        "value": False,
    }
