const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

// Usage: node opencode-review.test.js ARTIFACT.json (or - for stdin).
const filename = process.argv[2];
assert.ok(filename, "usage: opencode-review.test.js ARTIFACT.json (or -)");
const { agents, aliases, initContent, rules } = JSON.parse(
  fs.readFileSync(filename === "-" ? 0 : filename, "utf8"),
);
const models = {
  fable: "anthropic/claude-fable-5-1",
  opus: "anthropic/claude-opus-5-5",
};
const profiles = ["oc", "oc-openai", "oc-premium", "oc-anthropic", "oc-foyer", "oc-power"];

assert.equal(agents.review.model, models.fable);
for (const [choice, model] of Object.entries(models)) {
  const name = `review-${choice}`;
  assert.equal(agents[name].model, model, name);
  assert.notEqual(agents[name].disable, true, name);
  for (const field of ["mode", "steps", "prompt", "permission"]) {
    assert.deepEqual(agents[name][field], agents.review[field], `${name}.${field}`);
  }
  for (const primary of ["build", "plan"]) {
    assert.equal(agents[primary].permission.task[name], "allow", `${primary} allows ${name}`);
    assert.equal(agents[primary].permission.task.review, "allow");
    assert.equal(agents[primary].permission.task["review-sol"], "allow");
  }
  assert.ok(rules.includes(name), `rules explain ${name}`);
}
assert.match(rules, /--review-model/);
assert.match(rules, /review-sol/);
assert.match(rules, /quota/);

// Match the function's own indentation, not nested blocks or other startup code.
// Accept either a brace body or a subshell body used for environment isolation.
const wrappers = [...initContent.matchAll(/^([\t ]*)opencode\(\)[\t ]*[({]\n[\s\S]*?^\1[})][\t ]*$/gm)];
assert.equal(wrappers.length, 1, "extract only the opencode() function");
const quote = (value) => `'${value.replaceAll("'", "'\\''")}'`;
const aliasDefinitions = profiles.map((name) => {
  assert.equal(typeof aliases[name], "string", `generated alias ${name}`);
  return `alias ${quote(`${name}=${aliases[name]}`)}`;
}).join("\n");
const temp = fs.mkdtempSync(path.join(os.tmpdir(), "opencode-review-"));
const log = path.join(temp, "calls.jsonl");

function launch(name, args = [], options = {}) {
  fs.writeFileSync(log, "");
  const env = {
    PATH: `${temp}:${process.env.PATH}`,
    HOME: temp,
    ZDOTDIR: temp,
    OPENCODE_TEST_LOG: log,
    OPENCODE_TEST_EXIT: String(options.exitStatus ?? 0),
  };
  if (options.config !== undefined) env.OPENCODE_CONFIG_CONTENT = options.config;
  if (options.herdr !== undefined) env.HERDR_ENV = options.herdr;
  const command = [name, ...args.map(quote)].join(" ");
  const result = spawnSync("zsh", ["-f", "-c", `
    export PATH=${quote(env.PATH)}
    ${wrappers[0][0]}
    wait_for_metals_mcp() {
      OPENCODE_TEST_KIND=preflight command opencode "$@"
    }
    ${aliasDefinitions}
    eval ${quote(command)}
    launch_status=$?
    OPENCODE_TEST_KIND=parent command opencode
    ${options.followOn ? "opencode --version" : ""}
    exit "$launch_status"
  `], { cwd: temp, env, encoding: "utf8", timeout: 10000 });
  assert.ifError(result.error);
  assert.equal(result.signal, null, result.stderr);
  const events = fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse);
  const parent = events.find((event) => event.kind === "parent");
  assert.ok(parent, `shell completed: ${command}\n${result.stderr}`);
  assert.equal(parent.config, options.config ?? null, `no parent config leak: ${command}`);
  return { ...result, events: events.filter((event) => event.kind !== "parent") };
}

