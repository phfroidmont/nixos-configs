import { readFileSync } from "node:fs";

export function modelRef(value) {
  const [model, variant] = value.split("#");
  const slash = model.indexOf("/");
  return {
    providerID: model.slice(0, slash),
    id: model.slice(slash + 1),
    ...(variant ? { variant } : {}),
  };
}

export function prefix(mode, profile, reviewer = "default") {
  return `oc-${mode}-${profile}-${reviewer}-`;
}

// Each suite has immutable agent IDs. Selecting a suite changes a session,
// never the daemon's defaults or another client's agent registry entries.
export default {
  id: "local.oc-profiles",
  async setup(ctx) {
    const presets = JSON.parse(readFileSync(ctx.options.presets, "utf8"));
    const groups = new Map();
    await ctx.agent.transform((editor) => {
      const originals = new Map(
        editor.list().map((agent) => [agent.id, structuredClone(agent)]),
      );
      for (const profile of Object.keys(presets.profiles)) {
        for (const reviewer of ["default", "fable", "opus"]) {
          const group = prefix("custom", profile, reviewer);
          const definitions = presets.custom;
          const names = Object.keys(definitions).filter(
            (name) => !definitions[name].disabled,
          );
          groups.set(group, new Set(names));
          for (const name of names) {
            editor.update(group + name, (agent) => {
              // Config's built-in transform runs after external plugins.
              // Clone defaults here; native agents.<id> config applies model,
              // prompt and permissions later, after the shared policy.
              const base = originals.get(name);
              if (base) Object.assign(agent, structuredClone(base));
              agent.id = group + name;
              agent.name = `${name} (${profile}${reviewer === "default" ? "" : `, ${reviewer}`})`;
              agent.hidden = true;
            });
          }
        }
      }
    });

    const groupFor = (agent) =>
      [...groups.keys()].find((group) => agent?.startsWith(group));
    await ctx.session.hook("context", (event) => {
      const group = groupFor(event.agent);
      if (
        group?.startsWith("oc-custom-") &&
        ["build", "plan"].includes(event.agent.slice(group.length))
      ) {
        event.system.push({ type: "text", text: presets.delegation });
        if (event.tools?.subagent) {
          const caller = presets.custom[event.agent.slice(group.length)];
          const available = Object.entries(presets.custom).filter(
            ([name, definition]) => {
              if (definition.disabled || definition.mode !== "subagent")
                return false;
              return (
                caller.permissions
                  .filter(
                    (rule) =>
                      rule.action === "subagent" &&
                      (rule.resource === "*" || rule.resource === name),
                  )
                  .at(-1)?.effect === "allow"
              );
            },
          );
          event.tools.subagent.description +=
            "\nAvailable session-profile aliases:\n" +
            available
              .map(
                ([name, definition]) => `- ${name}: ${definition.description}`,
              )
              .join("\n");
        }
      }
    });
    await ctx.tool.hook("execute.before", async (event) => {
      if (event.tool !== "subagent") return;
      const group = groupFor(event.agent);
      if (group && groups.get(group).has(event.input.agent)) {
        event.input.agent = group + event.input.agent;
        return;
      }
      const session = await ctx.session.get({ sessionID: event.sessionID });
      const selection = session.metadata?.ocSelection;
      if (selection?.mode === "stock") {
        if (event.input.agent.startsWith("oc-"))
          throw new Error(
            "Private custom agents are unavailable in stock mode",
          );
        const model = ["explore", "general"].includes(event.input.agent)
          ? presets.profiles[selection.profile]?.[event.input.agent]?.model
          : undefined;
        if (model && !event.input.model) event.input.model = model;
      }
    });
    // Tab-switching back to the built-in build/plan agent retains this session's
    // suite. Metadata is persisted by oc and inherited by child sessions.
    await ctx.session.hook("prompt", async (event) => {
      const session = await ctx.session.get({ sessionID: event.sessionID });
      const group = session.metadata?.ocProfile;
      const selectedGroup = groupFor(session.agent);
      const name = selectedGroup
        ? session.agent.slice(selectedGroup.length)
        : session.agent;
      if (
        groups.has(group) &&
        groups.get(group).has(name) &&
        session.agent !== group + name
      ) {
        await ctx.session.switchAgent({
          sessionID: session.id,
          agent: group + name,
        });
      } else if (
        session.metadata?.ocSelection?.mode === "stock" &&
        selectedGroup &&
        ["build", "plan"].includes(name)
      ) {
        await ctx.session.switchAgent({ sessionID: session.id, agent: name });
      }
    });
  },
};
