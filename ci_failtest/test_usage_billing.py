import pytest

from ci_failtest.usage_billing import (
    Tier,
    billable_after_free,
    invoice_total,
    tiered_cost,
)

# 0–100 min @ $0.008, 100–500 @ $0.006, 500+ @ $0.004
TIERS = [Tier(100, 0.008), Tier(500, 0.006), Tier(None, 0.004)]


@pytest.mark.parametrize(
    "total,free,expected",
    [
        (0, 5000, 0.0),
        (4000, 5000, 0.0),
        (5000, 5000, 0.0),      # exactly at the allowance -> nothing billable
        (5200, 5000, 200.0),    # only the 200-min overage is billable
    ],
)
def test_billable_after_free(total, free, expected):
    assert billable_after_free(total, free) == expected


@pytest.mark.parametrize(
    "minutes,expected",
    [
        (50, 0.4),      # tier 1 only
        (100, 0.8),     # tier 1 boundary
        (300, 2.0),     # into tier 2
        (500, 3.2),     # tier 2 boundary
        (700, 4.0),     # into the unbounded tier 3
        (1000, 5.2),    # deep into tier 3
    ],
)
def test_tiered_cost(minutes, expected):
    assert tiered_cost(minutes, TIERS) == expected


def test_invoice_applies_free_then_tiers():
    # 5700 total, 5000 free -> 700 billable minutes -> $4.00
    assert invoice_total(5700, 5000, TIERS) == 4.0
