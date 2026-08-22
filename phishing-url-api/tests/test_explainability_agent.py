from multiagent.agents.explainability import ExplainabilityAgent
from multiagent.contracts import AnalysisResult, DecisionResult


def test_grounded_shap_explanation_preserves_factor_directions():
    analysis = AnalysisResult(
        interaction_id="interaction-1",
        url="https://example.com",
        classification="no-phishing",
        probability=0.44,
        indicators={},
        analyzed_at="2026-08-11T00:00:00+00:00",
        shap_explanation={
            "base_probability": 0.5,
            "top_factors": [
                {
                    "display_name": "Antigüedad del dominio",
                    "shap_value": -0.16,
                },
                {
                    "display_name": "Cantidad de enlaces",
                    "shap_value": 0.08,
                },
            ],
        },
    )
    decision = DecisionResult(
        risk_level="moderate",
        action="recommend_caution",
        utility_scores={},
        rationale="test",
    )

    result = ExplainabilityAgent._grounded_explanation(
        analysis,
        decision,
        follow_up=False,
        generation_mode="test",
    )

    assert "Antigüedad del dominio redujo 16.0 puntos" in result["answer"]
    assert "Cantidad de enlaces aumentó 8.0 puntos" in result["answer"]
    assert result["answer"].startswith("El modelo")


def make_detailed_analysis():
    return AnalysisResult(
        interaction_id="interaction-2",
        url="https://example.com",
        classification="no-phishing",
        probability=0.153,
        indicators={},
        analyzed_at="2026-08-11T00:00:00+00:00",
        shap_explanation={
            "available": True,
            "base_probability": 0.5,
            "top_factors": [
                {
                    "feature": "google_index",
                    "display_name": "Presencia en buscadores",
                    "raw_value": 1,
                    "shap_value": -0.151,
                },
                {
                    "feature": "domain_age",
                    "display_name": "Antigüedad del dominio",
                    "raw_value": 2500,
                    "shap_value": -0.122,
                },
                {
                    "feature": "nb_hyperlinks",
                    "display_name": "Cantidad de enlaces",
                    "raw_value": 20,
                    "shap_value": 0.089,
                },
            ],
            "all_contributions": [
                {
                    "feature": "google_index",
                    "display_name": "Presencia en buscadores",
                    "raw_value": 1,
                    "shap_value": -0.151,
                },
                {
                    "feature": "domain_age",
                    "display_name": "Antigüedad del dominio",
                    "raw_value": 2500,
                    "shap_value": -0.122,
                },
                {
                    "feature": "nb_hyperlinks",
                    "display_name": "Cantidad de enlaces",
                    "raw_value": 20,
                    "shap_value": 0.089,
                },
            ],
        },
    )


def make_hybrid_analysis():
    original = make_detailed_analysis()
    return AnalysisResult(
        **{
            **original.to_dict(),
            "classification": "phishing",
            "probability": 0.78,
            "shap_explanation": {
                "available": True,
                "method": "ExactBranchShapley",
                "base_probability": 0.5,
                "top_factors": [
                    {
                        "feature": "mlp_regularized",
                        "display_name": "MLP regularizada",
                        "shap_value": 0.188,
                    },
                    {
                        "feature": "random_forest",
                        "display_name": "Random Forest Top 25",
                        "shap_value": 0.156,
                    },
                ],
                "all_contributions": [
                    {
                        "feature": "mlp_regularized",
                        "display_name": "MLP regularizada",
                        "shap_value": 0.188,
                    },
                    {
                        "feature": "random_forest",
                        "display_name": "Random Forest Top 25",
                        "shap_value": 0.156,
                    },
                ],
                "feature_factors": [
                    {
                        "feature": "google_index",
                        "display_name": "Presencia en buscadores",
                        "raw_value": 0,
                        "shap_value": 0.113,
                    },
                    {
                        "feature": "phish_hints",
                        "display_name": "Palabras asociadas a phishing",
                        "raw_value": 2,
                        "shap_value": 0.054,
                    },
                    {
                        "feature": "domain_age",
                        "display_name": "Antiguedad del dominio",
                        "raw_value": 0,
                        "shap_value": 0.021,
                    },
                ],
                "all_feature_contributions": [
                    {
                        "feature": "google_index",
                        "display_name": "Presencia en buscadores",
                        "raw_value": 0,
                        "shap_value": 0.113,
                    },
                    {
                        "feature": "phish_hints",
                        "display_name": "Palabras asociadas a phishing",
                        "raw_value": 2,
                        "shap_value": 0.054,
                    },
                    {
                        "feature": "domain_age",
                        "display_name": "Antiguedad del dominio",
                        "raw_value": 0,
                        "shap_value": 0.002,
                    },
                ],
            },
        }
    )


