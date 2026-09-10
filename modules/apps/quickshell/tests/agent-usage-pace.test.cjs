const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const panelPath = process.argv[2];
assert.ok(panelPath, "pass the generated Panel.qml path as argv[2]");
const panel = fs.readFileSync(panelPath, "utf8");

function extractFunction(name) {
  const start = panel.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `missing ${name} in ${panelPath}`);
  const bodyStart = panel.indexOf("{", start);
  let depth = 0;
  for (let i = bodyStart; i < panel.length; i++) {
    if (panel[i] === "{") depth++;
    if (panel[i] === "}" && --depth === 0) return panel.slice(start, i + 1);
  }
  assert.fail(`unterminated ${name}`);
}

const helperNames = [
  "clamp",
  "windowIsLong",
  "windowSpanMs",
  "windowTitle",
  "limitSpanMs",
  "limitWindow",
  "limitWindows",
  "resetTimestampMs",
  "resetMsFor",
  "windowElapsedRatio",
  "limitAlarming",
  "resetTextFor",
  "formatDuration",
  "providerAlarming",
];
const logic = vm.createContext({ root: { nowMs: 0 } });
vm.runInContext(helperNames.map(extractFunction).join("\n"), logic);

const HOUR = 60 * 60 * 1000;
const DAY = 24 * HOUR;
const resetAt = new Date(10 * DAY).toISOString();
function normalized(label, title = "") {
  return logic.limitWindow(label, 0.5, resetAt, title);
}

assert.equal(normalized("Session (5-hour)").spanMs, 5 * HOUR);
assert.equal(normalized("Weekly (7-day)").spanMs, 7 * DAY);
assert.equal(normalized("5h window").spanMs, 5 * HOUR);
assert.equal(normalized("30m window").spanMs, 0.5 * HOUR);
assert.equal(normalized("Monthly (30-day)").spanMs, 30 * DAY);
assert.equal(normalized("Limit").spanMs, 0);
assert.equal(
  normalized("Opus 5 (1M context) Session", "Opus 5 (1M context) Session")
    .spanMs,
  5 * HOUR,
);
assert.equal(
  normalized("Opus 5 (1M context) Weekly", "Opus 5 (1M context) Weekly").spanMs,
  7 * DAY,
);
assert.equal(
  normalized("Opus 5 (1M context)", "Opus 5 (1M context)").spanMs,
  0,
);

const resetMs = Date.parse(resetAt);
const paced = normalized("5h window");
logic.root.nowMs = resetMs - 4 * HOUR;
assert.equal(logic.windowElapsedRatio(paced), 0.2);
logic.root.nowMs = resetMs - 6 * HOUR;
assert.equal(
  logic.windowElapsedRatio(paced),
  -1,
  "future window has not started",
);
assert.equal(
  logic.limitAlarming({ ...paced, percent: 0.9 }),
  true,
  "negative elapsed uses fallback",
);
logic.root.nowMs = resetMs;
assert.equal(logic.windowElapsedRatio(paced), 1);
assert.equal(
  logic.limitAlarming({ ...paced, percent: 1 }),
  false,
  "at reset waits for refresh",
);
logic.root.nowMs = resetMs + 1;
assert.equal(
  logic.limitAlarming({ ...paced, percent: 1 }),
  false,
  "after reset waits for refresh",
);
assert.equal(
  logic.limitAlarming({ percent: 1, resetAt, spanMs: 0 }),
  false,
  "expired reset wins over fallback",
);

logic.root.nowMs = resetMs - 4 * HOUR;
assert.equal(
  logic.limitAlarming({ ...paced, percent: 0.19 }),
  false,
  "under pace",
);
assert.equal(
  logic.limitAlarming({ ...paced, percent: 0.2 }),
  false,
  "equal pace",
);
assert.equal(
  logic.limitAlarming({ ...paced, percent: 0.21 }),
  true,
  "over pace",
);
assert.match(
  logic.resetTextFor(paced),
  /^Resets in 4h 0m · 20% of period elapsed$/,
);

logic.root.nowMs = resetMs - 0.25 * HOUR;
assert.equal(
  logic.limitAlarming({ ...paced, percent: 0.92 }),
  false,
  "high usage under pace is not alarming",
);
assert.equal(
  logic.limitAlarming({ ...paced, percent: 0.99 }),
  true,
  "high usage over pace is alarming",
);
logic.root.nowMs = resetMs - 4 * HOUR;

for (const bad of [
  { percent: 0.9, resetAt: "", spanMs: 5 * HOUR },
  { percent: 0.9, resetAt: "not-a-date", spanMs: 5 * HOUR },
  { percent: 0.9, resetAt, spanMs: 0 },
  { percent: 0.9, resetAt, spanMs: NaN },
  { percent: 0.9, resetAt, spanMs: Infinity },
]) {
  assert.equal(
    logic.limitAlarming(bad),
    true,
    `90% fallback: ${JSON.stringify(bad)}`,
  );
  assert.equal(logic.limitAlarming({ ...bad, percent: 0.899 }), false);
}

const secondWindowOverPace = {
  limits: [
    {
      label: "5h window",
      percent: 0.8,
      resetsAt: new Date(logic.root.nowMs + 0.5 * HOUR).toISOString(),
    },
    {
      label: "Weekly (7-day)",
      percent: 0.2,
      resetsAt: new Date(logic.root.nowMs + 6 * DAY).toISOString(),
    },
  ],
  creditsText: "2051",
};
assert.equal(
  logic.providerAlarming(secondWindowOverPace),
  true,
  "checks every provider window",
);
const creditsOnly = { limits: [], creditsText: "2051" };
assert.equal(
  logic.providerAlarming(creditsOnly),
  false,
  "credits are not a balance alarm",
);
assert.equal(
  [creditsOnly, secondWindowOverPace].some(logic.providerAlarming),
  true,
  "folds alarms across providers",
);
assert.equal(
  logic.providerAlarming({
    limits: [],
    balance: { funded: 100, remaining: 10 },
  }),
  true,
);
assert.equal(
  logic.providerAlarming({
    limits: [],
    balance: { funded: 100, remaining: 11 },
  }),
  false,
);

assert.match(
  panel,
  /readonly property bool alarming: root\.limitAlarming\(window\)/,
);
assert.match(
  panel,
  /markerValue: root\.resetMsFor\(limitRow\.window\) > 0 \? root\.windowElapsedRatio\(limitRow\.window\) : -1/,
);
assert.match(
  panel,
  /id: resetText[\s\S]*?text: root\.resetTextFor\(limitRow\.window\)[\s\S]*?wrapMode: Text\.WordWrap/,
);
assert.match(
  panel,
  /Timer \{\s*interval: 30000\s*running: true\s*repeat: true\s*onTriggered: root\.nowMs = Date\.now\(\)/,
);
console.log("Agent usage pace tests passed");
