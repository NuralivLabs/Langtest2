"""Tiered usage billing for MonkCI build minutes.

Given a month's total effective build minutes, apply the plan's free allowance
and then charge the remainder across ascending price tiers.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class Tier:
    # Cumulative-minute ceiling this tier covers up to; None means unbounded.
    up_to: Optional[float]
    price_per_min: float


def billable_after_free(total_minutes: float, free_allowance: float) -> float:
    """Minutes that remain billable once the free allowance is applied."""
    return max(0.0, float(total_minutes) - float(free_allowance))


def tiered_cost(minutes: float, tiers: list[Tier]) -> float:
    """Cost of ``minutes`` charged across ascending price tiers.

    Each tier prices the minutes that fall inside its band, where the band is the
    span between the previous tier's ceiling and this tier's ceiling.
    """
    cost = 0.0
    remaining = float(minutes)
    prev_cap = 0.0
    for tier in tiers:
        if tier.up_to is None:
            band = remaining
        else:
            band = tier.up_to
        take = min(remaining, band)
        if take <= 0:
            break
        cost += take * tier.price_per_min
        remaining -= take
        prev_cap = tier.up_to if tier.up_to is not None else prev_cap
    return round(cost, 4)


def invoice_total(total_minutes: float, free_allowance: float, tiers: list[Tier]) -> float:
    """End-to-end invoice: subtract the free allowance, then price the overage."""
    return tiered_cost(billable_after_free(total_minutes, free_allowance), tiers)
