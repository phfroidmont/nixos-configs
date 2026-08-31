import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property string state: "unavailable"
  property var folders: []
  property string folderPath: ""
  property string tooltip: "Nextcloud unavailable"
  readonly property string icon: state === "syncing" ? "\uf021"
    : state === "error" ? "\uf071" : "\uf0c2"
  readonly property string statusExecutable: Quickshell.env("NEXTCLOUD_STATUS")

  function normalizedState(value) {
    var status = String(value || "").toLowerCase().replace(/[ -]+/g, "_")
    if (status === "idle" || status === "synced" || status === "up_to_date" || status === "ok") return "idle"
    if (status === "syncing" || status === "sync" || status === "in_progress") return "syncing"
    if (status === "error" || status === "failed" || status === "failure" || status === "attention") return "error"
    if (status === "unavailable" || status === "offline" || status === "not_running") return "unavailable"
    return ""
  }

  function normalizedFolders(value) {
    var source = Array.isArray(value) ? value : []
    var result = []
    for (var i = 0; i < source.length; i++) {
      var folder = source[i]
      if (!folder || typeof folder !== "object") continue
      result.push({
        name: String(folder.name || folder.displayName || ""),
        path: String(folder.path || folder.folderPath || folder.localPath || ""),
        state: normalizedState(folder.state || folder.status) || "unavailable",
        message: String(folder.message || folder.statusText || "")
      })
    }
    return result
  }

  function aggregateState(explicitState, folderList) {
    var explicit = normalizedState(explicitState)
    if (explicit !== "") return explicit
    var aggregate = folderList.length > 0 ? "idle" : "unavailable"
    for (var i = 0; i < folderList.length; i++) {
      if (folderList[i].state === "error") return "error"
      if (folderList[i].state === "syncing") aggregate = "syncing"
      else if (folderList[i].state === "unavailable" && aggregate === "idle") aggregate = "unavailable"
    }
    return aggregate
  }

  function defaultTooltip(folderList, aggregate) {
    var labels = {
      unavailable: "Nextcloud unavailable",
      idle: "Nextcloud is up to date",
      syncing: "Nextcloud is syncing",
      error: "Nextcloud sync error"
    }
    var lines = [labels[aggregate]]
    for (var i = 0; i < Math.min(folderList.length, 5); i++) {
      var folder = folderList[i]
      var label = folder.name || folder.path
      if (label) lines.push(label + ": " + (folder.message || folder.state))
    }
    return lines.join("\n")
  }

  function setUnavailable(message) {
    state = "unavailable"
    folders = []
    folderPath = ""
    tooltip = message || "Nextcloud unavailable"
  }

  function applyStatus(raw) {
    try {
      var parsed = JSON.parse(String(raw || "").trim())
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("Expected an object")

      var nextFolders = normalizedFolders(parsed.folders)
      var nextState = aggregateState(parsed.aggregateState || parsed.state || parsed.status, nextFolders)
      var explicitPath = parsed.folderPath || parsed.path || parsed.localPath || ""

      folders = nextFolders
      state = nextState
      folderPath = String(explicitPath || (nextFolders.length > 0 ? nextFolders[0].path : ""))
      tooltip = String(parsed.tooltip || parsed.message || parsed.statusText || defaultTooltip(nextFolders, nextState))
    } catch (error) {
      setUnavailable("Nextcloud status is invalid")
    }
  }

  function refresh() {
    if (statusProcess.running) return
    if (!statusExecutable) {
      setUnavailable("Nextcloud status command is not configured")
      return
    }
    statusProcess.command = [statusExecutable]
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
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    stderr: StdioCollector { id: statusError; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.applyStatus(statusOutput.text)
      else {
        var message = String(statusError.text || statusOutput.text || "Nextcloud status command failed").trim()
        root.setUnavailable(message)
      }
    }
  }
}
