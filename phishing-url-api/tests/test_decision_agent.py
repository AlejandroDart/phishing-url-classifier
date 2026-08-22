from multiagent.agents.decision import DecisionAgent
from multiagent.contracts import AnalysisResult


def make_analysis(probability, indicators=None):
    return AnalysisResult(
        interaction_id="interaction-1",
        url="https://example.com",
        classification="phishing" if probability >= 0.5 else "no-phishing",
        probability=probability,
        indicators=indicators or {},
        analyzed_at="2026-08-11T00:00:00+00:00",
    )


def test_high_probability_selects_priority_warning():
    decision = DecisionAgent().decide(
        make_analysis(0.91, {"phish_hints": 2, "ip": 1})
    )

    assert decision.risk_level == "high"
    assert decision.action == "priority_warning"


def test_low_probability_selects_inform():
    decision = DecisionAgent().decide(make_analysis(0.08))

    assert decision.risk_level == "reduced"
    assert decision.action == "inform"


def test_mid_probability_selects_caution_without_changing_classification():
    analysis = make_analysis(0.48)
    decision = DecisionAgent().decide(analysis)

    assert decision.risk_level == "moderate"
    assert decision.action == "recommend_caution"
    assert analysis.classification == "no-phishing"
