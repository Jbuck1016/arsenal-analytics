"""Deterministic WhoScored event phase classification."""

from __future__ import annotations

from typing import Any


SET_PIECE_QUALIFIERS = frozenset({
    "ThrowIn", "FreekickTaken", "CornerTaken", "GoalKick", "KeeperThrow",
    "IndirectFreekickTaken", "Penalty", "FromCorner", "SetPiece",
    "DirectFreekick", "ThrowinSetPiece", "DirectCorner",
})


def event_is_open_play(qualifiers: Any) -> bool:
    """Use the event's own restart/shot tags, not a database default."""
    if not isinstance(qualifiers, list):
        return True
    return not any(
        (qualifier.get("type") or {}).get("displayName") in SET_PIECE_QUALIFIERS
        if isinstance(qualifier.get("type"), dict)
        else qualifier.get("type") in SET_PIECE_QUALIFIERS
        for qualifier in qualifiers
        if isinstance(qualifier, dict)
    )
