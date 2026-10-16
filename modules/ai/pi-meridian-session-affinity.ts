import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Without a session key, Meridian treats every tool-loop turn as a new
// conversation: the model loses its own previous turns and the prompt cache
// is rebuilt each round. See Meridian's docs/configuration.md.
export default function (pi: ExtensionAPI) {
  pi.on("before_provider_headers", (event, ctx) => {
    if (ctx.model?.provider !== "anthropic") return;
    const sessionId = ctx.sessionManager.getSessionId();
    if (sessionId) event.headers["x-session-affinity"] = sessionId;
  });
}
