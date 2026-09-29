"""Display formatting driven by CL_INDICATOR's ``display_as`` and ``decimals``."""

from __future__ import annotations

import math

# display_as values in CL_INDICATOR: PERCENT, NUMBER, CURRENCY, MILLIONS.
_SCALE = {"PERCENT": 100.0, "NUMBER": 1.0, "CURRENCY": 1.0, "MILLIONS": 1e-6}


def format_value(value, display_as: str, decimals, missing: str = "") -> str:
    """Format one observation for display.

    ``PERCENT`` multiplies a share (0-1) by 100 and appends ``%``;
    ``MILLIONS`` divides by one million; ``NUMBER`` and ``CURRENCY`` use a
    thousands separator. ``decimals`` is the number of decimal places.
    Missing values (None, NaN) return ``missing``.
    """
    if value is None:
        return missing
    try:
        v = float(value)
    except (TypeError, ValueError):
        return missing
    if math.isnan(v):
        return missing
    kind = str(display_as).strip().upper()
    if kind not in _SCALE:
        raise ValueError(f"unknown display_as {display_as!r}")
    d = int(decimals) if str(decimals).strip() != "" else 0
    v = v * _SCALE[kind]
    if kind == "PERCENT":
        return f"{v:.{d}f}%"
    if kind == "MILLIONS":
        return f"{v:.{d}f}"
    return f"{v:,.{d}f}"
