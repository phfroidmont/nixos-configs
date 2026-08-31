import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Scope {
  id: root

  property alias query: searchInput.text
  property int selectedIndex: 0
  property bool pendingShow: false
  property var iconIndex: ({})
  property var pendingIconIndex: ({})

  readonly property var filteredApplications: {
    const needle = query.trim().toLowerCase()
    const applications = DesktopEntries.applications.values.slice()

    applications.sort((left, right) => left.name.localeCompare(right.name))
    if (!needle)
      return applications

    return applications.filter(application => {
      const keywords = application.keywords ? application.keywords.join(" ") : ""
      const searchText = [
        application.name,
        application.genericName,
        application.comment,
        keywords
      ].join(" ").toLowerCase()

      return searchText.includes(needle)
    })
  }

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

  function moveSelection(offset) {
    const count = filteredApplications.length
    if (count === 0)
      return

    selectedIndex = (selectedIndex + offset + count) % count
    resultList.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function launchSelected() {
    const application = filteredApplications[selectedIndex]
    if (!application)
      return

    hide()
    if (application.runInTerminal) {
      const terminal = Quickshell.env("LAUNCHER_TERMINAL")
      if (terminal) {
        const command = []
        const workingDirectory = String(application.workingDirectory || "")
        const environment = Quickshell.env("LAUNCHER_ENV")
        if (environment) {
          command.push(environment)
          if (workingDirectory)
            command.push("-C", workingDirectory)
        }
        command.push(terminal, "-e")
        for (let index = 0; index < application.command.length; index++)
          command.push(application.command[index])
        Quickshell.execDetached(command)
      } else {
        application.execute()
      }
    } else if (Quickshell.env("LAUNCHER_ENV") && application.command.length > 0) {
      const command = [Quickshell.env("LAUNCHER_ENV")]
      const workingDirectory = String(application.workingDirectory || "")
      if (workingDirectory)
        command.push("-C", workingDirectory)
      for (let index = 0; index < application.command.length; index++)
        command.push(application.command[index])
      Quickshell.execDetached(command)
    } else {
      application.execute()
    }
  }

  function indexIcon(path) {
    const value = String(path || "").trim()
    if (!value)
      return

    const slash = value.lastIndexOf("/")
    const fileName = slash >= 0 ? value.slice(slash + 1) : value
    const extension = fileName.lastIndexOf(".")
    const iconName = extension > 0 ? fileName.slice(0, extension) : fileName

    if (iconName && pendingIconIndex[iconName] === undefined)
      pendingIconIndex[iconName] = value
  }

  function iconSource(icon) {
    const value = String(icon || "")
    if (!value)
      return Quickshell.iconPath("application-x-executable", true)
    if (value.startsWith("file://") || value.startsWith("image://"))
      return value
    if (value.startsWith("/"))
      return encodeURI(`file://${value}`)

    const indexedIcon = iconIndex[value]
    if (indexedIcon)
      return encodeURI(`file://${indexedIcon}`)

    const themedIcon = Quickshell.iconPath(value, true)
    if (themedIcon)
      return themedIcon

    return Quickshell.iconPath("application-x-executable", true)
  }

  IpcHandler {
    target: "launcher"

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

  Connections {
    target: DesktopEntries.applications

    function onValuesChanged() {
      if (!iconIndexScan.running)
        iconIndexScan.running = true
    }
  }

  Process {
    id: iconIndexScan

    command: [Quickshell.env("LAUNCHER_ICON_INDEX")]
    stdout: SplitParser { onRead: line => root.indexIcon(line) }
    onStarted: root.pendingIconIndex = ({})
    onRunningChanged: if (!running) root.iconIndex = root.pendingIconIndex
  }

  Component.onCompleted: {
    Hyprland.refreshMonitors()
    iconIndexScan.running = true
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
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Rectangle {
      anchors.fill: parent
      color: "#801d2021"
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.hide()
    }

    Rectangle {
      id: card

      readonly property int contentMargin: 18
      readonly property int headerHeight: 34
      readonly property int contentSpacing: 6
      readonly property int maxListHeight: Math.max(
        50,
        Math.floor(panel.height * 0.7) - contentMargin * 2 - headerHeight - contentSpacing
      )

      width: Math.min(300, panel.width - 28)
      height: contentMargin * 2 + headerHeight + contentSpacing + resultList.height
      anchors.centerIn: parent
      color: "#282828"
      border.width: 2
      border.color: "#fe8019"

      MouseArea {
        anchors.fill: parent
        onClicked: {}
      }

      Column {
        anchors.fill: parent
        anchors.margins: card.contentMargin
        spacing: card.contentSpacing

        Item {
          width: parent.width
          height: card.headerHeight

          Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: searchInput.text.length === 0
            text: "Apps..."
            color: "#fbf1c7"
            opacity: 0.58
            font.family: "monospace"
            font.pixelSize: 16
            elide: Text.ElideRight
          }

          TextInput {
            id: searchInput

            anchors.fill: parent
            color: "#fbf1c7"
            selectionColor: "#3c3836"
            selectedTextColor: "#fbf1c7"
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
              const control = (event.modifiers & Qt.ControlModifier) !== 0

              if (event.key === Qt.Key_Escape) {
                root.hide()
              } else if (event.key === Qt.Key_Down || (control && (event.key === Qt.Key_J || event.key === Qt.Key_N))) {
                root.moveSelection(1)
              } else if (event.key === Qt.Key_Up || (control && (event.key === Qt.Key_K || event.key === Qt.Key_P))) {
                root.moveSelection(-1)
              } else if (event.key === Qt.Key_PageDown || (control && event.key === Qt.Key_D)) {
                root.moveSelection(6)
              } else if (event.key === Qt.Key_PageUp || (control && event.key === Qt.Key_U)) {
                root.moveSelection(-6)
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.launchSelected()
              } else {
                return
              }

              event.accepted = true
            }
          }
        }

        ListView {
          id: resultList

          width: parent.width
          height: Math.min(Math.max(50, contentHeight), card.maxListHeight)
          model: root.filteredApplications
          clip: true
          spacing: 3
          boundsBehavior: Flickable.StopAtBounds

          delegate: Rectangle {
            id: row

            required property int index
            required property var modelData

            width: ListView.view.width
            height: 50
            color: index === root.selectedIndex ? "#14fbf1c7" : "transparent"
            border.width: index === root.selectedIndex ? 1 : 0
            border.color: "#40fbf1c7"

            IconImage {
              id: applicationIcon

              width: 18
              height: 18
              anchors.left: parent.left
              anchors.leftMargin: 17
              anchors.verticalCenter: parent.verticalCenter
              source: root.iconSource(row.modelData.icon)
            }

            Text {
              anchors.left: applicationIcon.right
              anchors.leftMargin: 15
              anchors.right: parent.right
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              text: row.modelData.name
              color: row.index === root.selectedIndex ? "#83a598" : "#fbf1c7"
              font.family: "monospace"
              font.pixelSize: 16
              font.weight: Font.Medium
              elide: Text.ElideRight
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.selectedIndex = row.index
              onClicked: {
                root.selectedIndex = row.index
                root.launchSelected()
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: root.filteredApplications.length === 0
            text: "No applications found"
            color: "#a89984"
            font.family: "monospace"
            font.pixelSize: 12
          }
        }
      }
    }
  }
}
