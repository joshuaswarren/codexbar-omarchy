# Plugin manifest schema (v1)

The Omarchy plugin registry (`shell/services/PluginRegistry.qml`) validates:

```jsonc
{
  "schemaVersion": 1,
  "id": "owner.plugin-id",       // no slashes, no leading "..", no leading "/"
  "name": "Human name",
  "version": "semver",
  "author": "Name <email>",
  "description": "One sentence",
  "kinds": ["bar-widget", "service", "panel", "menu"],
  "entryPoints": {
    "barWidget": "relative/path.qml",
    "service":   "relative/path.qml",
    "panel":     "relative/path.qml",
    "menu":      "relative/path.qml"
  },
  "barWidget": {
    "displayName": "...",
    "description": "...",
    "category": "System|Audio|Network|...",
    "defaultSection": "left|center|right",  // optional, default "center"
    "allowMultiple": false
  },
  "keepLoaded": true  // optional, survives summon/hide cycles
}
```

Plugin IDs are namespaced. Our ID `joshuaswarren.codexbar` makes the install land
under `~/.config/omarchy/plugins/joshuaswarren.codexbar/`.

## Lifecycle

| Phase | Trigger | What runs |
|---|---|---|
| Shell start | omarchy-launch-shell | `service` kinds load at startup |
| Add plugin | `omarchy plugin add <url>` | clones into `~/.config/omarchy/plugins/<id>/` |
| Enable | `omarchy plugin enable <id>` | entries written to `~/.config/omarchy/shell.json` (`bar.layout.<section>` or `plugins[]`) |
| Save | any file change in plugin dir | hot-reload — no restart |
| Disable | `omarchy plugin disable <id>` | `disabledPlugins[]` entry |
| Remove | `omarchy plugin remove <id>` | deletes checkout |

## IPC

The shell exposes `omarchy-shell shell …`. Individual plugins register their
own `IpcHandler` targets by `ipcTarget: "<plugin-id>"`. Our targets:

| Target | Methods |
|---|---|
| `joshuaswarren.codexbar` | `refresh`, `toggleMerge`, `nextProvider`, `quit` |
| `joshuaswarren.codexbar.panel` | `open`, `close`, `toggle` |

## Component contracts

### Service

```qml
Item {
  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  // owns state, runs Process/Timer, exposes properties + broadcasts
}
```

### Bar widget

```qml
BarWidget {
  id: root
  moduleName: "joshuaswarren.codexbar"
  // properties consumed by the bar layout
}
```

### Panel

```qml
Panel {
  id: root
  ipcTarget: "joshuaswarren.codexbar.panel"
  function open(payloadJson) { ... }
  function close() { ... }
}
```

### Menu

```qml
Menu {
  id: root
  ipcTarget: "joshuaswarren.codexbar.menu"
  function open(payloadJson) { ... }
  function close() { ... }
}
```
