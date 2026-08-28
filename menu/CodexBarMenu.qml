// menu/CodexBarMenu.qml
//
// Settings menu (kind: "menu") for CodexBar. Surfaces the three things users
// actually want to tweak without leaving the shell:
//   1. Merge-icons mode on/off
//   2. Per-provider enable/disable
//   3. Refresh cadence
//
// Data flows back through CodexBarService IPC; this menu never owns state.
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

Menu {
  id: root
  moduleName: "joshuaswarren.codexbar"
  ipcTarget: "joshuaswarren.codexbar.menu"

  readonly property var service: bar && bar.shell && bar.shell.firstPartyServiceFor
    ? bar.shell.firstPartyServiceFor("joshuaswarren.codexbar") : null

  readonly property var providers: service && service.providers ? service.providers : []
  readonly property var enabledIds: service && service.enabledProviderIds ? service.enabledProviderIds : []
  readonly property var enabledOverrides: service ? service.enabledOverrides : ({})

  function isProviderEnabled(id) {
    if (enabledOverrides[id] === true) return true
    if (enabledOverrides[id] === false) return false
    return enabledIds.indexOf(id) !== -1
  }

  function toggleProvider(id) {
    if (!service) return
    const next = !isProviderEnabled(id)
    if (typeof service.setProviderEnabled === "function") {
      service.setProviderEnabled(id, next)
    }
  }

  function closeMenu() {
    if (bar && bar.shell && typeof bar.shell.hide === "function") {
      bar.shell.hide("joshuaswarren.codexbar.menu")
    }
  }

  implicitWidth: 360
  implicitHeight: contentColumn.implicitHeight + 32

  background: Rectangle {
    color: Color.menu.background || "#1a1a1a"
    radius: Style.radius.lg || 12
    border.color: Color.menu.border || "transparent"
    border.width: 1
  }

  ColumnLayout {
    id: contentColumn
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    Text {
      text: "CodexBar settings"
      color: Color.foreground
      font.pixelSize: Style.font.titleSize || 14
      font.bold: true
    }

    // ---------- merge mode ----------
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Text {
        text: "Merge icons"
        color: Color.foreground
        Layout.fillWidth: true
      }
      Switch {
        checked: service && service.mergeMode === true
        onToggled: if (service) service.toggleMerge()
      }
    }

    // ---------- cadence ----------
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 4
      Text {
        text: "Refresh cadence (seconds)"
        color: Color.foreground
        opacity: 0.7
        font.pixelSize: Style.font.captionSize || 11
      }
      RowLayout {
        spacing: 4
        Repeater {
          model: [60, 300, 600, 1800]
          delegate: Rectangle {
            width: 56
            height: 28
            radius: 6
            color: (service && service.currentIntervalMs === modelData * 1000)
              ? Color.accent : (Color.menu.surface || "#262626")
            Text {
              anchors.centerIn: parent
              text: modelData === 60 ? "1m" : (modelData === 300 ? "5m" : (modelData === 600 ? "10m" : "30m"))
              color: Color.foreground
              font.pixelSize: Style.font.captionSize || 11
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: if (service) service.setCadence(modelData)
            }
          }
        }
      }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: Color.menu.border || "#333" }

    // ---------- provider toggles ----------
    Text {
      text: "Providers"
      color: Color.foreground
      opacity: 0.7
      font.pixelSize: Style.font.captionSize || 11
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 4
      Repeater {
        model: root.providers
        delegate: RowLayout {
          Layout.fillWidth: true
          spacing: 8
          Text {
            text: Icons.resolve(modelData, root.service ? root.service.userOverrides : ({}))
            color: Color.foreground
            font.pixelSize: 14
          }
          Text {
            text: modelData.name || modelData.id
            color: Color.foreground
            Layout.fillWidth: true
          }
          Switch {
            checked: root.isProviderEnabled(modelData.id)
            onToggled: root.toggleProvider(modelData.id)
          }
        }
      }
    }

    // ---------- footer ----------
    RowLayout {
      Layout.fillWidth: true
      BarIconButton {
        text: "↻"
        tooltipText: "Refresh now"
        onPressed: if (root.service) root.service.refresh()
      }
      Text {
        text: root.service && root.service.lastFetched > 0
          ? "Last: " + (new Date(root.service.lastFetched).toLocaleTimeString())
          : "Never fetched"
        color: Color.foreground
        opacity: 0.5
        font.pixelSize: Style.font.captionSize || 11
        Layout.fillWidth: true
      }
      BarIconButton {
        text: "✕"
        tooltipText: "Close"
        onPressed: root.closeMenu()
      }
    }
  }
}
