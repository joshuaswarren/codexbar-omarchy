// poller/CodexBarService.qml
//
// Headless Quickshell service (kind: "service") that polls the upstream
// `codexbar` CLI on an Adaptive cadence, owns the merged provider/usage state,
// and broadcasts updates to bar widgets and panels via `root.broadcast(...)`.
//
// All provider logic (OAuth, cookie parsing, API calls, spend scans) lives in
// https://github.com/steipete/CodexBar. This service is a thin orchestration
// layer: discover → fetch → normalize → fan-out.
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Joshua Warren (joshuaswarren)
// Upstream: https://github.com/steipete/CodexBar (MIT, © steipete)

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import ".." as Root
import "../providers/cli.js" as Cli

Item {
  id: root

  // ---------- injected by the plugin host ----------
  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var manifest: null

  // ---------- public state ----------
  // providers: Array<Provider>, set by discover()
  property var providers: []
  // usage: Object<providerId, Usage>
  property var usage: ({})
  // spend7 / spend30: SpendHistory
  property var spend7:  null
  property var spend30: null
  // lastFetched: timestamp
  property real lastFetched: 0
  // error: last error string, empty when healthy
  property string error: ""
  // mergeMode: user preference (single combined bar vs one bar per provider)
  property bool mergeMode: false
  // activeIndex: which provider is "selected" in the merged switcher
  property int activeIndex: 0
  // enabledProviderIds: which providers to render. Default = all enabled upstream.
  property var enabledProviderIds: []
  // per-provider enabled overrides (user prefs merged onto upstream `enabled`)
  property var enabledOverrides: ({})
  // user override file (reloaded on demand)
  property var userOverrides: ({})

  // ---------- adaptive cadence ----------
  // Upstream defaults to "Adaptive" which is roughly 5 min idle, faster when
  // usage is near a threshold. We mirror that: 5 min baseline, 1 min when any
  // provider is >= 80% of primary window.
  readonly property int baselineIntervalMs: 300000    // 5 min
  readonly property int urgentIntervalMs:   60000     // 1 min
  property int currentIntervalMs: baselineIntervalMs

  // ---------- bootstrap ----------
  Component.onCompleted: {
    loadUserOverrides()
    discoverAndFetch()
  }

  // ---------- helpers ----------
  function broadcast(channel, payload) {
    if (shell && typeof shell.broadcast === "function") {
      shell.broadcast(channel, payload)
    }
  }

  function loadUserOverrides() {
    const path = Quickshell.env("HOME") + "/.config/omarchy/plugins/joshuaswarren.codexbar/providers.json"
    const p = Qt.resolvedUrl("file://" + path)
    const proc = new Process()
    proc.command = ["cat", path]
    proc.stdoutChunks = ""
    proc.stdout.chunks.collect = true
    proc.stdout.chunks.changed.connect(function () {
      proc.stdoutChunks += proc.stdout.chunks.text
    })
    proc.exited.connect(function (code) {
      if (code !== 0) return  // no overrides file is fine
      try {
        const parsed = JSON.parse(proc.stdoutChunks)
        root.userOverrides = parsed.providers || {}
        root.mergeMode = parsed.mergeMode === true
        root.enabledOverrides = parsed.enabled || {}
      } catch (e) {
        console.warn("codexbar-omarchy: bad providers.json:", e)
      }
    })
    proc.start()
  }

  function discoverAndFetch() {
    Cli.listProviders(function (err, list) {
      if (err) {
        root.error = err.message || String(err)
        broadcast("error", { message: root.error })
        return
      }
      root.error = ""
      root.providers = list || []
      root.enabledProviderIds = root.providers.filter(function (p) {
        if (root.enabledOverrides[p.id] === false) return false
        if (root.enabledOverrides[p.id] === true) return true
        return p.enabled !== false
      }).map(function (p) { return p.id })
      fetchAll()
      scheduleNext()
    })
  }

  function fetchAll() {
    if (root.enabledProviderIds.length === 0) {
      root.lastFetched = Date.now()
      broadcast("updated", { ts: root.lastFetched })
      return
    }
    Cli.fetchUsage(root.enabledProviderIds, function (err, map) {
      if (err) {
        root.error = err.message || String(err)
        broadcast("error", { message: root.error })
        return
      }
      root.usage = map || {}
      root.lastFetched = Date.now()
      adaptCadence()
      broadcast("updated", { ts: root.lastFetched, usage: root.usage })
    })
    // Spend: only fetch on first load + every 30 min (heavy scan)
    if (!root.spend7 || !root.spend30 || (Date.now() - spendFetchedAt) > 1800000) {
      fetchSpend()
    }
  }

  property real spendFetchedAt: 0
  function fetchSpend() {
    Cli.fetchSpend(7,  function (e, s) { if (!e) root.spend7  = s })
    Cli.fetchSpend(30, function (e, s) { if (!e) root.spend30 = s; root.spendFetchedAt = Date.now() })
  }

  function adaptCadence() {
    // If any provider is at >= 80% primary, poll more often.
    let urgent = false
    for (let i = 0; i < root.enabledProviderIds.length; i++) {
      const u = root.usage[root.enabledProviderIds[i]]
      if (u && u.primary) {
        const pct = u.primary.limit > 0 ? (u.primary.used / u.primary.limit) * 100 : 0
        if (pct >= 80) { urgent = true; break }
      }
    }
    root.currentIntervalMs = urgent ? urgentIntervalMs : baselineIntervalMs
  }

  function scheduleNext() {
    pollTimer.interval = root.currentIntervalMs
    pollTimer.restart()
  }

  // ---------- IPC ----------
  IpcHandler {
    target: "joshuaswarren.codexbar"

    function refresh(): void {
      root.discoverAndFetch()
    }

    function toggleMerge(): void {
      root.mergeMode = !root.mergeMode
      root.broadcast("configChanged", { mergeMode: root.mergeMode })
    }

    function setMerge(value): void {
      root.mergeMode = value === true || value === "true"
      root.broadcast("configChanged", { mergeMode: root.mergeMode })
    }

    function setProviderEnabled(providerId, enabled): void {
      const next = Object.assign({}, root.enabledOverrides)
      next[providerId] = enabled === true || enabled === "true"
      root.enabledOverrides = next
      // Re-derive enabledProviderIds and refetch.
      root.discoverAndFetch()
    }

    function nextProvider(): void {
      if (!root.mergeMode || root.enabledProviderIds.length === 0) return
      root.activeIndex = (root.activeIndex + 1) % root.enabledProviderIds.length
      root.broadcast("activeIndexChanged", { index: root.activeIndex })
    }

    function setCadence(seconds): void {
      // user can override baseline; urgent cadence stays at 60s
      const n = Number(seconds)
      if (!Number.isFinite(n) || n < 30) return
      // ponytail: we expose this for power users; default stays adaptive
      root.currentIntervalMs = n * 1000
      root.scheduleNext()
    }
  }

  // ---------- timer ----------
  Timer {
    id: pollTimer
    interval: root.currentIntervalMs
    repeat: true
    triggeredOnStart: false
    onTriggered: root.fetchAll()
  }

  // ---------- reload on file change ----------
  FileView {
    id: overridesWatcher
    path: Quickshell.env("HOME") + "/.config/omarchy/plugins/joshuaswarren.codexbar/providers.json"
    watchChanges: true
    onLoaded: root.loadUserOverrides()
    onFileChanged: root.loadUserOverrides()
  }
}
