const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const filename = process.argv[2];
assert.ok(filename, "usage: opencode-review.test.js ARTIFACT.json");
const { launcher, native, presets: presetsPath, shared, aliases, rules, initContent } =
  JSON.parse(fs.readFileSync(filename, "utf8"));
const presets = JSON.parse(fs.readFileSync(presetsPath, "utf8"));
const { custom, profiles, power, reviewModels } = presets;
const agents = custom.agent;
const models = {
  fable: "anthropic/claude-fable-5-1",
  opus: "anthropic/claude-opus-5-5",
};
const gpt6Sol = "openai/gpt-6-sol";
const gpt6Luna = "openai/gpt-6-luna";
const gpt6Astra = "openai/gpt-6-astra";

assert.ok(shared.plugin.length > 0, "shared plugins remain in OpenCode settings");
assert.ok(shared.permission && shared.mcp && shared.provider, "shared settings remain outside launcher overlays");
assert.equal(shared.instructions, undefined, "shared settings do not impose custom delegation");
assert.deepEqual(reviewModels, models);
assert.equal(agents.review.model, models.opus, "default reviewer follows the balanced profile");
assert.equal(agents.review.permission.edit, "deny");
assert.equal(agents.review.permission.task, "deny");
assert.equal(agents["review-sol"].model, gpt6Sol);
assert.equal(agents["review-sol"].permission.edit, "deny");
assert.equal(agents.plan.permission.edit, "deny");
assert.equal(agents.build.permission.task["*"], "deny");
for (const [choice, model] of Object.entries(models)) {
  const name = `review-${choice}`;
  assert.equal(agents[name].model, model, name);
  assert.notEqual(agents[name].disable, true, name);
  for (const field of ["mode", "steps", "prompt", "permission"]) {
    assert.deepEqual(agents[name][field], agents.review[field], `${name}.${field}`);
  }
  for (const primary of ["build", "plan"]) {
    assert.equal(agents[primary].permission.task[name], "allow");
    assert.equal(agents[primary].permission.task.review, "allow");
    assert.equal(agents[primary].permission.task["review-sol"], "allow");
  }
}
for (const name of ["implement", "review-sol"]) assert.equal(agents[name].model, gpt6Sol);
for (const name of ["scout", "test-triage", "compaction", "scan", "title", "summary"]) {
  assert.ok(agents[name], name);
}
const delegation = custom.instructions.map((file) => fs.readFileSync(file, "utf8")).join("\n");
for (const phrase of ["review-fable", "review-opus", "review-sol", "quota", "--review-model"]) {
  assert.ok(delegation.includes(phrase), `custom instructions mention ${phrase}`);
}
assert.ok(!rules.includes("review-sol"), "global AGENTS does not impose custom delegation");
assert.ok(!rules.includes("--review-model"));

function merge(left, right) {
  const result = structuredClone(left);
  for (const [key, value] of Object.entries(right)) {
    if (value && typeof value === "object" && !Array.isArray(value) &&
        result[key] && typeof result[key] === "object" && !Array.isArray(result[key])) {
      result[key] = merge(result[key], value);
    } else if (["plugin", "instructions"].includes(key) && Array.isArray(value) && Array.isArray(result[key])) {
      result[key] = [...new Set([...result[key], ...value])];
    } else {
      result[key] = structuredClone(value);
    }
  }
  return result;
}

function expected({ agentsMode = "custom", profile, inherited = {}, usePower = false, reviewer } = {}) {
  let config = merge(agentsMode === "custom" ? custom : {}, inherited);
  if (profile) {
    let selected = profiles[profile];
    if (agentsMode === "stock") {
      selected = structuredClone(selected);
      selected.agent = Object.fromEntries(Object.entries(selected.agent).filter(([name]) =>
        ["build", "plan", "general", "explore", "compaction", "title", "summary"].includes(name)));
    }
    config = merge(config, selected);
  }
  if (usePower) config = merge(config, power);
  if (reviewer) {
    config.agent ??= {};
    config.agent.review ??= {};
    config.agent.review.model = models[reviewer];
    delete config.agent.review.variant;
  }
  return config;
}

