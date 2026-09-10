import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "phfroidmont.pangolin"
  ipcTarget: "phfroidmont.pangolin"

  readonly property var pangolin: bar?.shell?.firstPartyServiceFor(moduleName)
  readonly property color panelBackground: Color.popups.background
  readonly property color surfaceColor: Style.hoverFillFor(Color.popups.text, Color.accent)
  readonly property color foregroundColor: Color.popups.text
  readonly property color mutedColor: Color.muted
  readonly property color accentColor: Color.accent
  readonly property color errorColor: Color.urgent
  readonly property color connectedColor: Color.pick("pangolin.connected", Color.accent)
  readonly property color unavailableColor: Color.pick("pangolin.unavailable", Color.accent)
  readonly property string currentState: pangolin ? pangolin.state : "unavailable"
  readonly property var currentPeers: pangolin ? pangolin.peers : []
  readonly property color statusColor: currentState === "connected" ? connectedColor
    : currentState === "error" ? errorColor
    : currentState === "unavailable" ? unavailableColor : mutedColor
  readonly property string statusHeading: currentState === "connected" ? "Connected"
    : currentState === "disconnected" ? "Disconnected"
    : currentState === "stopped" ? "Client stopped"
    : currentState === "error" ? "Status error" : "Unavailable"

  function refresh() {
    if (pangolin && pangolin.refresh) pangolin.refresh()
  }

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    tooltipText: ""
    iconComponent: Component {
      Item {
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: "\uf132"
          color: root.statusColor
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: Style.bar.iconFont
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(372), Style.space(380))
    contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (dy === 0) return
        var maximum = Math.max(0, panelFlick.contentHeight - panelFlick.height)
        panelFlick.contentY = Math.max(0, Math.min(maximum, panelFlick.contentY + dy * Style.space(48)))
      }
      onTextKey: function(text) { if (text === "r" || text === "R") root.refresh() }

      Rectangle {
        anchors.fill: parent
        color: root.panelBackground

        Flickable {
          id: panelFlick
          anchors.fill: parent
          contentWidth: width
          contentHeight: contentColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: contentColumn
            width: panelFlick.width
            spacing: Style.space(12)

          Row {
            width: parent.width
            spacing: Style.space(10)

            Item {
              width: Style.space(38)
              height: Style.space(38)
              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: "\uf132"
                color: root.statusColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Style.font.heading
              }
            }

            Column {
              width: parent.width - Style.space(38) - refreshButton.width - parent.spacing * 2
              spacing: Style.space(2)
              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: "Pangolin"
                color: root.foregroundColor
                font.family: Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.statusHeading
                color: root.statusColor
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
                font.bold: true
                elide: Text.ElideRight
              }
              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: root.pangolin && root.pangolin.orgId !== "" ? "Organization: " + root.pangolin.orgId : "Organization: Not reported"
                color: root.mutedColor
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }

            Item {
              id: refreshButton
              width: Style.space(32)
              height: width
              opacity: root.pangolin && root.pangolin.refreshing ? 0.5 : 1
              Text {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: "\uf021"
                color: root.mutedColor
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Style.font.caption
              }
              MouseArea {
                anchors.fill: parent
                enabled: !root.pangolin || !root.pangolin.refreshing
                cursorShape: Qt.PointingHandCursor
                onClicked: root.refresh()
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: root.pangolin && root.pangolin.lastError !== ""
            width: parent.width
            text: root.pangolin ? root.pangolin.lastError : ""
            color: root.errorColor
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Rectangle {
            visible: root.currentState === "stopped"
            width: parent.width
            height: stoppedText.implicitHeight + Style.space(24)
            radius: Style.cornerRadius
            color: root.surfaceColor
            Text {
              id: stoppedText
              textFormat: Text.PlainText
              anchors.fill: parent
              anchors.margins: Style.space(12)
              text: "No client is currently running.\nStart Pangolin in a terminal, then refresh this panel."
              color: root.mutedColor
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
          }

          Column {
            visible: root.currentPeers.length > 0
            width: parent.width
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: "SITES"
              color: root.accentColor
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Column {
              id: siteRows
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: root.currentPeers
                Rectangle {
                  required property var modelData
                  width: siteRows.width
                  height: Style.space(42)
                  radius: Style.cornerRadius
                  color: root.surfaceColor
                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    spacing: Style.space(8)
                    Text {
                      textFormat: Text.PlainText
                      width: parent.width - statusText.implicitWidth - parent.spacing
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.name
                      color: root.foregroundColor
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                    }
                    Text {
                      id: statusText
                      textFormat: Text.PlainText
                      anchors.verticalCenter: parent.verticalCenter
                      text: modelData.status
                      color: modelData.status === "offline" ? root.mutedColor : root.connectedColor
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: root.currentPeers.length === 0 && root.currentState !== "stopped" && root.currentState !== "unavailable"
            width: parent.width
            text: "No sites reported."
            color: root.mutedColor
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          }
        }
      }
    }
  }
}
