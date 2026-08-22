from multiagent.contracts import AnalysisResult
from services.prediction_service import PredictionService


class AnalysisAgent:
    name = "analysis_agent"

    def __init__(self, prediction_service: PredictionService):
        self.prediction_service = prediction_service

    def analyze(
        self,
        url: str,
        interaction_id: str,
        *,
        store_global: bool = False,
        model_id: str | None = None,
        sensitivity_profile: str | None = None,
    ) -> AnalysisResult:
        technical = self.prediction_service.analyze(
            url,
            store_global=store_global,
            model_id=model_id,
            sensitivity_profile=sensitivity_profile,
        )
        return AnalysisResult(
            interaction_id=interaction_id,
            url=technical.url,
            classification=technical.label,
            probability=technical.probability,
            indicators=technical.explanation.get("features", {}),
            analyzed_at=technical.analyzed_at,
            model_id=technical.model_id,
            model_name=technical.model_name,
            stored_global=technical.stored_global,
            shap_explanation=technical.explanation.get("shap", {}),
            sensitivity_profile=technical.sensitivity_profile,
            base_threshold=technical.base_threshold,
            effective_threshold=technical.effective_threshold,
        )