const temp = fs.mkdtempSync(path.join(os.tmpdir(), "oc-review-"));
const log = path.join(temp, "calls.jsonl");
const fake = path.join(temp, "fake-opencode");
const executable = path.join(temp, "oc");
function launch(args = [], options = {}) {
  fs.writeFileSync(log, "");
  const env = { ...process.env, HOME: temp, OPENCODE_TEST_LOG: log,
    OPENCODE_TEST_EXIT: String(options.exitStatus ?? 0) };
  delete env.OPENCODE_CONFIG_CONTENT;
  delete env.OC_CONFIG_INPUT;
  delete env.OC_CONFIG_OUTPUT;
  delete env.HERDR_ENV;
  if (options.inherited !== undefined) env.OPENCODE_CONFIG_CONTENT = options.inherited;
  if (options.herdr !== undefined) env.HERDR_ENV = options.herdr;
  if (options.parent) {
    env.OPENCODE_CONFIG_CONTENT = options.parent.config;
    env.OC_CONFIG_INPUT = options.parent.input;
    env.OC_CONFIG_OUTPUT = options.parent.output;
  }
  const result = spawnSync(executable, args, { env, cwd: temp, encoding: "utf8", timeout: 10000 });
  assert.ifError(result.error);
  assert.equal(result.signal, null, result.stderr);
  const events = fs.readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse);
  return { ...result, events };
}
function successful(args, config, forwarded = ["--auto"], options = {}) {
  const result = launch(args, options);
  assert.equal(result.status, 0, `${JSON.stringify(args)}: ${result.stderr}`);
  assert.deepEqual(result.events.map((event) => event.kind), options.preflight ? ["debug", "native"] : ["native"]);
  const call = result.events.at(-1);
  assert.deepEqual(call.args, forwarded);
  assert.deepEqual(JSON.parse(call.config), config);
  if (options.preflight) assert.equal(result.events[0].config, call.config, "debug config sees identical overlay");
  return call;
}

