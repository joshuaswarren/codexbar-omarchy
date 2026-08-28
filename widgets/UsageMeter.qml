// widgets/UsageMeter.qml
//
// Reusable usage meter component. Renders a label + filled bar + percentage,
// tinted by accent and urgency. Used in both the bar chip and the popover.
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Joshua Warren (joshuaswarren)

import QtQuick
import Quickshell
import qs.Commons

Item {
  id: root
  property string label: ""
  property string sublabel: ""
  property real used: 0
  property real limit: 100
  property string resetAt: ""
  property string accent: Color.accent || "#60a5fa"
  property bool compact: false
  property bool showLabel: true

  readonly property real pct: limit > 0 ? Math.max(0, Math.min(100, (used / limit) * 100)) : 0
  readonly property bool urgent: pct >= 80
  readonly property bool warning: pct >= 50 && pct < 80
  readonly property string barColor: urgent ? Color.urgent : (warning ? accent : accent)

  implicitWidth: compact ? 64 : (showLabel ? Math.max(180, label.length * 8) : 120)
  implicitHeight: compact ? 16 : 28

  Column {
    anchors.fill: parent
    spacing: 2

    Row {
      visible: root.showLabel && !root.compact
      width: parent.width
      Text {
        text: root.label
        color: Color.foreground
        font.pixelSize: Style.font.captionSize || 11
      }
      Item { width: parent.width - leftLabel.implicitWidth - rightLabel.implicitWidth - sublabelText.implicitWidth; height: 1 }
      Text {
        id: leftLabel
        text: Math.round(root.pct) + "%"
        color: root.urgent ? Color.urgent : Color.foreground
        font.pixelSize: Style.font.captionSize || 11
      }
      Text {
        text: " · " + root.sublabel
        color: Color.foreground
        opacity: 0.6
        font.pixelSize: Style.font.captionSize || 11
      }
      Text {
        id: sublabelText
        text: root.resetAt ? " · " + formatReset(root.resetAt) : ""
        color: Color.foreground
        opacity: 0.6
        font.pixelSize: Style.font.captionSize || 11
      }
    }

    Rectangle {
      width: parent.width
      height: root.compact ? 4 : 6
      radius: height / 2
      color: Color.background || "#1f2937"
      border.color: Color.border || "transparent"
      border.width: 0

      Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * (root.pct / 100)
        radius: parent.radius
        color: root.barColor
        Behavior on width { NumberAnimation { duration: 250 } }
      }
    }
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