def test_hybrid_top_influence_uses_url_feature_instead_of_model_branch():
    result = ExplainabilityAgent._targeted_shap_answer(
        "Que caracteristica influyo mas?",
        make_hybrid_analysis(),
    )

    assert result["generation_mode"] == "shap_top_factor"
    assert "Presencia en buscadores" in result["answer"]
    assert "MLP regularizada" not in result["answer"]


def test_hybrid_least_influence_uses_all_url_features():
    result = ExplainabilityAgent._targeted_shap_answer(
        "Y cual fue la de menor influencia?",
        make_hybrid_analysis(),
    )

    assert result["generation_mode"] == "shap_least_factor"
    assert "dominio" in result["answer"].casefold()
    assert "Random Forest" not in result["answer"]


def test_explains_requested_feature_with_value_and_shap_effect():
    result = ExplainabilityAgent._targeted_shap_answer(
        "¿A qué se refiere presencia en buscadores?",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "shap_feature_definition"
    assert "consulta de tipo site:" in result["answer"]
    assert "valor 1" in result["answer"]
    assert "15.1 puntos" in result["answer"]
    assert "redujo" in result["answer"]


def test_explains_points_as_percentage_point_contributions():
    result = ExplainabilityAgent._targeted_shap_answer(
        "¿A qué te refieres con los puntos?",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "shap_points_definition"
    assert "puntos porcentuales" in result["answer"]
    assert "base de 50.0%" in result["answer"]
    assert "restó 15.1" in result["answer"]
    assert "probabilidad final de 15.3%" in result["answer"]


def test_new_google_url_analysis_keeps_probability_and_shap_summary():
    class FakeRagService:
        def answer_with_analysis(self, *args, **kwargs):
            return {
                "answer": "Verifica siempre el dominio antes de continuar.",
                "model": "fake",
                "sources": [],
            }

    decision = DecisionResult(
        risk_level="reduced",
        action="allow_with_caution",
        utility_scores={},
        rationale="test",
    )
    result = ExplainabilityAgent(FakeRagService()).explain_analysis(
        "Analiza la URL: https://www.google.com/",
        make_detailed_analysis(),
        decision,
        [],
        follow_up=False,
    )

    assert result["generation_mode"] == "shap_grounded_rag_ollama"
    assert "15.3% de probabilidad de phishing" in result["answer"]
    assert "SHAP" in result["answer"]
    assert "Presencia en buscadores" in result["answer"]


def test_follow_up_explains_reason_without_repeating_full_result():
    result = ExplainabilityAgent._targeted_shap_answer(
        "¿Por qué llegaste a esa conclusión?",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "shap_reasoning_summary"
    assert "combinar las 25 características" in result["answer"]
    assert "empujó el riesgo" in result["answer"]
    assert "15.3% de probabilidad" not in result["answer"]


def test_follow_up_details_only_the_most_influential_feature():
    result = ExplainabilityAgent._targeted_shap_answer(
        "¿Qué característica influyó más?",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "shap_top_factor"
    assert "Presencia en buscadores" in result["answer"]
    assert "15.1 puntos" in result["answer"]
    assert "no determina el resultado por sí sola" in result["answer"].casefold()


def test_follow_up_calculates_least_influential_feature_from_all_factors():
    result = ExplainabilityAgent._targeted_shap_answer(
        "¿Y la de menor influencia?",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "shap_least_factor"
    assert "Cantidad de enlaces" in result["answer"]
    assert "8.9 puntos" in result["answer"]
    assert "Antigüedad del dominio" not in result["answer"]


def test_follow_up_translates_result_to_simple_language():
    result = ExplainabilityAgent._targeted_shap_answer(
        "Explícame el resultado de manera sencilla",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "shap_simple_explanation"
    assert "aproximadamente 15 de cada 100" in result["answer"]
    assert "no es una certeza absoluta" in result["answer"]


def test_follow_up_explains_probability_and_complement():
    result = ExplainabilityAgent._targeted_shap_answer(
        "¿Qué significa la probabilidad?",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "shap_probability_explanation"
    assert "15.3%" in result["answer"]
    assert "84.7%" in result["answer"]
    assert "referencia de 50.0%" in result["answer"]


def test_follow_up_separates_increasing_and_reducing_factors():
    result = ExplainabilityAgent._targeted_shap_answer(
        "¿Qué factores aumentaron y cuáles redujeron el riesgo?",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "shap_direction_summary"
    assert "Aumentaron el riesgo" in result["answer"]
    assert "Redujeron el riesgo" in result["answer"]
    assert "Cantidad de enlaces" in result["answer"]
    assert "Antigüedad del dominio" in result["answer"]


def test_follow_up_understands_singular_direction_question():
    result = ExplainabilityAgent._targeted_shap_answer(
        "¿Qué aumentó y qué redujo el riesgo?",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "shap_direction_summary"
    assert "Aumentaron el riesgo" in result["answer"]
    assert "Redujeron el riesgo" in result["answer"]


def test_follow_up_gives_direct_action_for_phishing_result():
    original = make_detailed_analysis()
    analysis = AnalysisResult(
        **{
            **original.to_dict(),
            "classification": "phishing",
            "probability": 0.78,
        }
    )
    decision = DecisionResult(
        risk_level="high",
        action="priority_warning",
        utility_scores={},
        rationale="test",
    )

    result = ExplainabilityAgent._targeted_shap_answer(
        "¿Qué debería hacer con ese enlace?",
        analysis,
        decision,
    )

    assert result["generation_mode"] == "shap_action_recommendation"
    assert "78.0%" in result["answer"]
    assert "No abras el enlace" in result["answer"]
    assert "autenticación multifactor" in result["answer"]


def test_follow_up_safety_verdict_does_not_claim_absolute_safety():
    result = ExplainabilityAgent._targeted_shap_answer(
        "¿Entonces es seguro?",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "shap_safety_verdict"
    assert "15.3%" in result["answer"]
    assert "no garantiza que sea segura" in result["answer"]


def test_follow_up_recalls_analyzed_url():
    result = ExplainabilityAgent._targeted_shap_answer(
        "¿Cuál fue la URL analizada?",
        make_detailed_analysis(),
    )

    assert result["generation_mode"] == "analysis_url_recall"
    assert "https://example.com" in result["answer"]


def test_general_feature_definition_uses_authoritative_dictionary():
    result = ExplainabilityAgent._technical_definition(
        "¿Qué significa presencia en buscadores?"
    )

    assert result["generation_mode"] == "feature_knowledge_definition"
    assert "consulta de tipo site:" in result["answer"]
    assert "no demuestra" in result["answer"]
    assert result["model"] is None


def test_general_shap_definition_explains_direction_without_causality():
    result = ExplainabilityAgent._technical_definition(
        "¿Qué es SHAP y para qué sirve?"
    )

    assert result["generation_mode"] == "shap_knowledge_definition"
    assert "valor positivo aumenta" in result["answer"]
    assert "no demuestra causalidad" in result["answer"]


def test_general_feature_definition_ignores_connector_variations():
    result = ExplainabilityAgent._technical_definition(
        "¿Qué significa la proporción de números en una URL?"
    )

    assert result["generation_mode"] == "feature_knowledge_definition"
    assert result["answer"].startswith("Proporción de números en la URL")
    assert "no demuestra" in result["answer"]
