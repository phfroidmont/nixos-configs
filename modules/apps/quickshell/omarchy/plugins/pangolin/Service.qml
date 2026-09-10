import QtQuick
import Quickshell
import Quickshell.Io
import "Status.js" as Status

Item {
  id: root

  property var shell: null
  property string state: "unavailable"
  property bool connected: false
  property bool registered: false
  property bool terminated: false
  property string orgId: ""
  property var peers: []
  property string errorCode: ""
  property string lastError: ""
  property bool refreshing: false
  property double lastRefreshedMs: 0

  readonly property string pangolinExecutable: Quickshell.env("PANGOLIN_BIN")
  readonly property string timeoutExecutable: Quickshell.env("PANGOLIN_TIMEOUT_BIN")
  readonly property string icon: "\uf132"

  property bool _processStarted: false

  function shortMessage(value, fallback) {
    var text = String(value || fallback || "").replace(/\s+/g, " ").trim()
    return text.length > 180 ? text.substring(0, 177) + "..." : text
  }

  function setUnavailable(message) {
    state = "unavailable"
    connected = false
    registered = false
    terminated = false
    orgId = ""
    peers = []
    errorCode = ""
    lastError = shortMessage(message, "Pangolin status is unavailable")
    lastRefreshedMs = Date.now()
  }

  function applyStatus(raw) {
    var result = Status.parseStatus(raw)
    if (!result.ok) {
      setUnavailable(result.errorMessage)
      return
    }
    state = result.state
    connected = result.connected
    registered = result.registered
    terminated = result.terminated
    orgId = result.orgId
    peers = result.peers
    errorCode = result.errorCode
    lastError = result.state === "error"
      ? shortMessage(result.errorMessage, result.errorCode !== "" ? "Pangolin error (" + result.errorCode + ")" : "Pangolin reported an error")
      : ""
    lastRefreshedMs = Date.now()
  }

  function refresh() {
    if (statusProcess.running) return
    if (!pangolinExecutable || !timeoutExecutable) {
      setUnavailable("PANGOLIN_BIN and PANGOLIN_TIMEOUT_BIN must be configured")
      return
    }
    _processStarted = false
    refreshing = true
    statusProcess.command = [timeoutExecutable, "-k", "2s", "8s", pangolinExecutable, "status", "--json"]
    statusProcess.running = true
  }

  Timer {
    interval: 15000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProcess
    running: false
    command: []
    stdout: StdioCollector { id: statusStdout; waitForEnd: true }
    stderr: StdioCollector { id: statusStderr; waitForEnd: true }
    onStarted: root._processStarted = true
    onRunningChanged: {
      if (!running && root.refreshing && !root._processStarted) {
        root.refreshing = false
        root.setUnavailable("Pangolin status command could not be started")
      }
    }
    onExited: function(exitCode) {
      root.refreshing = false
      var output = String(statusStdout.text || "")
      var errorOutput = String(statusStderr.text || "")
      var combined = (output + "\n" + errorOutput).trim()
      if (exitCode === 124 || exitCode === 137) {
        root.setUnavailable("Pangolin status timed out")
      } else if (exitCode === 0) {
        root.applyStatus(output)
      } else if (Status.parseStatus(combined).state === "stopped") {
        root.applyStatus(combined)
      } else {
        root.setUnavailable(root.shortMessage(errorOutput || output, "Pangolin status command failed"))
      }
    }
  }
}
