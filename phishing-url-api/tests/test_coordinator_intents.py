import pytest

from multiagent.agents.coordinator import CoordinatorAgent
from multiagent.contracts import Intent


@pytest.mark.parametrize(
    "question",
    [
        "¿Por qué llegaste a esa conclusión?",
        "¿Qué característica influyó más?",
        "Explícame el resultado de manera sencilla",
        "¿Qué significa la probabilidad?",
        "¿Qué factores aumentaron y cuáles redujeron el riesgo?",
        "¿Cuál fue la URL analizada?",
        "¿Y la de menor influencia?",
    ],
)
def test_explainability_questions_recall_previous_analysis(question):
    intent = CoordinatorAgent().identify_intent(
        question,
        has_previous_analysis=True,
    )

    assert intent == Intent.ANALYSIS_FOLLOW_UP


def test_general_process_question_does_not_repeat_previous_analysis():
    intent = CoordinatorAgent().identify_intent(
        "¿Cuál es el proceso completo?",
        has_previous_analysis=True,
    )

    assert intent == Intent.GENERAL_QUERY
