# codexbar-omarchy

[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink)](https://github.com/sponsors/joshuaswarren)

> AI coding-provider usage, spend, and reset countdowns in the Omarchy bar.

A polished [Omarchy v4 (Quickshell)](https://omarchy.org/) plugin that wraps
[steipete/CodexBar](https://github.com/steipete/CodexBar)'s `codexbar` CLI and
renders every supported provider as a live bar widget with a real popover —
the macOS CodexBar experience on Omarchy, without the AppKit.

## Upstream credit

All underlying data fetching, provider integrations, OAuth flows, cookie
parsers, spend/cost scans, and the bundled Linux/CLI binaries come from
**Peter Steinberger's [CodexBar](https://github.com/steipete/CodexBar)**
(MIT, © steipete). This plugin is a Quickshell front-end; it does not
reimplement any provider logic.

If CodexBar is useful to you, support upstream:

- Star: <https://github.com/steipete/CodexBar>
- Sponsor: <https://github.com/sponsors/steipete>

The plugin auto-discovers whatever providers your installed `codexbar` build
exposes — new providers appear in the widget automatically on the next
refresh after an upstream release. No plugin update needed for new providers.

## Features

- Per-provider usage bars in the Omarchy bar (Codex, Claude, Cursor, Gemini,
  Copilot, Grok, GroqCloud, OpenRouter, LiteLLM, z.ai, MiniMax, ElevenLabs,
  Mistral, DeepSeek, AWS Bedrock, … — all ~70 of them).
- Reset countdowns (session, weekly, monthly) per provider.
- 7d / 30d spend charts (Codex + Claude local cost scan, OpenAI Admin API,
  OpenRouter, LiteLLM, z.ai, MiniMax, Mistral, AWS Bedrock — whatever your
  build supports).
- Merge-Icons mode: collapse every provider into a single status item with a
  switcher, matching the macOS "Merge Icons" UX.
- Popover panel mirroring the macOS settings → providers view.
- 5-minute Adaptive polling by default (matches upstream default).
- Refresh-on-demand via click + IPC.
- Keyboard switcher (next provider, merge-toggle, refresh).
- Theme-aware — uses `qs.Commons.Color`, `Style`, and `Border` singletons.

## Requirements

- Omarchy v4 ("Quattro") with Quickshell shell.
- `codexbar` CLI installed and on `$PATH`:

  ```bash
  yay -S codexbar-cli        # Arch / Omarchy
  # or
  brew install steipete/tap/codexbar   # Homebrew on Linux
  # or grab a release tarball from https://github.com/steipete/CodexBar/releases
  ```

  Verify with:

  ```bash
  codexbar --version
  codexbar providers list --format json
  ```

- Configure at least one provider with `codexbar config enable --provider <id>`.

## Install

```bash
omarchy plugin add https://github.com/joshuaswarren/codexbar-omarchy.git
omarchy plugin enable joshuaswarren.codexbar
omarchy-shell shell rescanPlugins
```

Then add the widget to a bar section in `~/.config/omarchy/shell.json`:

```json
{
  "bar": {
    "layout": {
      "right": [
        { "id": "joshuaswarren.codexbar" }
      ]
    }
  },
  "plugins": [
    { "id": "joshuaswarren.codexbar" }
  ]
}
```

Reload:

```bash
omarchy-shell shell reloadConfig
```

## Usage

| Action | Effect |
|---|---|
| Click the bar widget | Open the popover panel |
| Hover | Tooltip with current usage + next reset |
| Middle-click | Force refresh now |
| `Ctrl+Alt+C` | Toggle merge-icons mode |
| `Ctrl+Alt+R` | Force refresh all providers |
| Right-click | Settings menu (cadence, merge mode, providers) |

## Architecture

```
┌────────────────────┐    ┌─────────────────────┐    ┌────────────────────┐
│ CodexBarService.qml│ ── │ providers/cli.js    │ ── │ codexbar CLI       │
│ (kind: service)    │    │ JSON adapter        │    │ (upstream binary)  │
│ - polls every 5min │    │                     │    │                    │
│ - holds state      │    └─────────────────────┘    └────────────────────┘
│ - broadcasts via   │
│   IpcHandler       │
└────────┬───────────┘
         │ broadcasts to
         ▼
┌────────────────────┐    ┌────────────────────┐
│ CodexBarBar.qml    │    │ CodexBarPanel.qml  │
│ (kind: bar-widget) │    │ (kind: panel)      │
│ single | merged    │    │ - usage bars       │
└────────────────────┘    │ - spend chart      │
                          │ - provider switcher│
                          └────────────────────┘
```

### Provider discovery

The widget never hardcodes a provider list. On startup and every config
reload, the poller asks the CLI for the authoritative list:

```bash
codexbar providers list --format json
```

Each provider entry yields an icon (mapped from a built-in fallback table or
overridden in `~/.config/omarchy/plugins/joshuaswarren.codexbar/providers.json`),
display name, and primary usage window. When upstream adds a provider, you
just bump `codexbar-cli` and it shows up — no widget update.

## Development

```bash
git clone https://github.com/joshuaswarren/codexbar-omarchy.git
cd codexbar-omarchy
./scripts/dev-link.sh   # symlinks into ~/.config/omarchy/plugins/joshuaswarren.codexbar
omarchy-shell shell rescanPlugins
```

Save any QML/JS file — the shell hot-reloads.

### Tests

```bash
./scripts/verify.sh         # smoke tests against codexbar CLI
python3 tests/run_tests.py  # fixture-driven parser tests
```

See `docs/PLAN.md` for the full roadmap.

## Support

Every bit of support helps keep codexbar-omarchy alive and free. If you are able, [sponsor on GitHub](https://github.com/sponsors/joshuaswarren) or send a Lightning donation to `joshuaswarren@strike.me` to directly fund continued development and new integrations.

[![Sponsor](https://img.shields.io/badge/Sponsor-%E2%9D%A4-pink?style=for-the-badge)](https://github.com/sponsors/joshuaswarren)

If financial support is not an option, you can still make a big difference: [star the repo](https://github.com/joshuaswarren/codexbar-omarchy), share it, or recommend it to a colleague. Word of mouth is how most people find codexbar-omarchy.

## License

MIT — see [LICENSE](LICENSE).

CodexBar © steipete, MIT. See [docs/UPSTREAM.md](docs/UPSTREAM.md) for full
attribution.