function successful(result, args, preflight = false) {
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.events.map((event) => event.kind),
    preflight ? ["preflight", "opencode"] : ["opencode"]);
  const call = result.events.at(-1);
  assert.deepEqual(call.args, args);
  if (preflight) assert.equal(result.events[0].config, call.config, "preflight sees selected config");
  return call;
}

function selectedConfig(config, model) {
  const expected = structuredClone(config);
  expected.agent ??= {};
  expected.agent.review ??= {};
  expected.agent.review.model = model;
  delete expected.agent.review.variant;
  return expected;
}

function fixedNamedAgents(config) {
  for (const choice of Object.keys(models)) {
    const name = `review-${choice}`;
    assert.deepEqual({ ...agents[name], ...config.agent?.[name] }, agents[name],
      `profile leaves ${name} fixed`);
  }
}

try {
  // This executable is the only external opencode; neither models nor MCPs run.
  fs.writeFileSync(path.join(temp, "opencode"), `#!${process.execPath}
const fs = require("node:fs");
const kind = process.env.OPENCODE_TEST_KIND || "opencode";
fs.appendFileSync(process.env.OPENCODE_TEST_LOG, JSON.stringify({
  kind,
  args: process.argv.slice(2),
  config: process.env.OPENCODE_CONFIG_CONTENT ?? null,
}) + "\\n");
process.exit(kind === "opencode" ? Number(process.env.OPENCODE_TEST_EXIT) : 0);
`, { mode: 0o755 });

  // No selector means no JSON parsing or reserialization, even for invalid JSON.
  for (const config of [undefined, "", ' { "model": "keep/me" } ', "{broken-json"]) {
    const call = successful(launch("opencode", [], { config }), []);
    assert.equal(call.config, config ?? null);
  }

  // Exercise real generated aliases via eval, including their leading --auto.
  const profileConfigs = {};
  for (const name of profiles) {
    const baseline = successful(launch(name), ["--auto"]);
    const config = JSON.parse(baseline.config || "{}");
    profileConfigs[name] = config;
    fixedNamedAgents(config);
    for (const [choice, model] of Object.entries(models)) {
      const call = successful(launch(name, ["--review-model", choice, "run", "review this"]),
        ["--auto", "run", "review this"]);
      const selected = JSON.parse(call.config);
      assert.deepEqual(selected, selectedConfig(config, model), `${name} + ${choice}`);
      fixedNamedAgents(selected);
    }
  }
  assert.equal(profileConfigs["oc-anthropic"].model, models.opus);
  assert.equal(profileConfigs["oc-anthropic"].agent.build.model, models.opus);
  assert.equal(profileConfigs["oc-anthropic"].agent.plan.model, models.opus);
  assert.equal(profileConfigs["oc-anthropic"].agent.review.model, models.opus);
  assert.equal(profileConfigs["oc-premium"].agent.review.model, models.opus);
  assert.equal(profileConfigs["oc-premium"].agent.review.variant, undefined);

  // Preserve argument boundaries, quotes, globs, newlines, empty args, and --.
  const nativeArgs = ["--model", "openai/native", "./project's [one]*", "--",
    'prompt with "quotes", $HOME\nand a newline', "--review-model", "not-a-selector", ""];
  for (const [choice, model] of Object.entries(models)) {
    const call = successful(launch("opencode", ["--review-model", choice, ...nativeArgs]), nativeArgs);
    assert.deepEqual(JSON.parse(call.config), selectedConfig({}, model));
  }
  for (const args of [
    ["run", "--review-model", "invalid"],
    ["./project path", "--review-model", "opus"],
    ["--", "--review-model", "fable"],
    ["--model", "openai/native", "--review-model", "invalid"],
  ]) {
    const call = successful(launch("opencode", args), args);
    assert.equal(call.config, null, "stop parsing at the first non-wrapper argument");
  }

  for (const args of [
    ["--review-model"],
    ["--review-model", ""],
    ["--review-model", "invalid"],
    ["--review-model", "--session", "session-id"],
  ]) {
    const result = launch("oc", args, { herdr: "1" });
    assert.notEqual(result.status, 0, `reject ${JSON.stringify(args)}`);
    assert.deepEqual(result.events, [], "invalid selector fails before preflight or external command");
  }
  const malformed = launch("opencode", ["--review-model", "opus", "--session", "session-id"],
    { config: "{broken-json", herdr: "1" });
  assert.notEqual(malformed.status, 0);
  assert.deepEqual(malformed.events, [], "malformed JSON fails before preflight or external command");

  const customConfig = {
    model: "openai/keep-top-level",
    small_model: "openai/keep-small",
    plugin: ["keep-plugin"],
    mcp: { local: { enabled: true, environment: { KEEP: "value" } } },
    provider: { local: { options: { baseURL: "http://localhost:9999" } } },
    permission: { edit: "ask" },
    agent: {
      review: { model: "old/model", variant: "xhigh", temperature: 0.2, prompt: "keep prompt",
        permission: { edit: "deny" }, steps: 42 },
      build: { model: "keep/build", variant: "xhigh" },
      "review-fable": { model: models.fable },
      "review-opus": { model: models.opus },
    },
  };
  const customRaw = ` ${JSON.stringify(customConfig, null, 2)}\n`;
  for (const config of [undefined, "", customRaw]) {
    const result = launch("opencode", ["--review-model", "opus"], { config, followOn: true });
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(result.events.map((event) => event.kind), ["opencode", "opencode"]);
    assert.deepEqual(JSON.parse(result.events[0].config),
      selectedConfig(config ? customConfig : {}, models.opus));
    assert.deepEqual(result.events[1].args, ["--version"]);
    assert.equal(result.events[1].config, config ?? null, "no config leak to a follow-on launch");
  }
  const premium = launch("oc-premium", ["--review-model", "fable"],
    { config: customRaw, followOn: true });
  assert.equal(premium.status, 0, premium.stderr);
  assert.deepEqual(JSON.parse(premium.events[0].config),
    selectedConfig(profileConfigs["oc-premium"], models.fable));
  assert.equal(premium.events[1].config, customRaw, "alias assignment does not leak either");

  // Session restoration adds --auto once; ports alone do not imply --auto.
  for (const [name, args, expected, herdr, preflight] of [
    ["opencode", ["--session", "s"], ["--auto", "--session", "s"], undefined, false],
    ["opencode", ["--session=s"], ["--auto", "--session=s"], "0", false],
    ["opencode", ["--session=s"], ["--auto", "--session=s"], "1", true],
    ["oc", ["--session", "s"], ["--auto", "--session", "s"], "1", true],
    ["opencode", ["--auto", "--session", "s"], ["--auto", "--session", "s"], "1", true],
    ["opencode", ["--port", "4321"], ["--port", "4321"], "1", true],
    ["opencode", ["--port=4321"], ["--port=4321"], "1", true],
    ["opencode", [], [], "1", false],
  ]) {
    const call = successful(launch(name, ["--review-model", "opus", ...args], { herdr }),
      expected, preflight);
    assert.deepEqual(JSON.parse(call.config), selectedConfig({}, models.opus));
  }
  const restored = successful(launch("opencode", ["--session", "s"],
    { config: "{still-not-parsed", herdr: "1" }), ["--auto", "--session", "s"], true);
  assert.equal(restored.config, "{still-not-parsed");

  for (const args of [[], ["--review-model", "fable"], ["--review-model", "opus", "--session", "s"]]) {
    const result = launch("opencode", args, { exitStatus: 37, herdr: "1" });
    assert.equal(result.status, 37, "propagate the external command's exit status");
    assert.equal(result.events.at(-1).kind, "opencode");
  }
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}

console.log("Passed generated OpenCode reviewer, alias, and isolated zsh wrapper checks.");
