const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

async function main() {
  const artifact = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  for (const skill of artifact.skills) {
    assert.notEqual(
      path.dirname(fs.realpathSync(skill)),
      "/nix/store",
      "V2 watches a skill's resolved parent recursively; it must not be the entire Nix store",
    );
  }
  const { shared, presets: file } = artifact;
  assert.equal(shared.default_agent, "build", "default to the stock agent");
  const presets = JSON.parse(fs.readFileSync(file, "utf8"));
  assert.deepEqual(
    shared.providers.openai.models["gpt-6-astra"].limit,
    {
      context: 1050000,
      input: 922000,
      output: 128000,
    },
    "ChatGPT's legacy context cap must not shrink Astra's input budget",
  );
  const { default: plugin, modelRef } = await import(artifact.plugin);
  for (const [id, model] of Object.entries(shared.providers.openai.models)) {
    const base = id.replace(/-(?:ultra)?fast$/, "");
    assert.deepEqual(
      model.limit,
      shared.providers.openai.models[base].limit,
      `${id} must preserve its underlying model's limits`,
    );
  }
  assert.equal(Object.keys(shared.providers.openai.models).length, 18);
  assert.deepEqual(
    shared.providers.openai.models["gpt-5.3-codex-spark"].limit,
    { context: 128000, input: 100000, output: 32000 },
  );
  assert.equal(
    shared.providers.anthropic.models,
    undefined,
    "Meridian's discovered subscription context must remain authoritative",
  );
  const base = (name) => ({
    id: name,
    name,
    mode: ["build", "plan"].includes(name) ? "primary" : "subagent",
    permissions: [
      { action: "*", resource: "*", effect: "allow" },
      ...shared.permissions,
    ],
    request: { settings: {}, headers: {}, body: {} },
    hidden: false,
  });
  const registry = new Map(
    ["build", "plan", "explore", "general", "title"].map((name) => [
      name,
      base(name),
    ]),
  );
  const hooks = {};
  const sessions = new Map();
  const ctx = {
    options: { presets: file },
    agent: {
      transform: async (callback) =>
        callback({
          list: () => [...registry.values()],
          update: (id, change) => {
            const agent = registry.get(id) ?? base(id);
            change(agent);
            registry.set(id, agent);
          },
        }),
    },
    tool: {
      hook: async (name, callback) => {
        hooks[`tool.${name}`] = callback;
      },
    },
    session: {
      hook: async (name, callback) => {
        hooks[name] = callback;
      },
      get: async ({ sessionID }) => sessions.get(sessionID),
      switchAgent: async ({ sessionID, agent }) => {
        sessions.get(sessionID).agent = agent;
      },
    },
  };
  await plugin.setup(ctx);
  // Match the host's ordering: external transforms, shared config, then each
  // agent's native config. This catches global allow rules shadowing denies.
  for (const agent of registry.values())
    agent.permissions.push(...shared.permissions);
  for (const [id, config] of Object.entries(shared.agents)) {
    if (config.disabled) {
      registry.delete(id);
      continue;
    }
    const agent = registry.get(id) ?? base(id);
    const { permissions = [], model, ...fields } = config;
    Object.assign(agent, fields);
    if (model) agent.model = modelRef(model);
    agent.permissions.push(...permissions);
    registry.set(id, agent);
  }
  const permission = (agent, action, resource) => {
    const match = (pattern, value) =>
      new RegExp(
        "^" +
          pattern
            .replace(/[.+^${}()|[\]\\]/g, "\\$&")
            .replaceAll("*", ".*")
            .replaceAll("?", ".") +
          "$",
      ).test(value);
    return registry
      .get(agent)
      .permissions.filter(
        (rule) => match(rule.action, action) && match(rule.resource, resource),
      )
      .at(-1)?.effect;
  };
  for (const profile of Object.keys(presets.profiles)) {
    for (const reviewer of ["default", "fable", "opus"]) {
      const group = `oc-custom-${profile}-${reviewer}-`;
      assert.equal(
        registry.get(group + "review").model.id,
        (reviewer === "default"
          ? presets.profiles[profile].review.model
          : presets.reviewModels[reviewer]
        ).split("/")[1],
      );
      assert.equal(
        permission(group + "review", "edit", "src/Main.scala"),
        "deny",
      );
      assert.equal(
        permission(group + "plan", "shell", "git push origin main"),
        "deny",
      );
      assert.equal(
        permission(group + "plan", "shell", "git branch --show-current"),
        "allow",
      );
      assert.equal(
        permission(group + "build", "subagent", group + "review"),
        "allow",
      );
      assert.equal(
        permission(group + "review", "subagent", group + "explore"),
        "deny",
      );
      const event = {
        tool: "subagent",
        agent: group + "build",
        input: { agent: "review" },
      };
      await hooks["tool.execute.before"](event);
      assert.equal(event.input.agent, group + "review");
      assert.equal(
        permission(
          group + "build",
          "subagent",
          "oc-stock-openai-default-explore",
        ),
        "deny",
      );
    }
  }
  const custom = { agent: "oc-custom-balanced-default-build", system: [] };
  const stock = { agent: "build", system: [] };
  await hooks.context(custom);
  await hooks.context(stock);
  assert.equal(custom.system[0].text, presets.delegation);
  assert.deepEqual(stock.system, []);
  assert.equal(
    registry.get("build").system,
    undefined,
    "stock base has no custom instructions",
  );
  sessions.set("one", {
    id: "one",
    agent: "plan",
    metadata: { ocProfile: "oc-custom-premium-fable-" },
  });
  sessions.set("two", {
    id: "two",
    agent: "build",
    metadata: {
      ocProfile: "oc-stock-anthropic-default-",
      ocSelection: { mode: "stock", profile: "anthropic" },
    },
  });
  await Promise.all([
    hooks.prompt({ sessionID: "one" }),
    hooks.prompt({ sessionID: "two" }),
  ]);
  assert.equal(sessions.get("one").agent, "oc-custom-premium-fable-plan");
  assert.equal(sessions.get("two").agent, "build");
  const stockExplore = {
    tool: "subagent",
    sessionID: "two",
    agent: "build",
    input: { agent: "explore" },
  };
  await hooks["tool.execute.before"](stockExplore);
  assert.equal(
    stockExplore.input.agent,
    "explore",
    "stock mode keeps native/project agent definitions",
  );
  assert.equal(
    stockExplore.input.model,
    presets.profiles.anthropic.explore.model,
  );
  const stockProject = {
    tool: "subagent",
    sessionID: "two",
    agent: "build",
    input: { agent: "review" },
  };
  await hooks["tool.execute.before"](stockProject);
  assert.equal(
    stockProject.input.model,
    undefined,
    "stock mode leaves project-defined reviewers alone",
  );
  assert.equal(shared.compaction.buffer, 32000);
  assert.equal(shared.compaction.keep.tokens, 12000);
  assert.ok(shared.mcp.servers.playwright);
  assert.ok(!shared.plugin && !shared.agent && !shared.permission);
  console.log(
    "V2 profile isolation, model routing, instructions, and permissions passed",
  );
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
