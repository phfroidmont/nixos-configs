function unavailable(message) {
  return {
    ok: false,
    state: "unavailable",
    connected: false,
    registered: false,
    terminated: false,
    orgId: "",
    peers: [],
    errorCode: "",
    errorMessage: String(message || "Pangolin status is unavailable")
  }
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function peerStatus(peer) {
  if (peer.connected !== true) return "offline"
  if (peer.isLocal === true) return "local"
  if (peer.isRelay === true) return "relay"
  return "direct"
}

function statusObject(text) {
  var firstObject = null
  for (var start = text.indexOf("{"); start !== -1; start = text.indexOf("{", start + 1)) {
    var depth = 0
    var quoted = false
    var escaped = false
    for (var end = start; end < text.length; end++) {
      var character = text.charAt(end)
      if (quoted) {
        if (escaped) escaped = false
        else if (character === "\\") escaped = true
        else if (character === "\"") quoted = false
      } else if (character === "\"") {
        quoted = true
      } else if (character === "{") {
        depth++
      } else if (character === "}") {
        depth--
        if (depth === 0) {
          try {
            var candidate = JSON.parse(text.substring(start, end + 1))
            if (isObject(candidate)) {
              if (firstObject === null) firstObject = candidate
              if (candidate.connected !== undefined
                  || candidate.registered !== undefined
                  || candidate.terminated !== undefined) return candidate
            }
          } catch (error) {
          }
          break
        }
      }
    }
  }
  return firstObject
}

function parseStatus(raw) {
  var text = String(raw === undefined || raw === null ? "" : raw)
    .replace(/\x1b\[[0-?]*[ -\/]*[@-~]/g, "")
    .trim()
  var value = statusObject(text)
  if (value === null && /^[ \t]*No client is currently running\.?[ \t]*$/im.test(text)) {
    return {
      ok: true,
      state: "stopped",
      connected: false,
      registered: false,
      terminated: true,
      orgId: "",
      peers: [],
      errorCode: "",
      errorMessage: ""
    }
  }

  if (!isObject(value)
      || typeof value.connected !== "boolean"
      || typeof value.registered !== "boolean"
      || typeof value.terminated !== "boolean"
      || (value.orgId !== undefined && typeof value.orgId !== "string")
      || (value.peers !== undefined && !isObject(value.peers))) {
    return unavailable("Pangolin returned invalid status data")
  }

  var peers = []
  var peerMap = value.peers === undefined ? {} : value.peers
  var ids = Object.keys(peerMap).sort()
  for (var i = 0; i < ids.length; i++) {
    var id = ids[i]
    var peer = peerMap[id]
    if (peer === null) continue
    if (!isObject(peer)
        || typeof peer.name !== "string"
        || typeof peer.connected !== "boolean"
        || typeof peer.isRelay !== "boolean"
        || typeof peer.isLocal !== "boolean") {
      return unavailable("Pangolin returned invalid peer data")
    }
    peers.push({
      id: id,
      name: peer.name || id,
      connected: peer.connected,
      isRelay: peer.isRelay,
      isLocal: peer.isLocal,
      status: peerStatus(peer)
    })
  }
  peers.sort(function(a, b) {
    var byName = a.name.localeCompare(b.name)
    return byName !== 0 ? byName : a.id.localeCompare(b.id)
  })

  var errorCode = ""
  var errorMessage = ""
  var hasError = value.error !== undefined && value.error !== null
  if (hasError) {
    if (!isObject(value.error)) return unavailable("Pangolin returned invalid error data")
    errorCode = String(value.error.code === undefined || value.error.code === null ? "" : value.error.code)
    errorMessage = String(value.error.message === undefined || value.error.message === null ? "" : value.error.message)
  }

  var connected = value.connected === true && value.registered === true
  var state = connected ? "connected" : "disconnected"
  if (value.terminated === true) state = "stopped"
  if (hasError) state = "error"

  return {
    ok: true,
    state: state,
    connected: connected,
    registered: value.registered,
    terminated: value.terminated,
    orgId: value.orgId === undefined ? "" : value.orgId,
    peers: state === "stopped" ? [] : peers,
    errorCode: errorCode,
    errorMessage: errorMessage
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStatus: parseStatus,
    peerStatus: peerStatus
  }
}
