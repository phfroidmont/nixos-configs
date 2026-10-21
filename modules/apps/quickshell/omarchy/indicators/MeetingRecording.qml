import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property string meetingState: "idle"

  active: meetingState === "recording" || meetingState === "transcribing"
  activeText: meetingState === "transcribing" ? "󰔟" : "󰡉"
  inactiveText: "󰡉"
  activeTooltipText: meetingState === "transcribing" ? "Transcribing meeting" : "Stop meeting recording"
  inactiveTooltipText: "Record Meeting"

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() { root.refresh() }
  }

  Process {
    id: statusProc
    command: ["fos", "capture", "meeting", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.meetingState = text.trim() || "idle"
    }
  }

  Process {
    id: actionProc
    command: ["fos", "capture", "meeting", "toggle"]
    onExited: root.refresh()
  }

  Timer {
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onPressed: function() {
    if (!actionProc.running) actionProc.running = true
  }
}
