const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const pluginDir = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(__dirname, "../omarchy/plugins/pangolin");
const Status = require(path.join(pluginDir, "Status.js"));

function status(overrides = {}) {
  return JSON.stringify({
    connected: true,
    registered: true,
    terminated: false,
    orgId: "org-1",
    peers: {},
    ...overrides,
  });
}

let parsed = Status.parseStatus(status());
assert.equal(parsed.ok, true);
assert.equal(parsed.state, "connected");
assert.equal(parsed.orgId, "org-1");

parsed = Status.parseStatus(JSON.stringify({
  connected: true,
  registered: true,
  terminated: false,
}));
assert.equal(parsed.ok, true, "omitempty fields may be absent");
assert.equal(parsed.orgId, "");
assert.deepEqual(parsed.peers, []);

for (const values of [
  { connected: false, registered: true },
  { connected: true, registered: false },
  { connected: false, registered: false },
]) {
  const disconnected = Status.parseStatus(status(values));
  assert.equal(disconnected.state, "disconnected");
  assert.equal(disconnected.connected, false);
}

parsed = Status.parseStatus(status({
  peers: {
    z: { name: "Offline", connected: false, isRelay: false, isLocal: false },
    a: { name: "Direct", connected: true, isRelay: false, isLocal: false },
    b: { name: "Relay", connected: true, isRelay: true, isLocal: false },
    c: { name: "Local", connected: true, isRelay: false, isLocal: true },
  },
}));
assert.deepEqual(parsed.peers.map((peer) => peer.name), ["Direct", "Local", "Offline", "Relay"]);
assert.deepEqual(parsed.peers.map((peer) => peer.status), ["direct", "local", "offline", "relay"]);

parsed = Status.parseStatus(status({
  peers: {
    missing: null,
    good: { name: "Site 2", connected: true, isRelay: false, isLocal: false },
  },
}));
assert.equal(parsed.ok, true);
assert.deepEqual(parsed.peers.map((peer) => peer.name), ["Site 2"]);

const bannerStatus = status({ orgId: "banner-org" });
for (const output of [
  `A new version is available.\n${bannerStatus}\nRun pangolin update to install it.`,
  `\u001b[33mUpdate available\u001b[0m\n${bannerStatus}\nVisit https://example.invalid/releases`,
  `Update metadata: {not-json}\n${bannerStatus}\nRelease notes: {see website}`,
  `Update metadata: {"latest":"0.16.0"}\n${bannerStatus}\nRun pangolin update`,
]) {
  parsed = Status.parseStatus(output);
  assert.equal(parsed.ok, true);
  assert.equal(parsed.state, "connected");
  assert.equal(parsed.orgId, "banner-org");
}

parsed = Status.parseStatus(`Notice\nNo client is currently running.\nUpdate available`);
assert.equal(parsed.state, "stopped");
parsed = Status.parseStatus(`${bannerStatus}\nNo client is currently running.`);
assert.equal(parsed.state, "connected", "a stopped banner must not override valid JSON");

parsed = Status.parseStatus(status({
  error: { code: "denied", message: "registration failed" },
}));
assert.equal(parsed.state, "error", "error overrides connected state");
assert.equal(parsed.errorCode, "denied");
assert.equal(parsed.errorMessage, "registration failed");
assert.equal(Status.parseStatus(status({ error: {} })).state, "error");

parsed = Status.parseStatus(status({ terminated: true }));
assert.equal(parsed.state, "stopped");
assert.deepEqual(parsed.peers, []);

for (const message of ["No client is currently running", "No client is currently running."]) {
  parsed = Status.parseStatus(message);
  assert.equal(parsed.ok, true);
  assert.equal(parsed.state, "stopped");
}

for (const malformed of [
  "",
  "not json",
  "[]",
  JSON.stringify({ connected: true }),
  status({ connected: "yes" }),
  status({ orgId: null }),
  status({ peers: [] }),
  status({ peers: null }),
  status({ peers: { bad: { name: "Bad", connected: true } } }),
  status({ error: "failed" }),
]) {
  parsed = Status.parseStatus(malformed);
  assert.equal(parsed.ok, false, `expected unavailable for ${malformed}`);
  assert.equal(parsed.state, "unavailable");
  assert.deepEqual(parsed.peers, []);
}

const panel = fs.readFileSync(path.join(pluginDir, "Panel.qml"), "utf8");
assert.match(panel, /tooltipText:\s*""/);
assert.doesNotMatch(panel, /hoverEnabled:\s*true/);
const barIcon = panel.slice(panel.indexOf("iconComponent:"), panel.indexOf("onPressed:"));
assert.match(barIcon, /color:\s*root\.statusColor/);
assert.doesNotMatch(barIcon, /Rectangle\s*\{/);
assert.match(panel, /Item\s*\{\s*id:\s*refreshButton/);
assert.match(panel, /text:\s*"\\uf021"\s*color:\s*root\.mutedColor/);
assert.doesNotMatch(panel, /refreshedText|Refreshed |Refreshing\.\.\.|Color\.popups\.border/);
assert.match(panel, /textFormat:\s*Text\.PlainText[\s\S]*text:\s*modelData\.name/);
assert.equal((panel.match(/Flickable\s*\{/g) || []).length, 1, "panel should have one scrolling surface");

const service = fs.readFileSync(path.join(pluginDir, "Service.qml"), "utf8");
assert.match(service, /Quickshell\.env\("PANGOLIN_BIN"\)/);
assert.match(service, /Quickshell\.env\("PANGOLIN_TIMEOUT_BIN"\)/);
assert.match(service, /\[timeoutExecutable,\s*"-k",\s*"2s",\s*"8s",\s*pangolinExecutable,\s*"status",\s*"--json"\]/);
assert.match(service, /exitCode === 124 \|\| exitCode === 137/);
assert.match(service, /interval:\s*15000/);

for (const name of ["manifest.json", "Status.js", "Service.qml", "Panel.qml"]) {
  const source = fs.readFileSync(path.join(pluginDir, name), "utf8");
  assert.doesNotMatch(source, /[^\x00-\x7f]/, `${name} must be ASCII-only`);
}
assert.doesNotMatch(fs.readFileSync(__filename, "utf8"), /[^\x00-\x7f]/, "test must be ASCII-only");

console.log("pangolin status tests passed");
