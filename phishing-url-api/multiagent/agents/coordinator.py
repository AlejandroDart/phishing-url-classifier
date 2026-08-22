import re
import unicodedata
from urllib.parse import urlparse

from multiagent.contracts import Intent
from services.feature_knowledge import FEATURE_KNOWLEDGE


EXPLICIT_URL_PATTERN = re.compile(
    r"(?P<url>(?:https?://|www\.)[^\s<>\[\]{}\"']+)",
    re.IGNORECASE,
)
BARE_DOMAIN_PATTERN = re.compile(
    r"(?<![@\w.-])(?P<url>(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+"
    r"[a-z]{2,63}(?::\d{1,5})?(?:/[^\s<>\[\]{}\"']*)?)",
    re.IGNORECASE,
)
FOLLOW_UP_TERMS = (
    "por que",
    "explica",
    "que significa",
    "a que se refiere",
    "resultado",
    "peligros",
    "es seguro",
    "es segura",
    "que tan seguro",
    "que tan segura",
    "seguridad de esa url",
    "seguridad del enlace",
    "riesgo",
    "probabilidad",
    "punto",
    "shap",
    "influy",
    "influenc",
    "caracteristica",
    "variable",
    "valor",
    "base",
    "indicador",
    "anterior",
    "ese enlace",
    "esa url",
    "url analizada",
    "url analiz",
    "cual fue la url",
    "umbral aplicado",
    "perfil aplicado",
    "por que supero el umbral",
)


def _normalize_text(value: str) -> str:
    decomposed = unicodedata.normalize("NFKD", value.casefold())
    return "".join(
        character
        for character in decomposed
        if not unicodedata.combining(character)
    )


FEATURE_FOLLOW_UP_TERMS = tuple({
    _normalize_text(term)
    for feature, knowledge in FEATURE_KNOWLEDGE.items()
    for term in (feature, knowledge["label"], *knowledge.get("aliases", ()))
})


