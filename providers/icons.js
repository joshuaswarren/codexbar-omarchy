// providers/icons.js
//
// Icon resolution for the ~70 providers upstream exposes. We start from an
// inline Nerd Font fallback table (no extra deps, no async icon lookup), then
// let users override via `~/.config/omarchy/plugins/joshuaswarren.codexbar/providers.json`.
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Joshua Warren (joshuaswarren)

.pragma library

// Nerd Font glyphs as a portable default. Users can swap to Material/tabler
// icons by overriding `icon` per provider in their providers.json.
const ICONS = {
  // coding agents
  codex:       "\uf135",  //  — Codex (fa-terminal)
  claude:      "\ue8d6",  //  — md-robot
  cursor:      "\uf178",  //  — fa-i-cursor
  copilot:     "\uf09b",  //  — fa-github
  devin:       "\uf544",  //  — fa-robot
  droid:       "\ue6f0",  //  — fa-android-alt
  opencode:    "\uf121",  //  — fa-code
  opencode_go: "\uf121",
  antigravity: "\ue6f0",
  windsurf:    "\uf72a",  //  — fa-water
  augment:     "\uf0fe",  //  — fa-plus-circle
  kiro:        "\uf135",
  zed:         "\uf121",
  kilo:        "\uf0c8",  //  — fa-square
  cline:       "\uf121",
  command:     "\uf120",  //  — fa-terminal
  codebuff:    "\uf121",
  qoder:       "\uf121",
  amp:         "\uf0e7",  //  — fa-bolt
  alibaba:     "\uf1d4",  //  — fa-globe
  alibaba_coding_plan: "\uf1d4",
  alibaba_token_plan:  "\uf1d4",
  roo:         "\uf121",
  manus:       "\uf544",
  // model apis
  openai:      "\uf135",
  azure:       "\ue624",  //  — md-cloud
  azure_openai:"\ue624",
  gemini:      "\ueb3a",  //  — md-auto-awesome
  grok:        "\ue6f0",
  deepseek:    "\uf1d4",
  mistral:     "\ue6f0",
  moonshot:    "\uf186",  //  — fa-moon
  kimi:        "\uf186",
  doubao:      "\uf1d4",
  ollama:      "\ue6f0",
  groq:        "\ue6f0",
  groqcloud:   "\ue6f0",
  llama:       "\ue6f0",
  // voice / audio
  elevenlabs:  "\uf028",  //  — fa-volume-up
  deepgram:    "\uf028",
  // gateways / proxies
  openrouter:  "\uf362",  //  — fa-route
  litellm:     "\uf362",
  llm_proxy:   "\uf362",
  clawrouter:  "\uf362",
  sub2api:     "\uf362",
  wayfinder:  "\uf362",
  zenmux:      "\uf362",
  chutes:      "\uf362",
  neuralwatt:  "\uf0e7",
  // cloud
  aws:         "\ue624",
  bedrock:     "\ue624",
  vertex:      "\ueb3a",
  fireworks:  "\uf1d4",
  deepinfra:  "\uf1d4",
  venice:     "\uf1d4",
  synthetic:   "\uf0c8",
  jetbrains:   "\uf121",
  ibm:         "\uf1d4",
  ibm_bob:     "\uf1d4",
  // misc
  perplexity:  "\uf002",  //  — fa-search
  poe:         "\uf086",  //  — fa-comment
  abacus:      "\uf1d4",
  sakana:      "\uf1d4",
  xiaomi:      "\uf1d4",
  mimo:        "\uf1d4",
  devin:       "\uf544",
  factory:     "\uf0ad",  //  — fa-wrench
  crof:        "\uf1d4",
  stepfun:     "\uf1d4",
  command_code:"\uf120",
  opencode_go: "\uf121",
  zai:         "\uf1d4",
  zoommate:    "\uf1d4",
  t3:          "\uf086",
  t3chat:      "\uf086",
  qwen:        "\uf1d4",
  qwen_cloud:  "\uf1d4",
  warp:        "\ue6f0",
  default:     "\uf0ad"   //  — fa-wrench
}

// userOverride: optional path to user's providers.json
// provider: { id, ... } (upstream-normalized)
// returns: a string suitable for Qt.font.glyph or unicode display
function resolve(provider, userOverride) {
  if (!provider || !provider.id) return ICONS.default
  // explicit upstream-provided icon wins
  if (provider.icon) return provider.icon
  // user override layer
  const userMap = userOverride || {}
  const u = userMap[provider.id]
  if (u && u.icon) return u.icon
  // category fallback
  if (provider.category === "Coding agent") return "\uf121"
  if (provider.category === "Model API")    return "\uf135"
  if (provider.category === "Voice / Audio")return "\uf028"
  if (provider.category === "Gateway")      return "\uf362"
  if (provider.category === "Cloud")        return "\ue624"
  // lookup
  return ICONS[provider.id] || ICONS.default
}

// accentColor: same priority
function accentFor(provider, userOverride) {
  const u = (userOverride || {})[provider.id]
  if (u && u.accentColor) return u.accentColor
  if (provider.accentColor) return provider.accentColor
  // category default
  switch (provider.category) {
    case "Coding agent": return "#a78bfa"
    case "Model API":    return "#60a5fa"
    case "Voice / Audio":return "#34d399"
    case "Gateway":      return "#fbbf24"
    case "Cloud":        return "#f472b6"
    default:             return "#94a3b8"
  }
}