try {
  // Exercise the installed launcher, replacing only the absolute native binary path
  // in a temporary copy. Neither OpenCode, models, nor MCPs are started.
  const script = fs.readFileSync(launcher, "utf8");
  assert.equal(script.split(native).length, 2, "packaged launcher embeds native exactly once");
  fs.writeFileSync(executable, script.replace(native, fake), { mode: 0o755 });
  fs.writeFileSync(fake, `#!${process.execPath}
const fs = require("node:fs");
const kind = process.argv[2] === "debug" && process.argv[3] === "config" ? "debug" : "native";
fs.appendFileSync(process.env.OPENCODE_TEST_LOG, JSON.stringify({ kind,
  args: process.argv.slice(2), config: process.env.OPENCODE_CONFIG_CONTENT ?? null,
  input: process.env.OC_CONFIG_INPUT, output: process.env.OC_CONFIG_OUTPUT }) + "\\n");
process.exit(kind === "native" ? Number(process.env.OPENCODE_TEST_EXIT) : 0);
`, { mode: 0o755 });

  assert.equal(aliases.oc, undefined, "old oc shell alias must not shadow packaged launcher");
  successful([], expected());
  for (const [profile, config] of Object.entries(profiles)) {
    for (const mode of ["custom", "stock"]) {
      for (const usePower of [false, true]) {
        const args = ["--profile", profile, "--agents", mode, ...(usePower ? ["--power"] : [])];
        const selected = expected({ profile, agentsMode: mode, usePower });
        successful(args, selected);
        if (mode === "stock") {
          for (const name of ["review", "review-fable", "review-opus", "review-sol", "implement", "scout", "scan"]) {
            assert.equal(selected.agent?.[name], undefined, `stock ${profile} omits ${name}`);
          }
          assert.equal(selected.instructions, undefined, "stock has no custom delegation instructions");
        } else {
          for (const [choice, model] of Object.entries(models)) {
            const reviewed = expected({ profile, usePower, reviewer: choice });
            successful([...args, `--review-model=${choice}`], reviewed);
            assert.equal(reviewed.agent.review.model, model);
            assert.equal(reviewed.agent.review.variant, undefined);
            assert.equal(reviewed.agent[`review-${choice}`].model, model);
          }
        }
      }
    }
  }
  assert.equal(profiles.anthropic.model, models.opus);
  assert.equal(profiles.anthropic.agent.review.model, models.opus);
  assert.equal(profiles.openai.small_model, gpt6Luna);
  for (const name of ["implement", "scout", "test-triage", "compaction"]) {
    assert.equal(profiles.openai.agent[name].model, gpt6Sol);
  }
  for (const name of ["scan", "title", "summary"]) {
    assert.equal(profiles.openai.agent[name].model, gpt6Luna);
  }
  assert.equal(profiles.premium.small_model, gpt6Astra);
  assert.equal(profiles.premium.agent["review-sol"].variant, "xhigh");
  assert.equal(profiles.premium.agent.review.model, models.opus);

  const inherited = {
    plugin: ["keep-plugin", power.plugin[0]],
    instructions: ["keep-instructions", custom.instructions[0]],
    mcp: { local: { enabled: true, environment: { KEEP: "value" } } },
    provider: { local: { options: { baseURL: "http://localhost:9999" } } },
    agent: { review: { model: "old/model", variant: "xhigh", temperature: 0.2,
      permission: { edit: "deny" }, steps: 42 }, build: { model: "keep/build" } },
  };
  const raw = ` ${JSON.stringify(inherited, null, 2)}\n`;
  for (const mode of ["custom", "stock"]) {
    for (const profile of Object.keys(profiles)) {
      const args = ["--agents", mode, `--profile=${profile}`, "--power"];
      successful(args, expected({ agentsMode: mode, profile, inherited, usePower: true }),
        ["--auto"], { inherited: raw });
    }
  }
  successful(["--profile", "premium", "--review-model", "fable", "--power"],
    expected({ profile: "premium", inherited, usePower: true, reviewer: "fable" }),
    ["--auto"], { inherited: raw });
  successful(["--agents", "stock"], expected({ agentsMode: "stock", inherited }),
    ["--auto"], { inherited: raw });
  successful([], expected(), ["--auto"], { inherited: undefined });

  // Child launches must not mistake a parent's generated preset for user input.
  const parentInput = { plugin: ["keep-plugin"], instructions: ["keep-rules"] };
  const parent = successful(["--profile=premium", "--power"],
    expected({ profile: "premium", usePower: true, inherited: parentInput }),
    ["--auto"], { inherited: JSON.stringify(parentInput) });
  successful(["--agents=stock"], parentInput, ["--auto"], { parent });
  successful(["--profile=anthropic"], expected({ profile: "anthropic", inherited: parentInput }),
    ["--auto"], { parent });
  successful(["--agents=stock"], { model: "explicit/override" }, ["--auto"],
    { parent: { ...parent, config: '{"model":"explicit/override"}' } });

  const nativeArgs = ["--model", "openai/native", "./project's [one]*", "--",
    'prompt with "quotes", $HOME\nand a newline', "--review-model", "not-a-selector", ""];
  successful(["--review-model", "opus", ...nativeArgs], expected({ reviewer: "opus" }),
    ["--auto", ...nativeArgs]);
  for (const args of [["run", "--profile", "invalid"], ["--", "--profile", "invalid"],
    ["--model", "openai/native", "--review-model", "invalid"], ["--profilex=invalid"]]) {
    successful(args, expected(), ["--auto", ...args.filter((arg) => arg !== "--")]);
  }
  successful(["--no-auto", "run", "hello"], expected(), ["run", "hello"]);
  successful(["--no-auto", "--auto", "run"], expected(), ["--auto", "run"]);
  successful(["--auto", "--auto"], expected(), ["--auto", "--auto"]);
  successful(["--no-auto", "--", "--auto"], expected(), ["--auto"]);

  for (const args of [["--profile"], ["--profile="], ["--profile", "invalid"],
    ["--agents", "invalid"], ["--review-model", "invalid"], ["--review-model"],
    ["--agents", "stock", "--review-model", "opus"],
    ["--profile", "openai", "--profile=premium"],
    ["--agents=custom", "--agents=stock"],
    ["--review-model=opus", "--review-model", "fable"]]) {
    const result = launch(args, { herdr: "1" });
    assert.notEqual(result.status, 0, JSON.stringify(args));
    assert.deepEqual(result.events, [], "invalid selector fails before native or debug config");
  }
  for (const inheritedBad of ["{broken-json", "[]", "null", "{} {}", ""]) {
    const result = launch(["--profile", "openai"], { inherited: inheritedBad, herdr: "1" });
    if (inheritedBad === "") {
      assert.equal(result.status, 0, result.stderr);
    } else {
      assert.notEqual(result.status, 0, inheritedBad);
      assert.deepEqual(result.events, []);
    }
  }

  fs.writeFileSync(path.join(temp, "opencode.json"), '{"mcp":{"metals-lsp":{"type":"remote","url":"http://localhost:1234"}}}');
  for (const [args, preflight] of [
    [["--session", "s"], true], [["--session=s"], true], [["--port", "4321"], true],
    [["--port=4321"], true], [[], false], [["--", "--session", "s"], true],
  ]) {
    successful(args, expected(), ["--auto", ...args.filter((arg) => arg !== "--")],
      { herdr: "1", preflight });
  }
  successful(["--session=s"], expected(), ["--auto", "--session=s"], { herdr: "0" });
  successful(["--profile", "premium", "--review-model", "fable", "--session", "s"],
    expected({ profile: "premium", inherited, reviewer: "fable" }), ["--auto", "--session", "s"],
    { inherited: raw, herdr: "1", preflight: true });

  // Herdr restores fixed native argv through Zsh, bypassing its launch command.
  const wrappers = [...initContent.matchAll(/^([\t ]*)opencode\(\)[\t ]*\{\n[\s\S]*?^\1\}[\t ]*$/gm)];
  assert.equal(wrappers.length, 1);
  const wrapper = wrappers[0][0].replace(launcher, executable);
  fs.writeFileSync(log, "");
  const restored = spawnSync("zsh", ["-f", "-c", `${wrapper}\nopencode --session restored`], {
    cwd: temp, encoding: "utf8", timeout: 10000,
    env: { PATH: process.env.PATH, HOME: temp, HERDR_ENV: "1", OPENCODE_TEST_LOG: log, OPENCODE_TEST_EXIT: "0" },
  });
  assert.ifError(restored.error);
  assert.equal(restored.status, 0, restored.stderr);
  const restoredCalls = fs.readFileSync(log, "utf8").trim().split("\n").map(JSON.parse);
  assert.deepEqual(restoredCalls.map((call) => call.kind), ["debug", "native"]);
  assert.deepEqual(restoredCalls.at(-1).args, ["--auto", "--session", "restored"]);
  assert.deepEqual(JSON.parse(restoredCalls.at(-1).config), expected());

  for (const args of [[], ["--review-model", "opus"], ["--session", "s"]]) {
    const result = launch(args, { exitStatus: 37, herdr: "1" });
    assert.equal(result.status, 37, "propagate native exit status");
    assert.equal(result.events.at(-1).kind, "native");
  }
} finally {
  fs.rmSync(temp, { recursive: true, force: true });
}

console.log("Passed packaged oc reviewer, profile, isolation, and forwarding checks.");
