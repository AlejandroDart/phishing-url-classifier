from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


class Intent(str, Enum):
    GENERAL_QUERY = "general_query"
    URL_ANALYSIS = "url_analysis"
    ANALYSIS_FOLLOW_UP = "analysis_follow_up"
    SENSITIVITY_CHANGE = "sensitivity_change"
    SENSITIVITY_QUERY = "sensitivity_query"
    STORAGE_CHANGE = "storage_change"
    STORAGE_QUERY = "storage_query"


@dataclass(frozen=True)
class AnalysisResult:
    interaction_id: str
    url: str
    classification: str
    probability: float
    indicators: dict[str, Any]
    analyzed_at: str
    model_id: str = "random_forest"
    model_name: str = "Random Forest Top 25"
    stored_global: bool = False
    shap_explanation: dict[str, Any] = field(default_factory=dict)
    sensitivity_profile: str = "balanced"
    base_threshold: float = 0.5
    effective_threshold: float = 0.5

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class DecisionResult:
    risk_level: str
    action: str
    utility_scores: dict[str, float]
    rationale: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass
class ConversationContext:
    conversation_id: str
    interaction_id: str
    analysis: AnalysisResult
    decision: DecisionResult
    updated_at: str = field(default_factory=utc_now)

    def to_dict(self) -> dict[str, Any]:
        return {
            "conversation_id": self.conversation_id,
            "interaction_id": self.interaction_id,
            "analysis": self.analysis.to_dict(),
            "decision": self.decision.to_dict(),
            "updated_at": self.updated_at,
        }

    @classmethod
    def from_dict(cls, data: dict[str, Any]):
        return cls(
            conversation_id=data["conversation_id"],
            interaction_id=data["interaction_id"],
            analysis=AnalysisResult(**data["analysis"]),
            decision=DecisionResult(**data["decision"]),
            updated_at=data.get("updated_at", utc_now()),
        )
