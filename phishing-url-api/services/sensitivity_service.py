from dataclasses import dataclass


DEFAULT_SENSITIVITY_PROFILE = "balanced"
VALID_SENSITIVITY_PROFILES = {"aggressive", "balanced", "passive"}
THRESHOLD_OFFSET = 0.25
MIN_THRESHOLD = 0.05
MAX_THRESHOLD = 0.95


@dataclass(frozen=True)
class SensitivityThreshold:
    profile: str
    base_threshold: float
    effective_threshold: float

    def to_dict(self) -> dict:
        return {
            "sensitivity_profile": self.profile,
            "base_threshold": round(self.base_threshold, 6),
            "effective_threshold": round(self.effective_threshold, 6),
        }


def normalize_sensitivity_profile(value: str | None) -> str:
    if value is None:
        return DEFAULT_SENSITIVITY_PROFILE
    if not isinstance(value, str):
        raise ValueError("sensitivity_profile debe ser texto")
    normalized = value.strip().lower()
    if normalized not in VALID_SENSITIVITY_PROFILES:
        allowed = ", ".join(sorted(VALID_SENSITIVITY_PROFILES))
        raise ValueError(
            f"sensitivity_profile no valido. Valores permitidos: {allowed}"
        )
    return normalized


def resolve_sensitivity_threshold(
    base_threshold: float,
    profile: str | None,
) -> SensitivityThreshold:
    normalized = normalize_sensitivity_profile(profile)
    base = min(max(float(base_threshold), MIN_THRESHOLD), MAX_THRESHOLD)
    adjustment = {
        "aggressive": -THRESHOLD_OFFSET,
        "balanced": 0.0,
        "passive": THRESHOLD_OFFSET,
    }[normalized]
    effective = min(max(base + adjustment, MIN_THRESHOLD), MAX_THRESHOLD)
    return SensitivityThreshold(
        profile=normalized,
        base_threshold=base,
        effective_threshold=effective,
    )
