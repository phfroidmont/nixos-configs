import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "ClipboardHistory.js" as ClipboardHistory

Scope {
  id: root

  property alias query: searchInput.text
  property int selectedIndex: 0
  property bool pendingShow: false
  property bool clearConfirmOpen: false
  property bool captureInitialized: false
  property bool quarantineRestoresHistory: false
  property var history: []

  readonly property int historyLimit: 500
  readonly property color cardBackground: Color.menu.background
  readonly property color cardBorder: Color.menu.border
  readonly property var cardBorderSpec: Border.surfaceSpec("menu", "border", cardBorder, Math.max(1, Style.space(2)))
  readonly property int cardCornerRadius: Style.cornerRadius
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`
  readonly property string historyPath: `${stateHome}/quickshell/clipboard-history.json`
  readonly property var filteredEntries: ClipboardHistory.displayRows(history, query, 50)
  readonly property var selectedEntry: filteredEntries.length > selectedIndex ? filteredEntries[selectedIndex] : null

  function focusedScreen() {
    const focusedMonitor = Hyprland.focusedMonitor
    if (!focusedMonitor)
      return null

    for (let index = 0; index < Quickshell.screens.length; index++) {
      const screen = Quickshell.screens[index]
      if (Hyprland.monitorFor(screen) === focusedMonitor)
        return screen
    }

    return null
  }

  function show() {
    const screen = focusedScreen()
    if (!screen) {
      pendingShow = true
      Hyprland.refreshMonitors()
      return
    }

    pendingShow = false
    clearConfirmOpen = false
    panel.screen = screen
    query = ""
    selectedIndex = 0
    panel.visible = true
    Qt.callLater(() => {
      resultList.positionViewAtBeginning()
      searchInput.forceActiveFocus()
    })
  }

  function hide() {
    pendingShow = false
    clearConfirmOpen = false
    panel.visible = false
  }

  function toggle() {
    if (panel.visible)
      hide()
    else if (pendingShow)
      pendingShow = false
    else
      show()
  }

  function loadHistory(raw) {
    const valid = ClipboardHistory.isValidHistory(raw)
    if (!valid)
      return false

    const entries = ClipboardHistory.parseHistory(raw)
    let migrated = false
    for (let index = 0; index < entries.length; index++) {
      if (!entries[index].id) {
        entries[index].id = createEntryId()
        migrated = true
      }
    }

    history = entries
    selectedIndex = Math.min(selectedIndex, Math.max(0, filteredEntries.length - 1))
    if (migrated)
      saveHistory()
    return valid
  }

  function saveHistory() {
    historyFile.setText(JSON.stringify(history.slice(0, historyLimit), null, 2) + "\n")
    cleanupTimer.restart()
    cleanupFollowupTimer.restart()
  }

  function createEntryId() {
    const timestamp = Date.now().toString(36)
    const random = Math.random().toString(36).slice(2) + Math.random().toString(36).slice(2)
    return `${timestamp}-${random}`
  }

  function initializeCapture(pruneImages) {
    if (captureInitialized)
      return

    captureInitialized = true
    if (pruneImages)
      pruneProcess.running = true
    else
      quarantineProcess.running = true
  }

  function addClipboardEntry(entry) {
    const normalized = ClipboardHistory.normalizeEntry(entry)
    if (!normalized)
      return

    if (!normalized.id)
      normalized.id = createEntryId()
    history = ClipboardHistory.addEntry(history, normalized, historyLimit)
    saveHistory()
  }

  function addClipboardJson(line) {
    addClipboardEntry(ClipboardHistory.parseEntryJson(line))
  }

  function moveSelection(offset) {
    const count = filteredEntries.length
    if (count === 0)
      return

    selectedIndex = (selectedIndex + offset + count) % count
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function selectIndex(index) {
    if (filteredEntries.length === 0)
      return

    selectedIndex = Math.max(0, Math.min(index, filteredEntries.length - 1))
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function removeSelected() {
    const row = selectedEntry
    if (!row)
      return

    history = ClipboardHistory.removeEntryAt(history, row.index)
    saveHistory()
    selectedIndex = Math.min(selectedIndex, Math.max(0, filteredEntries.length - 1))
  }

  function requestClearHistory() {
    if (history.length > 0)
      clearConfirmOpen = true
  }

  function confirmClearHistory() {
    history = ClipboardHistory.clearHistory()
    selectedIndex = 0
    clearConfirmOpen = false
    Quickshell.execDetached([Quickshell.env("CLIPBOARD_ACTION"), "clear-corrupt-history"])
    saveHistory()
    Qt.callLater(() => searchInput.forceActiveFocus())
  }

  function activateSelected(copyOnly) {
    const row = selectedEntry
    if (!row)
      return

    const entry = history[row.index]
    if (!entry)
      return

    hide()
    const command = [Quickshell.env("CLIPBOARD_ACTION")]
    if (entry.type === "image") {
      command.push("paste-image")
      if (copyOnly)
        command.push("--copy-only")
      command.push(entry.mime, entry.path)
    } else {
      command.push("paste-text")
      if (copyOnly)
        command.push("--copy-only")
      command.push(row.id)
    }
    Quickshell.execDetached(command)
  }

  function openSelected() {
    const row = selectedEntry
    if (!row)
      return

    hide()
    Quickshell.execDetached([Quickshell.env("CLIPBOARD_ACTION"), "open", row.id])
  }

  function editSelected() {
    const row = selectedEntry
    if (!row)
      return

    if (row.entryType !== "image")
      return

    hide()
    Quickshell.execDetached([Quickshell.env("CLIPBOARD_ACTION"), "edit-image", row.id])
  }

  function imageSource(path) {
    const value = String(path || "")
    if (!value)
      return ""
    if (value.startsWith("file://") || value.startsWith("image://"))
      return value
    return "file://" + value.split("/").map(part => encodeURIComponent(part)).join("/")
  }

  IpcHandler {
    target: "clipboard"

    function clear(): void { root.confirmClearHistory() }
    function toggle(): void { root.toggle() }
    function show(): void { root.show() }
    function hide(): void { root.hide() }
  }

  Connections {
    target: Hyprland

    function onFocusedMonitorChanged() {
      if (root.pendingShow && Hyprland.focusedMonitor)
        root.show()
    }
  }

  FileView {
    id: historyFile

    path: root.historyPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      const valid = root.loadHistory(text())
      if (!root.captureInitialized) {
        root.initializeCapture(valid)
      } else if (!valid && !quarantineProcess.running) {
        root.quarantineRestoresHistory = true
        quarantineProcess.running = true
      }
    }
    onLoadFailed: {
      if (!root.captureInitialized) {
        root.loadHistory("[]")
        root.initializeCapture(false)
      } else if (!quarantineProcess.running) {
        root.quarantineRestoresHistory = true
        quarantineProcess.running = true
      }
    }
    onFileChanged: reload()
  }

  Process {
    id: pruneProcess

    command: [Quickshell.env("CLIPBOARD_ACTION"), "prune-images"]
    onExited: {
      cleanupFollowupTimer.restart()
      initProcess.running = true
    }
  }

  Process {
    id: quarantineProcess

    command: [Quickshell.env("CLIPBOARD_ACTION"), "quarantine-history"]
    onExited: {
      if (root.quarantineRestoresHistory) {
        root.quarantineRestoresHistory = false
        root.saveHistory()
      } else {
        initProcess.running = true
      }
    }
  }

  Process {
    id: initProcess

    command: [
      Quickshell.env("CLIPBOARD_PKILL"),
      "-f",
      "wl-paste .*--watch .*clipboard-capture"
    ]
    onExited: {
      currentClipboardProcess.running = true
      textWatchProcess.running = true
      imageWatchProcess.running = true
    }
  }

  Process {
    id: currentClipboardProcess

    command: [Quickshell.env("CLIPBOARD_CAPTURE")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.addClipboardJson(text)
    }
  }

  Process {
    id: textWatchProcess

    command: [
      Quickshell.env("CLIPBOARD_SETPRIV"),
      "--pdeathsig",
      "TERM",
      Quickshell.env("CLIPBOARD_WL_PASTE"),
      "--type",
      "text",
      "--watch",
      Quickshell.env("CLIPBOARD_CAPTURE"),
      "text"
    ]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser { onRead: line => root.addClipboardJson(line) }
  }

  Process {
    id: imageWatchProcess

    command: [
      Quickshell.env("CLIPBOARD_SETPRIV"),
      "--pdeathsig",
      "TERM",
      Quickshell.env("CLIPBOARD_WL_PASTE"),
      "--type",
      "image",
      "--watch",
      Quickshell.env("CLIPBOARD_CAPTURE"),
      "image"
    ]
    onExited: watchRestartTimer.restart()
    stdout: SplitParser { onRead: line => root.addClipboardJson(line) }
  }

  Timer {
    id: watchRestartTimer

    interval: 1000
    repeat: false
    onTriggered: {
      if (!textWatchProcess.running)
        textWatchProcess.running = true
      if (!imageWatchProcess.running)
        imageWatchProcess.running = true
    }
  }

  Timer {
    id: cleanupTimer

    interval: 200
    repeat: false
    onTriggered: Quickshell.execDetached([Quickshell.env("CLIPBOARD_ACTION"), "prune-images"])
  }

  Timer {
    id: cleanupFollowupTimer

    interval: 6000
    repeat: false
    onTriggered: Quickshell.execDetached([Quickshell.env("CLIPBOARD_ACTION"), "prune-images"])
  }

  Component.onCompleted: {
    Hyprland.refreshMonitors()
  }

  PanelWindow {
    id: panel

    visible: false
    anchors {
      top: true
      right: true
      bottom: true
      left: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "clipboard-history"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: "@clipboardScrim@"
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.hide()
    }

    BorderSurface {
      id: card

      readonly property int contentMargin: 18

      width: Math.max(300, Math.min(880, panel.width - 28))
      height: Math.max(260, Math.min(600, panel.height - 28))
      anchors.centerIn: parent
      color: root.cardBackground
      borderSpec: root.cardBorderSpec
      radius: root.cardCornerRadius

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Column {
        anchors.fill: parent
        anchors.margins: card.contentMargin
        spacing: 10

        Item {
          id: searchHeader

          width: parent.width
          height: 36

          Text {
            anchors.left: parent.left
            anchors.right: resultCount.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text.length === 0
            text: "Clipboard..."
            color: "@gruvboxFg@"
            opacity: 0.58
            font.family: "monospace"
            font.pixelSize: 16
            elide: Text.ElideRight
          }

          TextInput {
            id: searchInput

            anchors.left: parent.left
            anchors.right: resultCount.left
            anchors.rightMargin: 12
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: "@gruvboxFg@"
            selectionColor: "@gruvboxBg1@"
            selectedTextColor: "@gruvboxFg@"
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            font.family: "monospace"
            font.pixelSize: 16
            onTextChanged: {
              root.selectedIndex = 0
              resultList.positionViewAtBeginning()
            }

            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
              if (root.clearConfirmOpen) {
                if (event.key === Qt.Key_Escape) {
                  root.clearConfirmOpen = false
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  root.confirmClearHistory()
                }
                event.accepted = true
                return
              }

              if (event.key === Qt.Key_Escape) {
                if (root.query.length > 0)
                  root.query = ""
                else
                  root.hide()
              } else if (event.key === Qt.Key_Delete) {
                if ((event.modifiers & Qt.ShiftModifier) !== 0)
                  root.requestClearHistory()
                else
                  root.removeSelected()
              } else if (event.key === Qt.Key_Down) {
                root.moveSelection(1)
              } else if (event.key === Qt.Key_Up) {
                root.moveSelection(-1)
              } else if (event.key === Qt.Key_PageDown) {
                root.moveSelection(6)
              } else if (event.key === Qt.Key_PageUp) {
                root.moveSelection(-6)
              } else if (event.key === Qt.Key_Home) {
                root.selectIndex(0)
              } else if (event.key === Qt.Key_End) {
                root.selectIndex(root.filteredEntries.length - 1)
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if ((event.modifiers & Qt.ControlModifier) !== 0)
                  root.editSelected()
                else if ((event.modifiers & Qt.AltModifier) !== 0)
                  root.openSelected()
                else
                  root.activateSelected((event.modifiers & Qt.ShiftModifier) !== 0)
              } else {
                return
              }

              event.accepted = true
            }
          }

          Text {
            id: resultCount

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: `${root.filteredEntries.length}/${root.history.length}`
            color: "@gruvboxFgMuted@"
            font.family: "monospace"
            font.pixelSize: 12
          }
        }

        Row {
          id: content

          width: parent.width
          height: parent.height - searchHeader.height - actionHelp.height - parent.spacing * 2
          spacing: 10

          ListView {
            id: resultList

            width: Math.floor((parent.width - parent.spacing) * 0.42)
            height: parent.height
            model: root.filteredEntries
            clip: true
            spacing: 3
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              id: row

              required property int index
              required property var modelData

              width: ListView.view.width
              height: 58
              color: index === root.selectedIndex ? "@clipboardSelection@" : "transparent"
              border.width: index === root.selectedIndex ? 1 : 0
              border.color: "@clipboardSelectionBorder@"

              Rectangle {
                width: 7
                height: 7
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                color: row.modelData.entryType === "image" ? "@gruvboxPurple@" :
                  row.modelData.entryType === "file" ? "@gruvboxGreen@" : "@gruvboxBlue@"
              }

              Column {
                anchors.left: parent.left
                anchors.leftMargin: 30
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                  width: parent.width
                  text: row.modelData.previewText
                  color: row.index === root.selectedIndex ? "@gruvboxBlue@" : "@gruvboxFg@"
                  font.family: "monospace"
                  font.pixelSize: 13
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: row.modelData.entryType.toUpperCase()
                  color: "@gruvboxFgMuted@"
                  font.family: "monospace"
                  font.pixelSize: 10
                  elide: Text.ElideRight
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onPositionChanged: root.selectedIndex = row.index
                onClicked: mouse => {
                  root.selectedIndex = row.index
                  if (mouse.button === Qt.RightButton)
                    root.editSelected()
                  else
                    root.activateSelected(false)
                }
              }
            }

            Text {
              anchors.centerIn: parent
              visible: root.filteredEntries.length === 0
              text: "No clipboard entries"
              color: "@gruvboxFgMuted@"
              font.family: "monospace"
              font.pixelSize: 12
            }
          }

          Rectangle {
            width: parent.width - resultList.width - parent.spacing
            height: parent.height
            color: "@gruvboxBgHard@"
            border.width: 1
            border.color: "@gruvboxBg1@"

            Image {
              anchors.fill: parent
              anchors.margins: 16
              visible: root.selectedEntry && root.selectedEntry.previewImage.length > 0
              source: visible ? root.imageSource(root.selectedEntry.previewImage) : ""
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              cache: false
            }

            Flickable {
              anchors.fill: parent
              anchors.margins: 16
              visible: root.selectedEntry && root.selectedEntry.previewImage.length === 0
              contentWidth: width
              contentHeight: previewText.height
              clip: true

              Text {
                id: previewText

                width: parent.width
                text: root.selectedEntry ? root.selectedEntry.fullText : ""
                color: "@gruvboxFgSoft@"
                font.family: "monospace"
                font.pixelSize: 13
                wrapMode: Text.WrapAnywhere
              }
            }

            Text {
              anchors.centerIn: parent
              visible: !root.selectedEntry
              text: "Clipboard history is empty"
              color: "@gruvboxFgMuted@"
              font.family: "monospace"
              font.pixelSize: 12
            }
          }
        }

        Text {
          id: actionHelp

          width: parent.width
          height: 16
          text: root.selectedEntry && root.selectedEntry.entryType === "image"
            ? "Enter paste  Shift+Enter copy  Ctrl+Enter edit  Alt+Enter open  Delete remove  Shift+Delete clear"
            : "Enter paste  Shift+Enter copy  Alt+Enter open  Delete remove  Shift+Delete clear"
          color: "@gruvboxFgMuted@"
          font.family: "monospace"
          font.pixelSize: 10
          elide: Text.ElideRight
        }
      }

      Rectangle {
        width: Math.min(400, card.width - 40)
        height: 150
        anchors.centerIn: parent
        visible: root.clearConfirmOpen
        z: 10
        color: "@gruvboxBgHard@"
        border.width: 2
        border.color: "@gruvboxOrange@"

        MouseArea {
          anchors.fill: parent
          onClicked: {}
        }

        Column {
          anchors.fill: parent
          anchors.margins: 18
          spacing: 16

          Text {
            width: parent.width
            text: "Clear all clipboard history?"
            color: "@gruvboxFg@"
            horizontalAlignment: Text.AlignHCenter
            font.family: "monospace"
            font.pixelSize: 15
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Rectangle {
              width: 120
              height: 38
              color: "@gruvboxBg1@"

              Text {
                anchors.centerIn: parent
                text: "Cancel"
                color: "@gruvboxFg@"
                font.family: "monospace"
                font.pixelSize: 12
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  root.clearConfirmOpen = false
                  searchInput.forceActiveFocus()
                }
              }
            }

            Rectangle {
              width: 120
              height: 38
              color: "@gruvboxRedDark@"

              Text {
                anchors.centerIn: parent
                text: "Clear"
                color: "@gruvboxFg@"
                font.family: "monospace"
                font.pixelSize: 12
              }

              MouseArea {
                anchors.fill: parent
                onClicked: root.confirmClearHistory()
              }
            }
          }
        }
      }
    }
  }
}
