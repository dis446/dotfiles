import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execSync } from "node:child_process";
import { basename } from "node:path";

function notify(repo: string, session: string | null): void {
  const summary = session ? `${repo} [${session}]` : repo;
  const body   = session ? `tmux session "${session}" ready` : "pi ready for next prompt";
  try {
    execSync(
      `notify-send "Pi Done" "${summary}: ${body}"`,
      { timeout: 3000, stdio: "ignore" },
    );
  } catch {
    // notify-send can fail on headless or slow; not worth logging
  }
}

function getTmuxSession(): string | null {
  if (!process.env.TMUX) return null;
  try {
    return execSync("tmux display-message -p '#S'", {
      timeout: 2000,
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim() || null;
  } catch {
    return null;
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (_event, ctx) => {
    const repo    = basename(ctx.cwd);
    const session = getTmuxSession();
    notify(repo, session);
  });
}
