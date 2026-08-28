# Upstream attribution

This plugin is a Quickshell front-end for the
**[CodexBar](https://github.com/steipete/CodexBar)** project by Peter
Steinberger (`steipete`) and contributors.

## What comes from upstream

- **All provider integrations** — Codex, OpenAI, Azure OpenAI, Claude,
  Cursor, OpenCode, Alibaba Coding/Token Plan, Qwen Cloud, Gemini,
  Antigravity, Droid, Copilot, Devin, z.ai, Manus, MiniMax, T3 Chat,
  ZoomMate, Kimi, Kilo, Kiro, Vertex AI, Augment, Amp, Ollama, Synthetic,
  JetBrains AI, Warp, ElevenLabs, OpenRouter, Windsurf, Zed, Perplexity,
  Xiaomi MiMo, Doubao, Sakana AI, Abacus AI, Mistral, DeepSeek, Fireworks,
  DeepInfra, Moonshot, Venice, Codebuff, Crof, Command Code, Qoder,
  StepFun, AWS Bedrock, Grok, GroqCloud, LLM Proxy, ClawRouter, sub2api,
  Wayfinder, LiteLLM, Deepgram, Poe, Chutes, Neuralwatt, ZenMux, xAI,
  IBM Bob.
- **Provider state polling logic** (Adaptive cadence, incident badges).
- **Local cost scan** for Codex + Claude (SQLite WAL store).
- **CLI surface** (`codexbar providers list`, `codexbar config …`,
  `codexbar cost --format json`).
- **Linux/glibc and Linux/musl binaries** shipped in the CodexBar release
  tarball — `codexbar-cli` on AUR wraps these.

## What this plugin adds

- A Quickshell `service` that runs the poller at startup, owns state, and
  broadcasts updates to the bar/panel/menu via IPC.
- A Quickshell `bar-widget` that renders provider icons + usage bars + reset
  countdowns in the Omarchy bar.
- A Quickshell `panel` that opens on click and shows the macOS-style popover
  (usage bars, reset windows, 7d/30d spend chart, provider switcher).
- A Quickshell `menu` for cadence / merge-mode / provider toggles.
- Theme integration via `qs.Commons.Color`, `Style`, `Border`.
- `process.spawn` adapter that shells out to `codexbar … --format json` and
  parses the response. **Zero reimplementation of provider logic.**

## Upstream links

- Repo: <https://github.com/steipete/CodexBar>
- Releases: <https://github.com/steipete/CodexBar/releases>
- CLI docs: <https://github.com/steipete/CodexBar/blob/main/docs/cli.md>
- Configuration: <https://github.com/steipete/CodexBar/blob/main/docs/cli-configuration.md>
- AUR `codexbar-cli`: <https://aur.archlinux.org/packages/codexbar-cli>
- Sponsor: <https://github.com/sponsors/steipete>

## License compatibility

CodexBar is MIT. This plugin is MIT. Compatible.

## Trademarks

"CodexBar" and the CodexBar logo are trademarks of Peter Steinberger. This
plugin is an unofficial community integration; it is not affiliated with,
endorsed by, or sponsored by the CodexBar project beyond the standard MIT
grant.

## Privacy

CodexBar is privacy-first: it reuses existing provider sessions (OAuth,
cookies, API keys) and never stores passwords. **This plugin does not
collect, store, transmit, or analyze any usage data.** All data flows
directly between the `codexbar` binary and the local Quickshell process.

The provider list shown in the widget is rendered from the local
`~/.config/codexbar/config.json` plus the running providers list returned
by the CLI. The macOS app's adaptive agent-aware mode is **not** exposed by
this plugin — we do not read process lists.
