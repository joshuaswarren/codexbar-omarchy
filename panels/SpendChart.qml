// panels/SpendChart.qml
//
// 7d / 30d spend chart for CodexBar. Pulls spend history from the service and
// renders a simple bar chart (no external chart library; Quickshell/Qt
// rectangles + Canvas would both work; we use the lighter Rectangle approach
// to keep the panel responsive).
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Joshua Warren (joshuaswarren)

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons

Item {
  id: root
  property var service: null
  property int windowDays: 7

  readonly property var history: {
    if (!service) return null
    return windowDays === 30 ? service.spend30 : service.spend7
  }
  readonly property real maxTotal: {
    if (!history || !history.history || history.history.length === 0) return 0
    let m = 0
    for (let i = 0; i < history.history.length; i++) {
      if (history.history[i].total > m) m = history.history[i].total
    }
    return m
  }
  readonly property string currency: history && history.currency ? history.currency : "USD"
  readonly property real todayTotal: {
    if (!history || !history.history || history.history.length === 0) return 0
    return history.history[history.history.length - 1].total
  }

  implicitHeight: 80

  ColumnLayout {
    anchors.fill: parent
    spacing: 4

    RowLayout {
      Layout.fillWidth: true
      Text {
        text: "Spend (" + root.windowDays + "d)"
        color: Color.foreground
        opacity: 0.7
        font.pixelSize: Style.font.captionSize || 11
        Layout.fillWidth: true
      }
      Text {
        text: root.todayTotal.toFixed(2) + " " + root.currency
        color: Color.foreground
        font.pixelSize: Style.font.captionSize || 11
        font.bold: true
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      color: "transparent"

      Row {
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.bottomMargin: 4
        spacing: 2

        Repeater {
          model: root.history && root.history.history ? root.history.history : []
          delegate: Item {
            width: parent ? Math.max(2, (parent.width - (root.history.history.length - 1) * 2) / Math.max(1, root.history.history.length)) : 4
            height: parent ? parent.height : 0

            Rectangle {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              height: root.maxTotal > 0 ? Math.max(2, parent.height * (modelData.total / root.maxTotal)) : 2
              color: Color.accent
              radius: 2
              opacity: 0.85
              Behavior on height { NumberAnimation { duration: 200 } }
            }
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: !root.history || !root.history.history || root.history.history.length === 0
      text: "No spend history yet"
      color: Color.foreground
      opacity: 0.4
      font.pixelSize: Style.font.captionSize || 10
    }
  }
}
