from multiagent.contracts import AnalysisResult, ConversationContext, DecisionResult
from multiagent.memory import ShortTermMemory


def make_context(conversation_id="conversation-1"):
    return ConversationContext(
        conversation_id=conversation_id,
        interaction_id="interaction-1",
        analysis=AnalysisResult(
            interaction_id="interaction-1",
            url="https://example.com",
            classification="no-phishing",
            probability=0.1,
            indicators={},
            analyzed_at="2026-08-11T00:00:00+00:00",
        ),
        decision=DecisionResult(
            risk_level="reduced",
            action="inform",
            utility_scores={"inform": 0.9},
            rationale="test",
        ),
    )


def test_stores_and_clears_conversation_context():
    memory = ShortTermMemory()
    context = make_context()

    memory.put(context)
    assert memory.get("conversation-1") == context

    memory.clear("conversation-1")
    assert memory.get("conversation-1") is None


def test_evicts_oldest_conversation_at_capacity():
    memory = ShortTermMemory(max_conversations=1)
    memory.put(make_context("first"))
    memory.put(make_context("second"))

    assert memory.get("first") is None
    assert memory.get("second") is not None
