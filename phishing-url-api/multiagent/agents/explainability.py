import re
import unicodedata

from multiagent.contracts import AnalysisResult, DecisionResult
from services.feature_knowledge import FEATURE_KNOWLEDGE, describe_feature_value
from services.rag_service import OllamaUnavailableError, RagService


class ExplainabilityAgent:
    name = "explainability_agent"

    def __init__(self, rag_service: RagService):
        self.rag_service = rag_service

    def answer_general(self, question: str, history: list[dict]) -> dict:
        technical_definition = self._technical_definition(question)
        if technical_definition is not None:
            return technical_definition
        return self.rag_service.answer(question, history=history)

    @classmethod
    def _technical_definition(cls, question: str) -> dict | None:
        normalized = cls._normalize(question)
        definition_terms = (
            "que significa",
            "que es",
            "que son",
            "que mide",
            "para que sirve",
            "explica",
            "defin",
        )
        if not any(term in normalized for term in definition_terms):
            return None

        if "shap" in normalized:
            return {
                "answer": (
                    "SHAP es un método de explicabilidad que muestra cuánto aportó cada "
                    "característica a la probabilidad calculada. Un valor positivo aumenta "
                    "la probabilidad de phishing y uno negativo la reduce respecto de la "
                    "base; explica la decisión del modelo, pero no demuestra causalidad."
                ),
                "sources": ["Base de conocimiento", "SHAP TreeExplainer"],
                "model": None,
                "generation_mode": "shap_knowledge_definition",
            }

        for feature, knowledge in FEATURE_KNOWLEDGE.items():
            terms = (
                feature,
                knowledge.get("label", ""),
                *knowledge.get("aliases", ()),
            )
            if any(cls._term_matches(str(term), normalized) for term in terms):
                return {
                    "answer": (
                        f"{knowledge['label']}: {knowledge['description']} "
                        "El clasificador la combina con las otras variables; por sí sola "
                        "no demuestra que una URL sea phishing ni que sea segura."
                    ),
                    "sources": ["Diccionario de características del clasificador"],
                    "model": None,
                    "generation_mode": "feature_knowledge_definition",
                }
        return None

    @classmethod
    def _term_matches(cls, term: str, normalized_question: str) -> bool:
        normalized_term = cls._normalize(term)
        if len(normalized_term) < 3:
            return False
        if normalized_term in normalized_question:
            return True

        ignored = {
            "a", "al", "de", "del", "el", "en", "la", "las", "los",
            "o", "un", "una", "y",
        }
        term_words = {
            word for word in re.findall(r"[a-z0-9]+", normalized_term)
            if word not in ignored
        }
        question_words = set(re.findall(r"[a-z0-9]+", normalized_question))
        return len(term_words) >= 2 and term_words.issubset(question_words)

    def explain_analysis(
        self,
        question: str,
        analysis: AnalysisResult,
        decision: DecisionResult,
        history: list[dict],
        *,
        follow_up: bool = False,
    ) -> dict:
        targeted = (
            self._targeted_shap_answer(question, analysis, decision)
            if follow_up
            else None
        )
        if targeted is not None:
            return targeted

        try:
            generated = self.rag_service.answer_with_analysis(
                question,
                analysis=analysis.to_dict(),
                decision=decision.to_dict(),
                history=history,
                follow_up=follow_up,
            )
            return self._grounded_explanation(
                analysis,
                decision,
                follow_up=follow_up,
                recommendation=generated["answer"],
                model=generated.get("model"),
                sources=generated.get("sources", []),
                generation_mode="shap_grounded_rag_ollama",
            )
        except OllamaUnavailableError:
            return self._grounded_explanation(
                analysis,
                decision,
                follow_up=follow_up,
                generation_mode="shap_grounded_fallback",
            )

    @staticmethod
    def _normalize(value: str) -> str:
        decomposed = unicodedata.normalize("NFKD", value.casefold())
        return "".join(
            character
            for character in decomposed
            if not unicodedata.combining(character)
        )

    @classmethod
    def _find_requested_factor(cls, question: str, analysis: AnalysisResult):
        normalized_question = cls._normalize(question)
        factors = cls._feature_all_factors(analysis.shap_explanation)
        for factor in factors:
            feature = factor.get("feature", "")
            knowledge = FEATURE_KNOWLEDGE.get(feature, {})
            terms = (
                feature,
                factor.get("display_name", ""),
                knowledge.get("label", ""),
                *knowledge.get("aliases", ()),
            )
            if any(cls._term_matches(str(term), normalized_question) for term in terms):
                return factor
        return None

    @staticmethod
    def _feature_top_factors(shap_data: dict) -> list:
        return (
            shap_data.get("feature_factors")
            or shap_data.get("top_factors", [])
        )[:3]

    @staticmethod
    def _feature_all_factors(shap_data: dict) -> list:
        return (
            shap_data.get("all_feature_contributions")
            or shap_data.get("feature_factors")
            or shap_data.get("all_contributions", [])
        )

    @classmethod
    def _targeted_shap_answer(
        cls,
        question: str,
        analysis: AnalysisResult,
        decision: DecisionResult | None = None,
    ) -> dict | None:
        shap_data = analysis.shap_explanation
        if not shap_data.get("available"):
            return None

        normalized_question = cls._normalize(question)
        requested_factor = cls._find_requested_factor(question, analysis)
        asks_about_model_component = any(term in normalized_question for term in (
            "que modelo",
            "cual modelo",
            "rama del modelo",
            "componente del modelo",
            "componente del ensamble",
            "rama del ensamble",
        ))
        feature_top_factors = cls._feature_top_factors(shap_data)
        feature_all_factors = cls._feature_all_factors(shap_data)
        top_factors = (
            shap_data.get("top_factors", [])[:3]
            if asks_about_model_component
            else feature_top_factors
        )
        all_factors = (
            shap_data.get("all_contributions", [])
            if asks_about_model_component
            else feature_all_factors
        )
        asks_about_points = "punto" in normalized_question
        asks_for_top_factor = any(term in normalized_question for term in (
            "influyo mas",
            "influye mas",
            "mayor influencia",
            "factor principal",
            "caracteristica principal",
            "variable principal",
            "senal principal",
            "mayor peso",
        )) or (
            "influy" in normalized_question and "mas" in normalized_question
        )
        asks_for_least_factor = any(term in normalized_question for term in (
            "menor influencia",
            "influyo menos",
            "influye menos",
            "menos influyente",
            "menor peso",
            "menos peso",
        ))
        asks_for_simple_explanation = any(term in normalized_question for term in (
            "manera sencilla",
            "forma sencilla",
            "en sencillo",
            "facil de entender",
            "palabras simples",
            "como si no supiera",
        ))
        asks_why = any(term in normalized_question for term in (
            "por que",
            "como llegaste",
            "motivo de",
            "razon de",
            "que hizo que",
        ))
        asks_for_probability = any(term in normalized_question for term in (
            "cual fue la probabilidad",
            "que significa la probabilidad",
            "explica la probabilidad",
            "porcentaje",
            "nivel de probabilidad",
        )) or (
            "probabilidad" in normalized_question
            and any(term in normalized_question for term in (
                "cual",
                "significa",
                "explica",
                "entiendo",
            ))
        )
        asks_for_directions = any(term in normalized_question for term in (
            "aumentaron",
            "redujeron",
            "aumenta el riesgo",
            "reduce el riesgo",
            "a favor y en contra",
        )) or (
            "aument" in normalized_question and "redu" in normalized_question
        )
        asks_for_action = any(term in normalized_question for term in (
            "que debo hacer",
            "que deberia hacer",
            "que hago con",
            "como procedo",
            "puedo abrir",
            "debo abrir",
            "recomendacion",
        ))
        asks_for_verdict = any(term in normalized_question for term in (
            "es seguro",
            "es segura",
            "es peligroso",
            "es peligrosa",
            "puedo confiar",
            "es phishing entonces",
        ))
        asks_for_analyzed_url = any(term in normalized_question for term in (
            "cual fue la url",
            "que url analizaste",
            "url analizada",
            "url que analizaste",
        ))
        asks_for_threshold = any(term in normalized_question for term in (
            "umbral aplicado",
            "perfil aplicado",
            "que umbral",
            "cual umbral",
            "supero el umbral",
        ))
        definition_terms = (
            "que significa",
            "a que se refiere",
            "que es",
            "explica",
            "defin",
        )
        asks_for_definition = any(
            term in normalized_question for term in definition_terms
        ) or len(question.split()) <= 6

        if requested_factor is not None and asks_for_definition:
            feature = requested_factor.get("feature", "")
            knowledge = FEATURE_KNOWLEDGE.get(feature, {})
            label = knowledge.get(
                "label", requested_factor.get("display_name", feature)
            )
            description = knowledge.get(
                "description", requested_factor.get("description", "")
            )
            raw_value = requested_factor.get("raw_value")
            value_meaning = describe_feature_value(feature, raw_value)
            shap_value = float(requested_factor.get("shap_value", 0))
            direction = "aumentó" if shap_value > 0 else "redujo"
            points = abs(shap_value) * 100
            return {
                "answer": (
                    f"{label}: {description[:1].lower() + description[1:]} "
                    f"{value_meaning} En este análisis aportó {points:.1f} puntos "
                    f"y {direction} la probabilidad de phishing respecto de la base; "
                    "es una influencia del modelo, no una prueba aislada sobre el sitio."
                ),
                "sources": ["Resultado del clasificador", "SHAP TreeExplainer"],
                "model": None,
                "generation_mode": "shap_feature_definition",
            }

        if asks_about_points:
            examples = []
            for factor in top_factors:
                value = float(factor.get("shap_value", 0))
                operation = "sumó" if value > 0 else "restó"
                examples.append(
                    f"{factor.get('display_name', factor.get('feature'))} "
                    f"{operation} {abs(value) * 100:.1f} puntos"
                )
            base = float(shap_data.get("base_probability", 0)) * 100
            final = float(analysis.probability) * 100
            return {
                "answer": (
                    "Los puntos SHAP son puntos porcentuales aportados al cálculo de "
                    "la probabilidad de phishing, no una nota independiente sobre 100. "
                    f"El modelo partió de una base de {base:.1f}%; por ejemplo, "
                    f"{'; '.join(examples)}. Al sumar las contribuciones de las "
                    f"25 variables a la base se obtiene la probabilidad final de {final:.1f}%."
                ),
                "sources": ["Resultado del clasificador", "SHAP TreeExplainer"],
                "model": None,
                "generation_mode": "shap_points_definition",
            }

        if asks_for_top_factor and top_factors:
            factor = max(
                top_factors,
                key=lambda item: abs(float(item.get("shap_value", 0))),
            )
            feature = factor.get("feature", "")
            knowledge = FEATURE_KNOWLEDGE.get(feature, {})
            label = knowledge.get(
                "label", factor.get("display_name", feature)
            )
            description = knowledge.get(
                "description", factor.get("description", "")
            )
            value_meaning = describe_feature_value(
                feature, factor.get("raw_value")
            )
            shap_value = float(factor.get("shap_value", 0))
            effect = "aumentó" if shap_value > 0 else "redujo"
            return cls._shap_response(
                (
                    f"La característica con mayor influencia fue {label}. "
                    f"{description} {value_meaning} En este análisis fue la señal "
                    f"más importante: {effect} la probabilidad de phishing en "
                    f"{abs(shap_value) * 100:.1f} puntos respecto de la base. "
                    "No determina el resultado por sí sola."
                ),
                "shap_top_factor",
            )

        if asks_for_least_factor and all_factors:
            factor = min(
                all_factors,
                key=lambda item: abs(float(item.get("shap_value", 0))),
            )
            feature = factor.get("feature", "")
            knowledge = FEATURE_KNOWLEDGE.get(feature, {})
            label = knowledge.get(
                "label", factor.get("display_name", feature)
            )
            description = knowledge.get(
                "description", factor.get("description", "")
            )
            value_meaning = describe_feature_value(
                feature, factor.get("raw_value")
            )
            shap_value = float(factor.get("shap_value", 0))
            if shap_value > 1e-12:
                effect = "aumentó"
            elif shap_value < -1e-12:
                effect = "redujo"
            else:
                effect = "no modificó"
            return cls._shap_response(
                (
                    f"La característica con menor influencia fue {label}. "
                    f"{description} {value_meaning} Fue la señal con menor impacto "
                    f"absoluto: {effect} la probabilidad de phishing en "
                    f"{abs(shap_value) * 100:.1f} puntos respecto de la base."
                ),
                "shap_least_factor",
            )

        if asks_for_simple_explanation:
            probability = float(analysis.probability) * 100
            classification = (
                "phishing" if analysis.classification == "phishing"
                else "no phishing"
            )
            strongest = top_factors[0] if top_factors else None
            signal_text = ""
            if strongest:
                label = strongest.get(
                    "display_name", strongest.get("feature", "la señal principal")
                )
                effect = (
                    "elevó" if float(strongest.get("shap_value", 0)) > 0
                    else "disminuyó"
                )
                signal_text = f" La señal más influyente fue {label}, que {effect} el riesgo."
            return cls._shap_response(
                (
                    f"En sencillo: el modelo considera la URL {classification}. "
                    f"Estimó {probability:.1f}% de riesgo, es decir, aproximadamente "
                    f"{round(probability)} de cada 100 en su escala de predicción; "
                    f"no es una certeza absoluta.{signal_text}"
                ),
                "shap_simple_explanation",
            )

        if asks_for_probability:
            probability = float(analysis.probability) * 100
            base = float(shap_data.get("base_probability", 0.5)) * 100
            return cls._shap_response(
                (
                    f"La probabilidad estimada de phishing fue {probability:.1f}%; "
                    f"la alternativa no phishing corresponde a {100 - probability:.1f}%. "
                    f"El cálculo partió de una referencia de {base:.1f}% y las variables "
                    "SHAP aumentaron o redujeron ese valor. Es una estimación del modelo, "
                    "no una garantía sobre el sitio."
                ),
                "shap_probability_explanation",
            )

        if asks_for_directions:
            factors = feature_all_factors
            increasing = sorted(
                (item for item in factors if float(item.get("shap_value", 0)) > 0),
                key=lambda item: abs(float(item.get("shap_value", 0))),
                reverse=True,
            )[:3]
            reducing = sorted(
                (item for item in factors if float(item.get("shap_value", 0)) < 0),
                key=lambda item: abs(float(item.get("shap_value", 0))),
                reverse=True,
            )[:3]

            def summarize(items):
                return "; ".join(
                    f"{item.get('display_name', item.get('feature'))} "
                    f"({abs(float(item.get('shap_value', 0))) * 100:.1f} puntos)"
                    for item in items
                ) or "ninguna señal relevante"

            return cls._shap_response(
                (
                    f"Aumentaron el riesgo: {summarize(increasing)}. "
                    f"Redujeron el riesgo: {summarize(reducing)}. "
                    "El resultado final combina todas las variables, no solo estas señales."
                ),
                "shap_direction_summary",
            )

        if asks_for_action:
            probability = float(analysis.probability) * 100
            if analysis.classification == "phishing":
                advice = (
                    "No abras el enlace ni ingreses datos. Si ya lo abriste, no descargues "
                    "archivos; si entregaste credenciales, cámbialas desde el sitio oficial "
                    "y activa autenticación multifactor."
                )
            else:
                advice = (
                    "El modelo no detectó phishing, pero verifica que el dominio sea el "
                    "oficial antes de ingresar datos, descargar archivos o realizar pagos."
                )
            return cls._shap_response(
                f"La estimación fue {probability:.1f}% de phishing. {advice}",
                "shap_action_recommendation",
            )

        if asks_for_verdict:
            probability = float(analysis.probability) * 100
            if analysis.classification == "phishing":
                verdict = (
                    f"No conviene tratarla como segura: el modelo la clasificó como phishing "
                    f"con {probability:.1f}% de probabilidad. Evita abrirla o entregar datos."
                )
            else:
                verdict = (
                    f"El modelo no la clasificó como phishing y estimó {probability:.1f}% de "
                    "riesgo. Aun así, eso no garantiza que sea segura: confirma el dominio, "
                    "el contexto del mensaje y cualquier solicitud de credenciales o pago."
                )
            return cls._shap_response(verdict, "shap_safety_verdict")

        if asks_for_analyzed_url:
            return cls._shap_response(
                f"La URL del último análisis en esta conversación fue: {analysis.url}",
                "analysis_url_recall",
            )

        if asks_for_threshold:
            profile_label = {
                "aggressive": "Agresivo",
                "balanced": "Equilibrado",
                "passive": "Pasivo",
            }.get(analysis.sensitivity_profile, "Equilibrado")
            comparison = "superó" if analysis.classification == "phishing" else "no superó"
            return cls._shap_response(
                (
                    f"En ese análisis se aplicó el perfil {profile_label}, con un "
                    f"umbral de {analysis.effective_threshold * 100:.1f}%. La "
                    f"probabilidad calculada fue {analysis.probability * 100:.1f}% y "
                    f"{comparison} el umbral; por eso la clasificación final fue "
                    f"{'phishing' if analysis.classification == 'phishing' else 'no phishing'}. "
                    "El perfil no modificó la probabilidad ni la explicación SHAP."
                ),
                "sensitivity_threshold_explanation",
            )

        if asks_why and top_factors:
            details = []
            for factor in top_factors:
                feature = factor.get("feature", "")
                label = factor.get("display_name", feature)
                effect = (
                    "empujó el riesgo hacia arriba"
                    if float(factor.get("shap_value", 0)) > 0
                    else "empujó el riesgo hacia abajo"
                )
                details.append(
                    f"{label} {effect} en "
                    f"{abs(float(factor.get('shap_value', 0))) * 100:.1f} puntos"
                )
            return cls._shap_response(
                (
                    "El modelo llegó a esa conclusión al combinar las 25 características "
                    f"extraídas de la URL y del sitio. Las señales decisivas fueron: "
                    f"{'; '.join(details)}. La clasificación corresponde al efecto "
                    "conjunto de todas ellas."
                ),
                "shap_reasoning_summary",
            )

        return None

    @staticmethod
    def _shap_response(answer: str, generation_mode: str) -> dict:
        return {
            "answer": answer,
            "sources": ["Resultado del clasificador", "SHAP TreeExplainer"],
            "model": None,
            "generation_mode": generation_mode,
        }

    @staticmethod
    def _grounded_explanation(
        analysis: AnalysisResult,
        decision: DecisionResult,
        *,
        follow_up: bool,
        recommendation: str | None = None,
        model: str | None = None,
        sources: list[str] | None = None,
        generation_mode: str,
    ) -> dict:
        probability = round(analysis.probability * 100, 1)
        classification = (
            "phishing" if analysis.classification == "phishing" else "no phishing"
        )
        recommendation = recommendation or {
            "high": "No abras el enlace ni ingreses credenciales.",
            "moderate": "Verifica el dominio por un canal oficial antes de continuar.",
            "reduced": "Mantén la precaución habitual y verifica siempre el dominio.",
        }[decision.risk_level]
        top_factors = ExplainabilityAgent._feature_top_factors(
            analysis.shap_explanation
        )
        factor_text = ""
        if top_factors:
            summaries = []
            for factor in top_factors:
                effect = (
                    "aumentó" if factor.get("shap_value", 0) > 0 else "redujo"
                )
                impact_points = abs(float(factor.get("shap_value", 0))) * 100
                summaries.append(
                    f"{factor.get('display_name', factor.get('feature'))} {effect} "
                    f"{impact_points:.1f} puntos"
                )
            base_probability = analysis.shap_explanation.get("base_probability")
            base_text = (
                f" desde una base de {float(base_probability) * 100:.1f}%"
                if base_probability is not None
                else ""
            )
            factor_text = (
                f" La explicación SHAP{base_text} identificó: "
                f"{'; '.join(summaries)}."
            )
        model_label = analysis.model_name or analysis.model_id
        opening = "Sobre el análisis anterior, el" if follow_up else "El"
        shap_method = analysis.shap_explanation.get("method", "SHAP")
        profile_label = {
            "aggressive": "Agresivo",
            "balanced": "Equilibrado",
            "passive": "Pasivo",
        }.get(analysis.sensitivity_profile, "Equilibrado")
        threshold_text = (
            f" Se aplicó el perfil {profile_label} con un umbral de "
            f"{analysis.effective_threshold * 100:.1f}%."
        )
        return {
            "answer": (
                f"{opening} modelo {model_label} clasificó la URL como {classification} "
                f"con {probability}% de probabilidad de phishing.{threshold_text}"
                f"{factor_text} "
                f"{recommendation}"
            ),
            "sources": [
                "Resultado del clasificador",
                f"SHAP {shap_method}",
                *(sources or []),
            ],
            "model": model,
            "generation_mode": generation_mode,
        }
