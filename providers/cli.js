// providers/cli.js
//
// CLI adapter for the upstream `codexbar` binary. This file shells out — it does
// NOT reimplement provider logic. All provider integrations live in
// https://github.com/steipete/CodexBar; this adapter just spawns its CLI and
// parses the JSON it returns.
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Joshua Warren (joshuaswarren)
// Upstream: https://github.com/steipete/CodexBar (MIT, © steipete)

.pragma library

const CODEXBAR = "codexbar"  // resolved via $PATH; AUR package `codexbar-cli` installs this
const DEFAULT_TIMEOUT_MS = 8000

// run(args, callback, timeoutMs)
// callback(err, parsedJson|null, rawText)
function run(args, callback, timeoutMs) {
  const proc = new Process()
  proc.command = [CODEXBAR].concat(args)
  proc.stdoutChunks = ""
  proc.stderrChunks = ""
  proc.timeoutMs = timeoutMs || DEFAULT_TIMEOUT_MS
  proc.timedOut = false

  proc.stdout.chunks.collect = true
  proc.stderr.chunks.collect = true

  proc.started.connect(function () {})
  proc.stderr.chunks.changed.connect(function () {
    proc.stderrChunks += proc.stderr.chunks.text
  })
  proc.stdout.chunks.changed.connect(function () {
    proc.stdoutChunks += proc.stdout.chunks.text
  })

  proc.exited.connect(function (exitCode, exitStatus) {
    const raw = proc.stdoutChunks
    const err = proc.stderrChunks
    if (proc.timedOut) {
      callback(new Error("codexbar timed out after " + proc.timeoutMs + "ms"), null, raw)
      return
    }
    if (exitCode !== 0) {
      const msg = (err || raw || "").trim().split("\n").pop() || ("exit " + exitCode)
      callback(new Error("codexbar " + args.join(" ") + ": " + msg), null, raw)
      return
    }
    let parsed = null
    if (raw && raw.trim().length > 0) {
      try { parsed = JSON.parse(raw) }
      catch (e) {
        callback(new Error("codexbar returned non-JSON: " + raw.slice(0, 120)), null, raw)
        return
      }
    }
    callback(null, parsed, raw)
  })

  proc.start()
  return proc
}

// listProviders(callback) -> callback(err, Array<Provider>)
//
// Calls `codexbar providers list --format json`. The exact schema is owned by
// upstream; we normalize to a stable internal shape.
//
// Expected upstream schema (best-effort, see docs/cli.md):
//   [
//     {"id":"codex","name":"Codex","enabled":true,"windows":["session","weekly"]},
//     ...
//   ]
//
// If upstream's schema differs, the adapter fills in sensible defaults so the
// UI degrades gracefully.
function listProviders(callback) {
  run(["providers", "list", "--format", "json"], function (err, json) {
    if (err) { callback(err, null); return }
    if (!Array.isArray(json)) {
      callback(new Error("providers list did not return an array"), null)
      return
    }
    const out = []
    for (let i = 0; i < json.length; i++) {
      const p = json[i] || {}
      out.push(normalizeProvider(p))
    }
    callback(null, out)
  })
}

// fetchUsage(providerIds, callback) -> callback(err, Object<providerId, Usage>)
//
// Calls `codexbar usage --format json --provider <id>` for each id and merges
// results. Upstream may also expose a bulk `codexbar usage --all --format json`;
// if so, prefer that (one process, lower overhead). Fall back to per-provider.
//
// Expected upstream schema (per provider):
//   {
//     "provider": "codex",
//     "primary": { "used": 73, "limit": 100, "unit": "%", "resetAt": "..." },
//     "windows": [
//       {"name":"session","used":12,"limit":100,"unit":"%","resetAt":"..."},
//       {"name":"weekly","used":40,"limit":100,"unit":"%","resetAt":"..."}
//     ],
//     "spend": {"today":1.23,"week":7.89,"month":31.0,"currency":"USD"},
//     "status": "ok|warning|incident|error",
//     "message": ""
//   }
function fetchUsage(providerIds, callback) {
  if (!providerIds || providerIds.length === 0) {
    callback(null, {})
    return
  }
  run(["usage", "--format", "json", "--all"], function (err, json) {
    if (!err && json && typeof json === "object" && !Array.isArray(json)) {
      // Bulk shape: { providers: { id: Usage } } or { id: Usage }
      const bag = (json.providers && typeof json.providers === "object") ? json.providers : json
      const out = {}
      for (let i = 0; i < providerIds.length; i++) {
        const id = providerIds[i]
        out[id] = bag[id] ? normalizeUsage(bag[id], id) : null
      }
      callback(null, out)
      return
    }
    // Fallback: per-provider sequential fan-out.
    const out = {}
    let pending = providerIds.length
    let failed = false
    for (let i = 0; i < providerIds.length; i++) {
      const id = providerIds[i]
      run(["usage", "--format", "json", "--provider", id], function (e, u) {
        if (failed) return
        if (e) { failed = true; callback(e, null); return }
        out[id] = u ? normalizeUsage(u, id) : null
        pending--
        if (pending === 0) callback(null, out)
      })
    }
    if (pending === 0) callback(null, out)
  })
}

