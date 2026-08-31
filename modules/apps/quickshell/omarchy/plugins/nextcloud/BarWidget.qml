import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "phfroidmont.nextcloud"

  readonly property var nextcloud: bar?.shell?.firstPartyServiceFor("phfroidmont.nextcloud")
  readonly property bool unavailable: !nextcloud || nextcloud.state === "unavailable"

  visible: !(setting("hideWhenUnavailable", false) === true && unavailable)
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function run(executable, argument) {
    if (!executable) return
    var command = [executable]
    if (argument) command.push(argument)
    Quickshell.execDetached(command)
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.nextcloud ? root.nextcloud.icon : "\uf0c2"
    slotSize: Style.bar.statusSlot
    tooltipText: root.nextcloud ? root.nextcloud.tooltip : "Nextcloud unavailable"
    opacity: root.unavailable ? 0.45 : 1.0

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) {
        root.run(Quickshell.env("NEXTCLOUD_OPEN"))
      } else if ((buttonCode === Qt.MiddleButton || buttonCode === Qt.RightButton)
          && root.nextcloud && root.nextcloud.folderPath) {
        root.run(Quickshell.env("NEXTCLOUD_OPEN_FOLDER"), root.nextcloud.folderPath)
      }
    }
  }
}
