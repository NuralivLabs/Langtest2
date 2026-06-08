"""Tiny self-contained module used to exercise the MonkCI debug agent."""


def add(a, b):
    # BUG: this subtracts instead of adding.
    return a - b


def multiply(a, b):
    return a * b