class CoordinatorAgent:
    name = "coordinator_agent"

    @staticmethod
    def requested_sensitivity_profile(message: str) -> str | None:
        normalized = _normalize_text(message)
        percentage_match = re.search(r"\b(25|50|75)\s*%", normalized)
        if "umbral" in normalized and percentage_match:
            return {
                "25": "aggressive",
                "50": "balanced",
                "75": "passive",
            }[percentage_match.group(1)]
        profile_terms = {
            "aggressive": (
                "agresivo", "agresiva", "mas sensible", "maxima sensibilidad",
                "detectar mas", "mas estricto",
            ),
            "balanced": (
                "equilibrado", "equilibrada", "balanceado", "balanceada",
                "modo normal", "nivel normal",
            ),
            "passive": (
                "pasivo", "pasiva", "menos sensible", "menos alertas",
                "menos falsas alarmas", "conservador", "conservadora",
                "no quiero tantas alertas", "evita tantas alertas",
            ),
        }
        for profile, terms in profile_terms.items():
            if any(term in normalized for term in terms):
                return profile
        return None

    @staticmethod
    def _is_sensitivity_query(message: str) -> bool:
        normalized = _normalize_text(message)
        subject = any(term in normalized for term in (
            "sensibilidad", "umbral", "modo", "perfil", "nivel de deteccion",
        ))
        query = any(term in normalized for term in (
            "cual es mi", "cual tengo", "que modo", "que perfil",
            "esta activo", "estoy usando",
            "tengo activado", "tengo activo",
        ))
        return subject and query

    @staticmethod
    def _is_sensitivity_change(message: str) -> bool:
        normalized = _normalize_text(message)
        return any(term in normalized for term in (
            "activa", "activar", "cambia", "cambiar", "coloca", "poner",
            "pon ", "quiero", "usa ", "usar ", "dejalo", "configura",
            "prefiero", "necesito",
        ))

    @staticmethod
    def requested_storage_state(
        message: str,
        history: list[dict] | None = None,
    ) -> bool | None:
        normalized = _normalize_text(message)
        history_text = " ".join(
            _normalize_text(str(item.get("content", "")))
            for item in (history or [])[-2:]
            if isinstance(item, dict)
        )
        storage_subject = any(term in normalized for term in (
            "almacenamiento", "guardar en servidor", "guardado global",
            "registro global", "base de datos global",
        ))
        contextual_reference = any(term in normalized for term in (
            "activalo", "activarlo", "desactivalo", "desactivarlo",
            "habilitalo", "habilitarlo", "deshabilitalo", "deshabilitarlo",
            "puedes hacerlo", "hazlo tu",
        )) and any(term in history_text for term in (
            "almacenamiento", "guardar en servidor", "almacenamiento global",
        ))
        if not (storage_subject or contextual_reference):
            return None

        if any(term in normalized for term in (
            "desactiva", "desactivalo", "desactivar", "desactivarlo",
            "deshabilita", "deshabilitalo", "deshabilitar", "deshabilitarlo",
            "no guardes", "deja de guardar",
        )):
            return False
        if any(term in normalized for term in (
            "activa", "activalo", "activar", "activarlo", "habilita",
            "habilitalo", "habilitar", "habilitarlo", "guarda en servidor",
            "quiero guardar",
        )):
            return True
        return None

    @staticmethod
    def _is_storage_query(message: str) -> bool:
        normalized = _normalize_text(message)
        subject = any(term in normalized for term in (
            "almacenamiento", "guardar en servidor", "guardado global",
            "registro global", "base de datos global",
        ))
        query = any(term in normalized for term in (
            "esta activo", "esta activado", "esta habilitado", "se guarda",
            "estoy guardando", "cual es el estado", "tengo activo",
        ))
        return subject and query

    def extract_url(self, message: str) -> str | None:
        match = EXPLICIT_URL_PATTERN.search(message)
        if not match:
            match = BARE_DOMAIN_PATTERN.search(message)
        if not match:
            return None
        candidate = match.group("url").rstrip(".,;:!?)]}")
        normalized = candidate if "://" in candidate else f"https://{candidate}"
        parsed = urlparse(normalized)
        return normalized if parsed.hostname else None

    def identify_intent(
        self,
        message: str,
        has_previous_analysis: bool,
        history: list[dict] | None = None,
    ) -> Intent:
        if self.extract_url(message):
            return Intent.URL_ANALYSIS

        requested_profile = self.requested_sensitivity_profile(message)
        if requested_profile and self._is_sensitivity_change(message):
            return Intent.SENSITIVITY_CHANGE
        if self._is_sensitivity_query(message):
            return Intent.SENSITIVITY_QUERY

        if self._is_storage_query(message):
            return Intent.STORAGE_QUERY
        if self.requested_storage_state(message, history) is not None:
            return Intent.STORAGE_CHANGE

        normalized = _normalize_text(message)
        general_process_phrases = (
            "proceso completo",
            "flujo completo",
            "como funciona el sistema",
            "como funciona el analisis",
            "como trabajan los agentes",
            "flujo de los agentes",
            "proceso multiagente",
        )
        if any(phrase in normalized for phrase in general_process_phrases):
            return Intent.GENERAL_QUERY

        follow_up_terms = (*FOLLOW_UP_TERMS, *FEATURE_FOLLOW_UP_TERMS)
        if has_previous_analysis and any(term in normalized for term in follow_up_terms):
            return Intent.ANALYSIS_FOLLOW_UP

        return Intent.GENERAL_QUERY

    def route(self, intent: Intent) -> list[str]:
        if intent == Intent.URL_ANALYSIS:
            return ["analysis_agent", "decision_agent", "explainability_agent"]
        if intent in {
            Intent.SENSITIVITY_CHANGE,
            Intent.SENSITIVITY_QUERY,
            Intent.STORAGE_CHANGE,
            Intent.STORAGE_QUERY,
        }:
            return ["coordinator_agent"]
        return ["explainability_agent"]
