import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// Board tasks work in ~/Projects/.worktrees, where no Neovim runs Metals.
// A worktree whose setup ran `mill --bsp-install` gets its own headless Metals;
// pi starts it with the session and stops it with the session.
const worktrees = join(homedir(), "Projects", ".worktrees") + "/";

export default function (pi: ExtensionAPI) {
  const cwd = process.cwd();
  if (!cwd.startsWith(worktrees)) return;
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
}