// fetchSpend(windowDays, callback) -> callback(err, SpendHistory)
//
// Window is 7 or 30. Returns an array of { date, total, currency, byProvider }.
// Falls back to empty if upstream does not expose history yet.
function fetchSpend(windowDays, callback) {
  run(["spend", "--format", "json", "--days", String(windowDays)], function (err, json) {
    if (err) { callback(err, null); return }
    if (!json) { callback(null, emptySpend(windowDays)); return }
    callback(null, normalizeSpend(json, windowDays))
  })
}

// ---------- internal helpers ----------

function normalizeProvider(p) {
  return {
    id: String(p.id || p.provider || ""),
    name: String(p.name || p.displayName || p.id || ""),
    enabled: p.enabled !== false && p.disabled !== true,
    windows: Array.isArray(p.windows) ? p.windows.slice() : [],
    category: p.category || inferCategory(p.id),
    icon: p.icon || null,            // upstream may supply an icon name
    accentColor: p.accentColor || null,
    source: p.source || null         // "cli" | "oauth" | "browser" | "api-key"
  }
}

function normalizeUsage(u, id) {
  if (!u || typeof u !== "object") return null
  const primary = u.primary || pickPrimaryWindow(u.windows) || null
  return {
    provider: id,
    primary: primary,
    windows: Array.isArray(u.windows) ? u.windows.map(normalizeWindow) : [],
    spend: u.spend ? normalizeSpendUsage(u.spend) : null,
    status: u.status || "ok",
    message: u.message || "",
    fetchedAt: Date.now()
  }
}

function normalizeWindow(w) {
  return {
    name: String(w.name || w.label || "session"),
    used: num(w.used, 0),
    limit: num(w.limit, 100),
    unit: w.unit || "%",
    resetAt: w.resetAt || w.reset || null
  }
}

function normalizeSpendUsage(s) {
  return {
    today: num(s.today, 0),
    week: num(s.week, 0),
    month: num(s.month, 0),
    currency: s.currency || "USD"
  }
}

function normalizeSpend(json, days) {
  if (Array.isArray(json)) {
    return { days: days, history: json, currency: json[0] && json[0].currency || "USD" }
  }
  if (json.history && Array.isArray(json.history)) {
    return { days: days, history: json.history, currency: json.currency || "USD" }
  }
  return emptySpend(days)
}

function emptySpend(days) {
  const now = new Date()
  const history = []
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date(now.getTime() - i * 86400000)
    history.push({ date: d.toISOString().slice(0, 10), total: 0, byProvider: {} })
  }
  return { days: days, history: history, currency: "USD" }
}

function pickPrimaryWindow(windows) {
  if (!Array.isArray(windows) || windows.length === 0) return null
  // Prefer "session" by name, else first.
  for (let i = 0; i < windows.length; i++) {
    if (String(windows[i].name || "").toLowerCase() === "session") return normalizeWindow(windows[i])
  }
  return normalizeWindow(windows[0])
}

function inferCategory(id) {
  if (!id) return "Other"
  const s = String(id).toLowerCase()
  if (s.indexOf("claude") !== -1 || s === "codex" || s === "copilot" || s === "cursor"
      || s === "kiro" || s === "zed" || s === "kilo" || s === "roo" || s === "cline"
      || s === "devin" || s === "droid" || s === "kiro" || s === "kilo"
      || s === "windsurf" || s === "augment" || s === "opencode"
      || s === "antigravity" || s === "qoder" || s === "command"
      || s === "codebuff" || s === "amp" || s === "alibaba") return "Coding agent"
  if (s.indexOf("gpt") !== -1 || s === "openai" || s === "azure" || s === "gemini"
      || s === "grok" || s === "deepseek" || s === "mistral" || s === "moonshot"
      || s === "kimi" || s === "doubao" || s === "ollama" || s === "groq"
      || s.indexOf("llama") !== -1) return "Model API"
  if (s === "elevenlabs" || s === "deepgram") return "Voice / Audio"
  if (s === "openrouter" || s === "litellm" || s === "llm-proxy" || s === "clawrouter"
      || s === "sub2api" || s === "wayfinder") return "Gateway"
  if (s === "aws" || s.indexOf("bedrock") !== -1 || s === "vertex" || s === "fireworks"
      || s === "deepinfra" || s === "venice" || s === "synthetic" || s === "together"
      || s === "replicate") return "Cloud"
  return "Other"
}

function num(v, dflt) {
  const n = Number(v)
  return Number.isFinite(n) ? n : dflt
}
