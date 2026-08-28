# codexbar-omarchy — plan & roadmap

Polished Quickshell plugin for Omarchy v4 that wraps
[steipete/CodexBar](https://github.com/steipete/CodexBar)'s `codexbar` CLI.

## Goals

1. **Full parity with macOS CodexBar.** Per-provider usage meters, reset
   countdowns, spend charts, merge-icons mode, popover panel, settings menu.
2. **Auto-discover upstream providers.** The widget never hardcodes a
   provider list — it queries `codexbar providers list --format json` at
   startup + on every config reload. New upstream providers appear
   automatically on the next refresh after `yay -Syu codexbar-cli`.
3. **Theme-aware.** Uses `qs.Commons.Color`, `Style`, `Border` so the widget
   inherits any Omarchy theme without per-theme code.
4. **Zero reimplementation.** Every provider integration (OAuth, cookies,
   API keys, spend scans, incident polling) is upstream's job. We are a
   presentation layer.

## Phase 0 — Foundation ✅

- [x] `manifest.json` (schemaVersion 1, kinds: bar-widget, service, panel, menu)
- [x] `LICENSE` (MIT)
- [x] `README.md` (install, usage, architecture, upstream credit)
- [x] `docs/UPSTREAM.md` (full attribution)
- [x] `docs/PLUGIN.md` (manifest schema + component contracts)
- [x] `scripts/verify.sh` + `scripts/dev-link.sh`
- [x] `.github/workflows/ci.yml` (manifest validation, shellcheck, smoke)

## Phase 1 — Provider layer ✅

- [x] `providers/cli.js` — spawn adapter wrapping the CLI, parses JSON
- [x] `providers/icons.js` — inline icon table + user override layer
- [x] `poller/CodexBarService.qml` — headless service, Adaptive cadence,
      IPC, broadcasts to widgets
- [x] Fixtures for 65 providers (all categories)
- [x] `tests/run_tests.py` — 250+ assertions on parser logic

## Phase 2 — UI surfaces ✅

- [x] `widgets/CodexBarBar.qml` — per-provider and merge-icons modes
- [x] `widgets/UsageMeter.qml` — reusable bar
- [x] `panels/CodexBarPanel.qml` — popover with switcher + spend chart
- [x] `panels/SpendChart.qml` — 7d/30d chart
- [x] `menu/CodexBarMenu.qml` — cadence, merge toggle, provider list

## Phase 3 — Polish (next)

| Item | Status | Notes |
|---|---|---|
| Real-world smoke test on Omarchy | TODO | needs a running Omarchy box |
| Hover tooltip polish | TODO | match Omarchy tooltip styling |
| Keyboard hotkeys (Ctrl+Alt+C, R) | TODO | bind via menu or bar widget |
| Click-through to provider-specific deep links | TODO | e.g. Claude → claude.ai/settings |
| Spend window toggle (7d ↔ 30d) | TODO | wire from panel footer `$` button |
| macOS-style per-provider icons (not just category glyphs) | TODO | ship PNG/SVG set per provider in `icons/` |
| Refresh-on-window-focus | TODO | bind to Hyprland active window change |
| Notification on urgent threshold | TODO | shell notifications plugin |
| Localization | TODO | mirror upstream's 21-language catalog |
| Auto-install of `codexbar-cli` on `omarchy plugin enable` | TODO | `install.sh` runs `yay -S --needed codexbar-cli` if missing |

## Phase 4 — Distribution

- [ ] First public release `v0.1.0` (after Phase 3 smoke test on real Omarchy)
- [ ] Add screenshots/GIFs to README
- [ ] Cross-link to Omarchy awesome list (`awesome-omarchy.com`)
- [ ] Cross-link to CodexBar README ("Omarchy Quickshell front-end")
- [ ] Optional AUR `omarchy-codexbar-plugin` package

## Verification checklist before first release

- [ ] `scripts/verify.sh` passes on a clean Omarchy install
- [ ] Bar widget renders on first launch, no rescanPlugins needed
- [ ] Click opens panel, panel lists every enabled provider
- [ ] Spend chart shows last 7 days + currency
- [ ] Merge-icons toggle works in popup + persists in `providers.json`
- [ ] Manual refresh updates the bar within 1s
- [ ] Add a new provider upstream → bump codexbar-cli → provider appears
      in the bar without touching the plugin
- [ ] No `*.qml` parse errors in `~/.local/state/quickshell/log/`

## Known limitations

- **Browser-cookie providers** (Cursor, Devin, Mistral, Windsurf, OpenCode,
  many others) require the user to grant Omarchy's browser access to their
  cookie store — we don't bridge that. The user will see "no data" for those
  providers until they sign in via `codexbar config …` (upstream's flow).
- **Adaptive (agent-aware) mode** — the macOS app's optional process-list
  inspection feature — is **not** exposed. We don't read process lists.
  Rationale: privacy + Linux process model is different enough that
  reimplementing upstream's heuristic would be a liability.
- **Sudo-required provider actions** (e.g. some AWS Bedrock flows) are
  best-effort. If the CLI errors, the panel shows the upstream message.

## Per-phase acceptance criteria

| Phase | Pass when |
|---|---|
| 0 | `python3 -c 'json.load(open("manifest.json"))'` succeeds, `bash -n scripts/*.sh` clean, `shellcheck` clean |
| 1 | `python3 tests/run_tests.py` exits 0 |
| 2 | QML parses (visual check on Omarchy) |
| 3 | All "TODO" items above closed, screenshots added |
| 4 | Tagged release, cross-links live, README polished |

## Architectural decisions

1. **CLI subprocess over in-process reimplementation.** Spawning `codexbar`
   keeps us on the right side of the MIT grant (we link via data, not code)
   and means upstream can ship fixes without us merging.
2. **`.js` modules for adapters, `.qml` for UI.** Mirrors the Omarchy
   built-ins (`BarModel.js`, `TrayModel.js`, `BatteryModel.js`). JS has
   clean async + JSON, QML has clean binding + rendering.
3. **Service owns state.** The bar widget is read-only with respect to the
   service. All mutations go through `IpcHandler`, which makes the design
   auditable and lets the menu drive the same source of truth.
4. **Per-provider chips, not a stack.** Per-provider mirrors the macOS
   popover at-a-glance and degrades gracefully as users enable/disable
   providers. Merge-icons mode is opt-in.
5. **No new deps.** Nerd Font glyphs in a JS table. No icon packs, no
   chart libs, no OAuth flows. Lightweight and dependency-free.

## License

MIT. See [LICENSE](../LICENSE).
