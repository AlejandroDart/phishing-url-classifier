import pytest

from services.sensitivity_service import (
    normalize_sensitivity_profile,
    resolve_sensitivity_threshold,
)


@pytest.mark.parametrize(
    ("profile", "expected"),
    [
        ("aggressive", 0.25),
        ("balanced", 0.50),
        ("passive", 0.75),
    ],
)
def test_hybrid_threshold_profiles(profile, expected):
    result = resolve_sensitivity_threshold(0.50, profile)
    assert result.effective_threshold == expected


def test_balanced_preserves_each_models_validated_threshold():
    result = resolve_sensitivity_threshold(0.405, None)
    assert result.profile == "balanced"
    assert result.effective_threshold == 0.405


def test_threshold_adjustment_is_bounded():
    assert resolve_sensitivity_threshold(0.15, "aggressive").effective_threshold == 0.05
    assert resolve_sensitivity_threshold(0.80, "passive").effective_threshold == 0.95


def test_rejects_unknown_profile():
    with pytest.raises(ValueError):
        normalize_sensitivity_profile("extreme")
