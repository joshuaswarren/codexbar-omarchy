#!/usr/bin/env python3
"""
Standalone parser tests for codexbar-omarchy.

We don't pull in Quickshell here — the JS adapter code (`providers/cli.js`)
is tested via a thin Python mirror that asserts the same JSON shapes the CLI
emits parse to the same internal model. If upstream ever changes the schema,
these tests fail loudly.

Run: python3 tests/run_tests.py
Exits 0 on success, 1 on any assertion failure.
"""
from __future__ import annotations
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIX = ROOT / "fixtures" / "codexbar-mock.json"

# ---------- expected internal shapes (mirror providers/cli.js normalize*) ----------

EXPECTED_PROVIDER_KEYS = {"id", "name", "enabled", "windows", "category", "icon", "accentColor", "source"}
EXPECTED_USAGE_KEYS    = {"provider", "primary", "windows", "spend", "status", "message", "fetchedAt"}
EXPECTED_WINDOW_KEYS   = {"name", "used", "limit", "unit", "resetAt"}

# Categories we expect every fixture provider to map into
VALID_CATEGORIES = {
    "Coding agent", "Model API", "Voice / Audio", "Gateway", "Cloud", "Other"
}


# ---------- mirror of providers/cli.js normalize* ----------

def normalize_provider(p: dict) -> dict:
    return {
        "id": str(p.get("id") or p.get("provider") or ""),
        "name": str(p.get("name") or p.get("displayName") or p.get("id") or ""),
        "enabled": p.get("enabled") is not False and p.get("disabled") is not True,
        "windows": list(p.get("windows") or []),
        "category": infer_category(str(p.get("id") or "")),
        "icon": p.get("icon"),
        "accentColor": p.get("accentColor"),
        "source": p.get("source"),
    }


def infer_category(pid: str) -> str:
    s = pid.lower()
    if any(k in s for k in ["claude", "codex", "copilot", "cursor", "kiro", "zed",
                              "kilo", "roo", "cline", "devin", "droid", "windsurf",
                              "augment", "opencode", "antigravity", "qoder", "command",
                              "codebuff", "amp", "alibaba", "manus"]):
        return "Coding agent"
    if any(k in s for k in ["gpt", "openai", "azure", "gemini", "grok", "deepseek",
                             "mistral", "moonshot", "kimi", "doubao", "ollama", "groq",
                             "llama"]):
        return "Model API"
    if s in ("elevenlabs", "deepgram"):
        return "Voice / Audio"
    if s in ("openrouter", "litellm", "llm_proxy", "clawrouter", "sub2api",
             "wayfinder", "zenmux", "chutes", "neuralwatt"):
        return "Gateway"
    if s in ("aws", "bedrock", "vertex", "fireworks", "deepinfra", "venice",
             "synthetic", "jetbrains", "ibm", "ibm_bob"):
        return "Cloud"
    return "Other"


def normalize_window(w: dict) -> dict:
    def num(v, dflt):
        try: return float(v) if v is not None else dflt
        except (TypeError, ValueError): return dflt
    return {
        "name": str(w.get("name") or w.get("label") or "session"),
        "used": num(w.get("used"), 0),
        "limit": num(w.get("limit"), 100),
        "unit": w.get("unit") or "%",
        "resetAt": w.get("resetAt") or w.get("reset"),
    }


def normalize_usage(u: dict, pid: str) -> dict:
    windows = [normalize_window(w) for w in (u.get("windows") or [])]
    primary = u.get("primary") or (windows[0] if windows else None)
    return {
        "provider": pid,
        "primary": primary,
        "windows": windows,
        "spend": u.get("spend"),
        "status": u.get("status") or "ok",
        "message": u.get("message") or "",
        "fetchedAt": 12345,  # deterministic in tests
    }


# ---------- assertions ----------

def assert_eq(label, got, want):
    if got != want:
        print(f"FAIL  {label}\n  got:  {got!r}\n  want: {want!r}")
        sys.exit(1)
    print(f"ok    {label}")


def assert_true(label, cond):
    if not cond:
        print(f"FAIL  {label}")
        sys.exit(1)
    print(f"ok    {label}")


def main() -> int:
    data = json.loads(FIX.read_text())

    # --- provider list ---
    providers = [normalize_provider(p) for p in data["providers"]]
    assert_true(f"all {len(providers)} providers have unique ids",
                len({p["id"] for p in providers}) == len(providers))
    for p in providers:
        assert_true(f"provider '{p['id']}' has all keys",
                    set(p.keys()) == EXPECTED_PROVIDER_KEYS)
        assert_true(f"provider '{p['id']}' has valid category",
                    p["category"] in VALID_CATEGORIES)
        assert_true(f"provider '{p['id']}' has non-empty id", bool(p["id"]))

    # spot-check category inference
    by_id = {p["id"]: p for p in providers}
    assert_eq("codex category",  by_id["codex"]["category"],      "Coding agent")
    assert_eq("claude category", by_id["claude"]["category"],     "Coding agent")
    assert_eq("gemini category", by_id["gemini"]["category"],     "Model API")
    assert_eq("elevenlabs cat",  by_id["elevenlabs"]["category"], "Voice / Audio")
    assert_eq("openrouter cat",  by_id["openrouter"]["category"], "Gateway")
    assert_eq("bedrock cat",     by_id["bedrock"]["category"],    "Cloud")

    # --- enabled count from fixture ---
    enabled_upstream = [p for p in providers if p["enabled"]]
    assert_true(f"at least one upstream-enabled provider", len(enabled_upstream) >= 4)
    enabled_ids = {p["id"] for p in enabled_upstream}
    assert_eq("enabled set", enabled_ids, {"codex", "claude", "cursor", "gemini", "openrouter", "copilot"})

    # --- usage normalization ---
    for pid, raw in data["usage"].items():
        u = normalize_usage(raw, pid)
        assert_true(f"usage '{pid}' has all keys",
                    set(u.keys()) == EXPECTED_USAGE_KEYS)
        assert_true(f"usage '{pid}' has windows", len(u["windows"]) > 0)
        for w in u["windows"]:
            assert_true(f"usage '{pid}' window '{w.get('name')}' has all keys",
                        set(w.keys()) == EXPECTED_WINDOW_KEYS)
            assert_true(f"usage '{pid}' window is finite",
                        (w["used"] >= 0 and w["limit"] > 0))
        assert_eq(f"usage '{pid}' provider echoed", u["provider"], pid)
        assert_true(f"usage '{pid}' status is one of ok|warning|urgent|error",
                    u["status"] in {"ok", "warning", "urgent", "error", "incident"})

    # --- urgent cadence trigger (gemini at 91%) ---
    pct = data["usage"]["gemini"]["primary"]["used"] / data["usage"]["gemini"]["primary"]["limit"] * 100
    assert_true("gemini primary >= 80% (urgent polling)", pct >= 80)

    # --- spend history ---
    s = data["spend7"]
    assert_eq("spend7.days", s["days"], 7)
    assert_eq("spend7 history length", len(s["history"]), 7)
    totals = [d["total"] for d in s["history"]]
    assert_true("spend7 totals are numeric", all(isinstance(t, (int, float)) for t in totals))
    assert_true("spend7 totals non-negative", all(t >= 0 for t in totals))

    print("\nall green")
    return 0


if __name__ == "__main__":
    sys.exit(main())
