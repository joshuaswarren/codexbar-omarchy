// panels/CodexBarPanel.qml
//
// Popover panel (kind: "panel") for CodexBar. Mirrors the macOS app's popover:
// header with provider switcher, per-provider usage meters for every window,
// a spend chart, and a footer with refresh + open-menu actions.
//
// Data is sourced from the CodexBarService via bar.shell.firstPartyServiceFor.
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Joshua Warren (joshuaswarren)
// Upstream: https://github.com/steipete/CodexBar (MIT, © steipete)

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import ".." as Root
import "../providers/icons.js" as Icons
import "../widgets/UsageMeter.qml" as UM

Panel {
  id: root
  moduleName: "joshuaswarren.codexbar"
  ipcTarget: "joshuaswarren.codexbar.panel"

  // ---------- service binding ----------
  readonly property var service: bar && bar.shell && bar.shell.firstPartyServiceFor
    ? bar.shell.firstPartyServiceFor("joshuaswarren.codexbar") : null

  readonly property var providers: service && service.providers ? service.providers : []
  readonly property var enabledIds: service && service.enabledProviderIds ? service.enabledProviderIds : []
  readonly property int activeIndex: service ? Math.max(0, Math.min(service.activeIndex || 0, Math.max(0, enabledIds.length - 1))) : 0
  readonly property string activeId: enabledIds.length > 0 ? enabledIds[activeIndex] : ""
  readonly property var activeProvider: findProvider(activeId)
  readonly property var activeUsage: service && service.usage ? (service.usage[activeId] || null) : null
  readonly property string activeAccent: activeProvider ? Icons.accentFor(activeProvider, service ? service.userOverrides : ({})) : "#60a5fa"
  readonly property string activeGlyph: activeProvider ? Icons.resolve(activeProvider, service ? service.userOverrides : ({})) : ""

  readonly property int spendWindow: 7

  function findProvider(id) {
    for (let i = 0; i < providers.length; i++) {
      if (providers[i].id === id) return providers[i]
    }
    return null
  }

  function closePanel() {
    if (bar && bar.shell && typeof bar.shell.hide === "function") {
      bar.shell.hide("joshuaswarren.codexbar.panel")
    }
  }

  function openSettings() {
    if (bar && bar.shell && typeof bar.shell.summon === "function") {
      bar.shell.summon("joshuaswarren.codexbar.menu", "{}")
    }
  }

  function nextProvider() {
    if (service && typeof service.nextProvider === "function") service.nextProvider()
  }

  // ---------- panel chrome ----------
  implicitWidth: 460
  implicitHeight: contentColumn.implicitHeight + 32

  background: Rectangle {
    color: Color.popups.background || "#1a1a1a"
    radius: Style.radius.lg || 12
    border.color: Color.popups.border || "transparent"
    border.width: 1
  }

  ColumnLayout {
    id: contentColumn
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    // ---------- header ----------
    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: root.activeGlyph
        color: root.activeAccent
        font.pixelSize: 22
      }
      ColumnLayout {
        spacing: 0
        Layout.fillWidth: true
        Text {
          text: root.activeProvider ? root.activeProvider.name : "CodexBar"
          color: Color.foreground
          font.pixelSize: Style.font.titleSize || 14
          font.bold: true
        }
        Text {
          text: root.activeProvider ? (root.activeProvider.category || "Provider") : ""
          color: Color.foreground
          opacity: 0.6
          font.pixelSize: Style.font.captionSize || 11
        }
      }
      BarIconButton {
        text: "↻"
        tooltipText: "Refresh"
        onPressed: if (root.service) root.service.refresh()
      }
      BarIconButton {
        text: "✕"
        tooltipText: "Close"
        onPressed: root.closePanel()
      }
    }

    // ---------- provider switcher ----------
    Flow {
      Layout.fillWidth: true
      spacing: 4
      visible: root.enabledIds.length > 1

      Repeater {
        model: root.enabledIds
        delegate: Rectangle {
          property string providerId: modelData
          property var provider: root.findProvider(providerId)
          property bool isActive: providerId === root.activeId
          width: 28
          height: 24
          radius: 6
          color: isActive ? (root.activeAccent) : (Color.popups.surface || "#262626")
          border.color: isActive ? Color.urgent : "transparent"
          border.width: isActive ? 1 : 0

          Text {
            anchors.centerIn: parent
            text: provider ? Icons.resolve(provider, root.service ? root.service.userOverrides : ({})) : ""
            color: isActive ? Color.background : Color.foreground
            font.pixelSize: 13
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.service) {
                root.service.activeIndex = index
                if (typeof root.service.broadcast === "function") {
                  root.service.broadcast("activeIndexChanged", { index: index })
                }
              }
            }
          }
        }
      }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Color.popups.border || "#333" }

    // ---------- usage meters ----------
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6

      Repeater {
        model: {
          if (!root.activeUsage || !root.activeUsage.windows) return []
          return root.activeUsage.windows
        }
        delegate: UM.UsageMeter {
          Layout.fillWidth: true
          label: (modelData.name || "session").toUpperCase()
          used: modelData.used
          limit: modelData.limit
          resetAt: modelData.resetAt
          accent: root.activeAccent
        }
      }

      Text {
        Layout.fillWidth: true
        visible: !root.activeUsage || !root.activeUsage.windows || root.activeUsage.windows.length === 0
        text: root.activeUsage && root.activeUsage.status === "error"
          ? "Error: " + (root.activeUsage.message || "unknown")
          : "No data"
        color: Color.foreground
        opacity: 0.5
        font.pixelSize: Style.font.captionSize || 11
      }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Color.popups.border || "#333" }

    // ---------- spend chart ----------
    SpendChart {
      Layout.fillWidth: true
      Layout.preferredHeight: 80
      service: root.service
      windowDays: root.spendWindow
    }

    // ---------- footer ----------
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Text {
        text: root.service && root.service.lastFetched > 0
          ? "Updated " + formatAge(root.service.lastFetched)
          : "—"
        color: Color.foreground
        opacity: 0.5
        font.pixelSize: Style.font.captionSize || 11
        Layout.fillWidth: true
      }
      BarIconButton {
        text: "$"
        tooltipText: "Toggle spend window"
        onPressed: {
          // ponytail: state lives on the panel for now; promote to service if needed
          // (real impl will toggle root.spendWindow between 7 and 30)
        }
      }
      BarIconButton {
        text: "⚙"
        tooltipText: "Settings"
        onPressed: root.openSettings()
      }
    }
  }

  function formatAge(ts) {
    const ms = Date.now() - ts
    if (ms < 0) return "now"
    const s = Math.floor(ms / 1000)
    if (s < 60) return s + "s ago"
    const m = Math.floor(s / 60)
    if (m < 60) return m + "m ago"
    return Math.floor(m / 60) + "h ago"
  }
}
