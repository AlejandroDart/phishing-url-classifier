import logging
import os
import uuid
from inspect import signature

from database.agent_repository import AgentRepository, agent_repository
from multiagent.agents import (
    AnalysisAgent,
    CoordinatorAgent,
    DecisionAgent,
    ExplainabilityAgent,
)
from multiagent.contracts import ConversationContext, Intent
from multiagent.events import EventTracer
from multiagent.memory import ShortTermMemory, short_term_memory
from services.prediction_service import prediction_service
from services.rag_service import rag_service
from services.sensitivity_service import normalize_sensitivity_profile


logger = logging.getLogger(__name__)


class MultiAgentOrchestrator:
    def __init__(
        self,
        *,
        coordinator=None,
        analysis_agent=None,
        decision_agent=None,
        explainability_agent=None,
        memory: ShortTermMemory | None = None,
        repository: AgentRepository | None = None,
    ):
        self.coordinator = coordinator or CoordinatorAgent()
        self.analysis_agent = analysis_agent or AnalysisAgent(prediction_service)
        self.decision_agent = decision_agent or DecisionAgent()
        self.explainability_agent = explainability_agent or ExplainabilityAgent(
            rag_service
        )
        self.memory = memory or short_term_memory
        self.repository = repository or agent_repository

    def _load_context(
        self,
        conversation_id: str,
        *,
        allow_persistent: bool,
    ) -> ConversationContext | None:
        context = self.memory.get(conversation_id)
        if context is not None:
            return context
        if not allow_persistent:
            return None
        context = self.repository.latest_context(conversation_id)
        if context is not None:
            self.memory.put(context)
        return context

    def handle(
        self,
        question: str,
        *,
        history: list[dict] | None = None,
        conversation_id: str | None = None,
        store_global: bool = False,
        model_id: str | None = None,
        sensitivity_profile: str | None = None,
    ) -> dict:
        interaction_id = str(uuid.uuid4())
        conversation_id = conversation_id or str(uuid.uuid4())
        history = history or []
        tracer = EventTracer(interaction_id)
        sensitivity_profile = normalize_sensitivity_profile(sensitivity_profile)

        previous_context = self._load_context(
            conversation_id,
            allow_persistent=store_global,
        )
        with tracer.operation(
            "intent_identified",
            self.coordinator.name,
        ):
            intent = self.coordinator.identify_intent(
                question,
                has_previous_analysis=previous_context is not None,
                history=history,
            )
            route = self.coordinator.route(intent)

        analysis = None
        decision = None

        if intent == Intent.SENSITIVITY_CHANGE:
            requested_profile = self.coordinator.requested_sensitivity_profile(
                question
            )
            labels = {
                "aggressive": "Agresivo",
                "balanced": "Equilibrado",
                "passive": "Pasivo",
            }
            result = {
                "answer": (
                    f"Listo. Cambié el perfil de sensibilidad a "
                    f"{labels[requested_profile]}. La configuración se aplicará "
                    "al escáner y a mis próximos análisis."
                ),
                "sources": ["Configuración de LinkShield AI"],
                "model": None,
                "generation_mode": "sensitivity_configuration_change",
                "action": {
                    "type": "set_sensitivity",
                    "value": requested_profile,
                },
            }
        elif intent == Intent.SENSITIVITY_QUERY:
            labels = {
                "aggressive": "Agresivo",
                "balanced": "Equilibrado",
                "passive": "Pasivo",
            }
            result = {
                "answer": (
                    f"El perfil de sensibilidad activo es "
                    f"{labels[sensitivity_profile]}. Se usa tanto en el escáner "
                    "como en mis análisis de URL."
                ),
                "sources": ["Configuración de LinkShield AI"],
                "model": None,
                "generation_mode": "sensitivity_configuration_query",
            }
        elif intent == Intent.STORAGE_CHANGE:
            enabled = self.coordinator.requested_storage_state(question, history)
            result = {
                "answer": (
                    "Listo. Activé el almacenamiento global. Los próximos análisis "
                    "podrán guardarse en el servidor."
                    if enabled
                    else "Listo. Desactivé el almacenamiento global. Los próximos "
                    "análisis permanecerán solamente en el historial local."
                ),
                "sources": ["Configuración de LinkShield AI"],
                "model": None,
                "generation_mode": "storage_configuration_change",
                "action": {
                    "type": "set_global_storage",
                    "value": enabled,
                },
            }
        elif intent == Intent.STORAGE_QUERY:
            result = {
                "answer": (
                    "El almacenamiento global está activado. Los análisis pueden "
                    "guardarse en el servidor."
                    if store_global
                    else "El almacenamiento global está desactivado. Los análisis "
                    "se conservan solamente en el historial local del dispositivo."
                ),
                "sources": ["Configuración de LinkShield AI"],
                "model": None,
                "generation_mode": "storage_configuration_query",
            }
        elif intent == Intent.URL_ANALYSIS:
            url = self.coordinator.extract_url(question)
            with tracer.operation(
                "url_analyzed",
                self.analysis_agent.name,
                target="technical_classifier",
            ):
                analysis_kwargs = {"store_global": store_global}
                if "sensitivity_profile" in signature(
                    self.analysis_agent.analyze
                ).parameters:
                    analysis_kwargs["sensitivity_profile"] = sensitivity_profile
                if model_id is not None:
                    analysis_kwargs["model_id"] = model_id
                analysis = self.analysis_agent.analyze(
                    url,
                    interaction_id,
                    **analysis_kwargs,
                )

            with tracer.operation(
                "decision_created",
                self.decision_agent.name,
                target=self.explainability_agent.name,
            ):
                decision = self.decision_agent.decide(analysis)

            context = ConversationContext(
                conversation_id=conversation_id,
                interaction_id=interaction_id,
                analysis=analysis,
                decision=decision,
            )
            self.memory.put(context)
            with tracer.operation(
                "explanation_generated",
                self.explainability_agent.name,
            ):
                result = self.explainability_agent.explain_analysis(
                    question,
                    analysis,
                    decision,
                    history,
                )
        elif intent == Intent.ANALYSIS_FOLLOW_UP and previous_context is not None:
            analysis = previous_context.analysis
            decision = previous_context.decision
            with tracer.operation(
                "memory_recalled",
                self.coordinator.name,
                target="short_or_persistent_memory",
            ):
                pass
            with tracer.operation(
                "explanation_generated",
                self.explainability_agent.name,
            ):
                result = self.explainability_agent.explain_analysis(
                    question,
                    analysis,
                    decision,
                    history,
                    follow_up=True,
                )
        else:
            with tracer.operation(
                "knowledge_answer_generated",
                self.explainability_agent.name,
                target="rag_ollama",
            ):
                result = self.explainability_agent.answer_general(question, history)

        result.update({
            "interaction_id": interaction_id,
            "conversation_id": conversation_id,
            "intent": intent.value,
            "agents": route,
            "analysis": analysis.to_dict() if analysis else None,
            "decision": decision.to_dict() if decision else None,
            "trace": tracer.summary(),
        })
        persisted = False
        if store_global:
            persisted = self.repository.save_interaction(
                interaction_id=interaction_id,
                conversation_id=conversation_id,
                intent=intent.value,
                user_message=question,
                status="completed",
                analysis=analysis.to_dict() if analysis else None,
                decision=decision.to_dict() if decision else None,
                response_summary=result.get("answer", ""),
                events=tracer.events,
            )
        result["persisted"] = persisted
        result["persistence_mode"] = (
            "global_postgresql" if store_global else "short_term_memory_only"
        )
        return result


multiagent_orchestrator = MultiAgentOrchestrator()


def multiagent_enabled() -> bool:
    return os.getenv("MULTI_AGENT_CHAT_ENABLED", "true").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }
