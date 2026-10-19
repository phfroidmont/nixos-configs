import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// Board tasks work in ~/Projects/.worktrees, where no Neovim runs Metals.
// A worktree whose setup ran `mill --bsp-install` gets its own headless Metals;
// pi starts it with the session and stops it with the session.
const worktrees = join(homedir(), "Projects", ".worktrees") + "/";

// Elsewhere Neovim runs Metals with startMcpServer and mcpClient = "opencode",
// so Metals writes its MCP endpoint into the project's opencode.json.
// A second Metals on the same workspace would fight Neovim's over .metals/,
// so pi joins Neovim's instead.
function neovimMetalsUrl(cwd: string): string | undefined {
  const file = join(cwd, "opencode.json");
  if (!existsSync(file)) return undefined;
  try {
    const config = JSON.parse(readFileSync(file, "utf8"));
    const url = config?.mcp?.["metals-lsp"]?.url;
    return typeof url === "string" ? url : undefined;
  } catch {
    return undefined;
  }
}

export default function (pi: ExtensionAPI) {
  const cwd = process.cwd();

  if (cwd.startsWith(worktrees)) {
    if (!existsSync(join(cwd, ".bsp"))) return;
    pi.registerMcpServer("metals", {
      command: "metals-mcp-worktree",
      args: [cwd],
      // pi shows the first line, up to 250 characters, in the system prompt.
      description:
        "Metals for this Scala worktree: compile diagnostics, symbol search, types, docs, usages. " +
        "It needs about a minute after start; if it reports no modules, run `sleep 15` in bash and retry.",
      // A compile after a dependency change can take minutes.
      timeout: 900,
    });
    return;
  }

  const url = neovimMetalsUrl(cwd);
  if (!url) return;
  pi.registerMcpServer("metals", {
    url,
    description:
      "Metals of the Neovim editing this Scala project: compile diagnostics, symbol search, types, docs, usages. " +
      "Unreachable when that Neovim is closed; after reopening it, run /reload.",
    timeout: 900,
  });
}
