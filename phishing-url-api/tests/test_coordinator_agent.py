from multiagent.agents.coordinator import CoordinatorAgent
from multiagent.contracts import Intent


def test_routes_message_with_url_to_analysis():
    agent = CoordinatorAgent()

    assert agent.extract_url("Analiza https://example.com/login") == (
        "https://example.com/login"
    )
    assert agent.identify_intent("Analiza https://example.com/login", False) == (
        Intent.URL_ANALYSIS
    )


def test_normalizes_www_url():
    agent = CoordinatorAgent()

    assert agent.extract_url("revisa www.example.com/path.") == (
        "https://www.example.com/path"
    )


def test_extracts_bare_domain_without_scheme_or_www():
    agent = CoordinatorAgent()

    assert agent.extract_url("Analiza google.com") == "https://google.com"


def test_does_not_treat_invalid_hyphenated_text_as_domain():
    agent = CoordinatorAgent()

    assert agent.extract_url("Analiza esto: no-es-una-url") is None


def test_follow_up_requires_previous_analysis():
    agent = CoordinatorAgent()
    question = "¿Por qué apareció como peligrosa?"

    assert agent.identify_intent(question, True) == Intent.ANALYSIS_FOLLOW_UP
    assert agent.identify_intent(question, False) == Intent.GENERAL_QUERY


def test_shap_feature_and_points_questions_are_follow_ups():
    agent = CoordinatorAgent()

    assert agent.identify_intent(
        "¿A qué se refiere presencia en buscadores?", True
    ) == Intent.ANALYSIS_FOLLOW_UP


def test_routes_explicit_sensitivity_changes_and_queries():
    agent = CoordinatorAgent()

    assert agent.identify_intent(
        "Anita, quiero el modo agresivo", False
    ) == Intent.SENSITIVITY_CHANGE
    assert agent.requested_sensitivity_profile(
        "Cambia el umbral al 25%"
    ) == "aggressive"
    assert agent.identify_intent(
        "Que perfil de sensibilidad estoy usando?", False
    ) == Intent.SENSITIVITY_QUERY


def test_routes_storage_changes_queries_and_contextual_follow_up():
    agent = CoordinatorAgent()

    assert agent.identify_intent(
        "Desactiva el almacenamiento global", False
    ) == Intent.STORAGE_CHANGE
    assert agent.requested_storage_state(
        "Puedes desactivarlo tu?",
        [{"role": "assistant", "content": "El almacenamiento global esta activo."}],
    ) is False
    assert agent.identify_intent(
        "Puedes desactivarlo tu?",
        False,
        [{"role": "assistant", "content": "El almacenamiento global esta activo."}],
    ) == Intent.STORAGE_CHANGE
    assert agent.identify_intent(
        "Esta activo el almacenamiento global?", False
    ) == Intent.STORAGE_QUERY
    assert agent.identify_intent(
        "El almacenamiento global esta activado?", False
    ) == Intent.STORAGE_QUERY
    assert agent.requested_storage_state(
        "Desactivalo",
        [{"role": "assistant", "content": "Active el almacenamiento global."}],
    ) is False
    assert agent.identify_intent(
        "Desactivalo",
        False,
        [{"role": "assistant", "content": "Active el almacenamiento global."}],
    ) == Intent.STORAGE_CHANGE


def test_applied_threshold_question_remains_analysis_follow_up():
    agent = CoordinatorAgent()

    assert agent.identify_intent(
        "Que umbral aplicado tuvo ese analisis?", True
    ) == Intent.ANALYSIS_FOLLOW_UP
    assert agent.identify_intent(
        "¿A qué te refieres con los puntos?", True
    ) == Intent.ANALYSIS_FOLLOW_UP


def test_general_cybersecurity_question_is_not_confused_with_safety_follow_up():
    agent = CoordinatorAgent()

    assert agent.identify_intent(
        "¿Qué es ciberseguridad?", True
    ) == Intent.GENERAL_QUERY
    assert agent.identify_intent(
        "¿Entonces es seguro?", True
    ) == Intent.ANALYSIS_FOLLOW_UP
