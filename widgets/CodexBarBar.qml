// widgets/CodexBarBar.qml
//
// Bar widget (kind: "bar-widget") for CodexBar. Two rendering modes:
//
//   - Per-provider (default): one icon + usage bar per enabled provider
//   - Merge-icons (mirror of macOS "Merge Icons"): a single icon + bar for the
//     "active" provider, with a switcher (Ctrl+Alt+C or nextProvider IPC).
//
// Click opens the popover panel; middle-click force-refreshes the poller.
//
// All data comes from the CodexBarService (kind: "service"). The widget itself
// never shells out — it reads `service.usage`, `service.providers`, and
// `service.enabledProviderIds` and reacts to `service.broadcast("updated")`.
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Joshua Warren (joshuaswarren)
// Upstream: https://github.com/steipete/CodexBar (MIT, © steipete)

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import ".." as Root
import "../providers/icons.js" as Icons

BarWidget {
  id: root
  moduleName: "joshuaswarren.codexbar"

  // ---------- service binding ----------
  // The plugin host exposes first-party services via shell.firstPartyServiceFor(<id>).
  // Third-party services are looked up by walking pluginRegistry.
  readonly property var service: {
    if (typeof bar !== "undefined" && bar && bar.shell && typeof bar.shell.firstPartyServiceFor === "function") {
      const s = bar.shell.firstPartyServiceFor("joshuaswarren.codexbar")
      if (s) return s
    }
    return null
  }

  // ---------- visible providers ----------
  // If the service is up, drive from it; otherwise render an empty hint.
  readonly property var providers: service && service.providers ? service.providers : []
  readonly property var enabledIds: service && service.enabledProviderIds ? service.enabledProviderIds : []
  readonly property bool mergeMode: service && service.mergeMode === true

  readonly property var activeProviderName: {
    if (!mergeMode) return ""
    if (!service || enabledIds.length === 0) return ""
    const idx = Math.max(0, Math.min(service.activeIndex || 0, enabledIds.length - 1))
    const id = enabledIds[idx]
    for (let i = 0; i < providers.length; i++) {
      if (providers[i].id === id) return providers[i].name || id
    }
    return id
  }

  readonly property int visibleCount: enabledIds.length
  readonly property bool healthy: service && !service.error && service.lastFetched > 0
  readonly property bool stale: {
    if (!service || !service.lastFetched) return true
    return (Date.now() - service.lastFetched) > (service.currentIntervalMs * 2)
  }

  // ---------- render ----------
  // Per-provider mode: implicit width = N * slotWidth + gap
  // Merge mode: implicit width = 1 * slotWidth
  implicitWidth: mergeMode ? mergeRow.implicitWidth : (visibleCount === 0 ? emptyHint.implicitWidth : row.implicitWidth)
  implicitHeight: Style.bar.statusSlot || 24
  visible: visibleCount > 0 || !service

  // Layouts side-by-side when bar allows, but the bar will collapse them
  // horizontally if there's no space (BarWidget handles overflow).

  Row {
    id: row
    visible: !root.mergeMode && root.visibleCount > 0
    spacing: Style.spacing.controlGap || 4

    Repeater {
      model: root.enabledIds
      delegate: ProviderChip {
        providerId: modelData
        provider: findProvider(modelData)
        usage: findUsage(modelData)
      }
    }
  }

  Row {
    id: mergeRow
    visible: root.mergeMode && root.visibleCount > 0
    spacing: Style.spacing.controlGap || 4

    ProviderChip {
      providerId: root.enabledIds.length > 0 ? root.enabledIds[Math.max(0, Math.min(root.service ? root.service.activeIndex : 0, root.enabledIds.length - 1))] : ""
      provider: findProvider(root.enabledIds.length > 0 ? root.enabledIds[Math.max(0, Math.min(root.service ? root.service.activeIndex : 0, root.enabledIds.length - 1))] : "")
      usage: findUsage(root.enabledIds.length > 0 ? root.enabledIds[Math.max(0, Math.min(root.service ? root.service.activeIndex : 0, root.enabledIds.length - 1))] : "")
      isMerged: true
    }
  }

  Text {
    id: emptyHint
    visible: !root.mergeMode && root.visibleCount === 0 && root.service
    text: root.service && root.service.error ? "codexbar: " + root.service.error : "codexbar: —"
    color: Color.foreground
    opacity: 0.6
    font.pixelSize: Style.font.captionSize || 11
  }

  // ---------- helpers ----------
  function findProvider(id) {
    for (let i = 0; i < root.providers.length; i++) {
      if (root.providers[i].id === id) return root.providers[i]
    }
    return { id: id, name: id, enabled: true, category: "Other" }
  }

  function findUsage(id) {
    return root.service && root.service.usage ? (root.service.usage[id] || null) : null
  }

  function openPanel() {
    if (typeof bar === "undefined" || !bar || !bar.shell) return
    if (typeof bar.shell.summon === "function") {
      bar.shell.summon("joshuaswarren.codexbar.panel", "{}")
    } else if (typeof root.shell === "object" && root.shell && typeof root.shell.summon === "function") {
      root.shell.summon("joshuaswarren.codexbar.panel", "{}")
    }
  }

  function refreshNow() {
    if (root.service && typeof root.service.refresh === "function") {
      root.service.refresh()
    }
  }

  function nextProvider() {
    if (root.service && typeof root.service.nextProvider === "function") {
      root.service.nextProvider()
    }
  }

  // ---------- iframe: react to service broadcasts ----------
  Connections {
    target: root.service
    function onBroadcast(channel, payload) {
      if (channel === "updated" || channel === "activeIndexChanged"
          || channel === "configChanged" || channel === "error") {
        // Property bindings already react; nothing to do here.
      }
    }
  }

  // ---------- global hotkeys (optional) ----------
  // Real hotkey binding is deferred to the menu/panel; the widget stays click-only.

  // ---------- chip delegate ----------
  component ProviderChip: BarIconButton {
    id: chip
    property string providerId: ""
    property var provider: ({})
    property var usage: null
    property bool isMerged: false

    readonly property var primary: usage && usage.primary ? usage.primary : null
    readonly property real pct: primary && primary.limit > 0
      ? Math.max(0, Math.min(100, (primary.used / primary.limit) * 100))
      : 0
    readonly property string glyph: Icons.resolve(provider, root.service ? root.service.userOverrides : ({}))
    readonly property string accent: Icons.accentFor(provider, root.service ? root.service.userOverrides : ({}))

    text: isMerged
      ? (pct > 0 ? glyph + " " + Math.round(pct) + "%" : glyph)
      : glyph
    fontSize: Style.font.caption || 11
    slotSize: Style.bar.statusSlot || 24

    // tint by accent + urgency
    color: pct >= 80 ? Color.urgent : (pct >= 50 ? Color.accent : Color.foreground)

    tooltipText: {
      if (!provider || !provider.id) return "CodexBar"
      const u = usage
      if (!u || !u.primary) return provider.name + ": no data"
      const reset = u.primary.resetAt ? " — resets " + formatReset(u.primary.resetAt) : ""
      return provider.name + ": " + Math.round(pct) + "%" + reset
    }

    onPressed: function (mouse) {
      if (mouse && mouse.button === Qt.MiddleButton) {
        root.refreshNow()
      } else {
        root.openPanel()
      }
    }
    onWheel: function (delta) {
      if (root.mergeMode && delta < 0) root.nextProvider()
      else if (root.mergeMode && delta > 0) root.nextProvider()
    }

    function formatReset(iso) {
      const t = Date.parse(iso)
      if (!Number.isFinite(t)) return iso
      const ms = t - Date.now()
      if (ms <= 0) return "now"
      const m = Math.floor(ms / 60000)
      if (m < 60) return m + "m"
      const h = Math.floor(m / 60)
      if (h < 24) return h + "h"
      return Math.floor(h / 24) + "d"
    }
  }
}
