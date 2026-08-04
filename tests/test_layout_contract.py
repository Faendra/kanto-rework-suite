"""Contract documentation tests for the three required reference layouts.

The Lua implementation is exercised in Gen1Recomp during the runtime spike.
These tests pin the product-level breakpoint expectations in CI.
"""


def classify(width: int, height: int) -> str:
    ratio = width / height
    if ratio >= 1.35:
        return "landscape"
    if ratio <= 0.82:
        return "portrait"
    return "classic"


def test_reference_layouts() -> None:
    assert classify(1920, 1080) == "landscape"
    assert classify(1080, 1920) == "portrait"
    assert classify(1600, 1440) == "classic"
