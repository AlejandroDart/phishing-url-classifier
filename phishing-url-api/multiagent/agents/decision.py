from multiagent.contracts import AnalysisResult, DecisionResult


class DecisionAgent:
    name = "decision_agent"

    @staticmethod
    def _technical_signal(indicators: dict) -> float:
        signals = [
            min(float(indicators.get("phish_hints", 0)) / 2.0, 1.0),
            min(float(indicators.get("nb_hyphens", 0)) / 3.0, 1.0),
            min(float(indicators.get("nb_dots", 0)) / 5.0, 1.0),
            1.0 if float(indicators.get("ip", 0)) > 0 else 0.0,
            min(float(indicators.get("ratio_digits_url", 0)), 1.0),
            min(float(indicators.get("ratio_extRedirection", 0)), 1.0),
        ]
        return sum(signals) / len(signals)

    def decide(self, analysis: AnalysisResult) -> DecisionResult:
        probability = min(max(float(analysis.probability), 0.0), 1.0)
        signal = self._technical_signal(analysis.indicators)

        # Each score represents the usefulness of a conversational action.
        utilities = {
            "inform": max(0.0, 1.0 - probability - (0.10 * signal)),
            "recommend_caution": max(
                0.0,
                1.0 - (abs(probability - 0.5) * 2.0) + (0.10 * signal),
            ),
            "priority_warning": min(1.0, probability + (0.15 * signal)),
        }
        action = max(utilities, key=utilities.get)
        risk_by_action = {
            "inform": "reduced",
            "recommend_caution": "moderate",
            "priority_warning": "high",
        }
        rationale = (
            f"Acción seleccionada por utilidad: probabilidad={probability:.3f}, "
            f"señal técnica={signal:.3f}."
        )
        return DecisionResult(
            risk_level=risk_by_action[action],
            action=action,
            utility_scores={key: round(value, 4) for key, value in utilities.items()},
            rationale=rationale,
        )
