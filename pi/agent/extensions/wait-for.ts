/**
 * wait_for — background polling for pi.
 *
 * Spawn any long-running condition check (deployments, pipelines, pods, curl
 * probes) in a detached background poller. The agent keeps working; when the
 * condition passes (or times out), pi wakes the session with a real user
 * message via pi.sendUserMessage(). No more sleep-loop tool calls burning
 * tokens.
 *
 * Tools:
 *   wait_for_start  — spawn a poller: { id, command, interval?, timeout?,
 *                     description? } — command must exit 0 when the
 *                     condition is MET (non-zero / empty output keeps polling).
 *   wait_for_status — list/check/cancel pollers.
 *   wait_for_check  — force an immediate check of one/all pollers (no waiting
 *                     for the next tick).
 *
 * State: /tmp/pi-wait-for/state.json (survives session restarts; pollers are
 * spawn-detached shell processes writing status files next to it).
 *
 * Wake: when a poller finishes, the extension calls
 * pi.sendUserMessage("wait_for: <description> — <result>", {triggerTurn:true})
 * so the agent genuinely continues the turn that was waiting.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { spawn, execFile } from "node:child_process";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  readdirSync,
  unlinkSync,
} from "node:fs";
import { join } from "node:path";

const STATE_DIR = "/tmp/pi-wait-for";
const STATE_FILE = join(STATE_DIR, "state.json");

type ToolResult = { content: { type: "text"; text: string }[]; details: Record<string, unknown> };

type Poller = {
  id: string;
  command: string;
  description: string;
  intervalSec: number;
  timeoutSec: number;
  startedAt: number;
  pid?: number;
  status: "running" | "met" | "timeout" | "cancelled" | "error";
  result?: string;
  finishedAt?: number;
};

function ensureDir(): void {
  if (!existsSync(STATE_DIR)) mkdirSync(STATE_DIR, { recursive: true });
}

function loadState(): Record<string, Poller> {
  ensureDir();
  if (!existsSync(STATE_FILE)) return {};
  try {
    return JSON.parse(readFileSync(STATE_FILE, "utf-8"));
  } catch {
    return {};
  }
}

function saveState(state: Record<string, Poller>): void {
  ensureDir();
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function runOnce(command: string, timeoutSec: number): Promise<{ code: number; output: string }> {
  return new Promise((resolve) => {
    execFile(
      "bash",
      ["-c", command],
      { timeout: Math.min(timeoutSec, 120) * 1000 },
      (err, stdout, stderr) => {
        resolve({
          code: err && (err as any).code === undefined ? -1 : ((err as any)?.code ?? 0),
          output: `${stdout}${stderr}`.trim().slice(0, 2000),
        });
      },
    );
  });
}

/** One check pass over all running pollers. Returns text of wakeups to send. */
async function checkRunning(pi: ExtensionAPI): Promise<string[]> {
  const state = loadState();
  const now = Date.now();
  const wakes: string[] = [];

  for (const p of Object.values(state)) {
    if (p.status !== "running") continue;

    if (now - p.startedAt > p.timeoutSec * 1000) {
      p.status = "timeout";
      p.finishedAt = now;
      p.result = `timed out after ${p.timeoutSec}s`;
      wakes.push(`wait_for [${p.id}] TIMEOUT: ${p.description} — condition never met within ${p.timeoutSec}s`);
      continue;
    }

    const res = await runOnce(p.command, 120);
    if (res.code === 0) {
      p.status = "met";
      p.finishedAt = now;
      p.result = res.output || "condition met";
      wakes.push(`wait_for [${p.id}] CONDITION MET: ${p.description}\n${res.output || ""}`.trim());
    } else if (res.code === -1 && /ETIMEDOUT|killed/i.test(res.output)) {
      // check command itself hung; leave running, next tick retries
      continue;
    }
  }

  if (wakes.length) saveState(state);
  return wakes;
}

/** Reap anything the previous session left running; report their outcomes. */
async function reconcileOrphans(pi: ExtensionAPI): Promise<string[]> {
  const state = loadState();
  const now = Date.now();
  const wakes: string[] = [];
  for (const p of Object.values(state)) {
    if (p.status !== "running") continue;
    // stale status file from a dead session: check once now
    const res = await runOnce(p.command, 60);
    if (res.code === 0) {
      p.status = "met";
      p.finishedAt = now;
      p.result = res.output || "condition met";
      wakes.push(`wait_for [${p.id}] CONDITION MET (reconciled): ${p.description}\n${res.output || ""}`.trim());
    } else if (now - p.startedAt > p.timeoutSec * 1000) {
      p.status = "timeout";
      p.finishedAt = now;
      p.result = "timed out (reconciled after restart)";
      wakes.push(`wait_for [${p.id}] TIMEOUT (reconciled): ${p.description}`);
    }
  }
  if (wakes.length) saveState(state);
  return wakes;
}

export default function (pi: ExtensionAPI) {
  ensureDir();

  let widgetBound = false;
  let tickTimer: NodeJS.Timeout | undefined;
  let widgetTimer: NodeJS.Timeout | undefined;

  // timers are session-scoped: they must die when the session ends or is
  // replaced (reload/new/resume/fork). Otherwise a still-running timer holds
  // a stale ctx and crashes on ctx.hasUI after the session is swapped.
  const clearTimers = (): void => {
    if (widgetTimer) clearInterval(widgetTimer);
    if (tickTimer) clearInterval(tickTimer);
    widgetTimer = undefined;
    tickTimer = undefined;
  };

  /** Render the wait_for widget: one line per active poller, plus footer status. */
  const renderWidget = (ctx: any): void => {
    if (!ctx?.hasUI || widgetBound) return;
    widgetBound = true;
    const state = loadState();
    const running = Object.values(state).filter((p) => p.status === "running");
    if (running.length === 0) {
      ctx.ui.setWidget("wait-for", undefined);
      ctx.ui.setStatus("wait-for", undefined);
      return;
    }
    const theme = ctx.ui.theme;
    const lines = running.map((p) => {
      const elapsed = Math.max(1, Math.round((Date.now() - p.startedAt) / 1000));
      const remaining = Math.max(0, p.timeoutSec - elapsed);
      const mm = Math.floor(elapsed / 60);
      const ss = String(elapsed % 60).padStart(2, "0");
      const t = mm > 0 ? `${mm}m${ss}s` : `${ss}s`;
      return (
        theme.fg("accent", "⏳ ") +
        theme.fg("text", `${p.id} `) +
        theme.fg("muted", `${p.description} — `) +
        theme.fg("dim", `${t} elapsed, ${remaining}s left`)
      );
    });
    ctx.ui.setWidget("wait-for", (tui: unknown, th: typeof theme) => {
      const updated = Object.values(loadState()).filter((p) => p.status === "running");
      if (updated.length === 0) return { render: () => [], invalidate: () => {} };
      const out = updated.map((p) => {
        const elapsed = Math.max(1, Math.round((Date.now() - p.startedAt) / 1000));
        const remaining = Math.max(0, p.timeoutSec - elapsed);
        const mm = Math.floor(elapsed / 60);
        const ss = String(elapsed % 60).padStart(2, "0");
        const t = mm > 0 ? `${mm}m${ss}s` : `${ss}s`;
        return (
          th.fg("accent", "⏳ ") +
          th.fg("text", `${p.id} `) +
          th.fg("muted", `${p.description} — `) +
          th.fg("dim", `${t} elapsed, ${remaining}s left`)
        );
      });
      return { render: () => out, invalidate: () => {} };
    });
    ctx.ui.setStatus(
      "wait-for",
      theme.fg("accent", `⏳ ${running.length} wait_for`),
    );
  };

  const tick = async (ctx?: any) => {
    try {
      const wakes = await checkRunning(pi);
      for (const w of wakes) {
        pi.sendUserMessage(w, { deliverAs: "followUp" });
      }
      if (ctx) renderWidget(ctx);
    } catch {
      // never crash the timer
    }
  };

  pi.on("session_start", async (_event, ctx) => {
    // a previous session's timers may still be running (reload/new/resume/fork
    // emits session_shutdown, but clear defensively so we never reuse a stale
    // captured ctx from the old session).
    clearTimers();
    const wakes = await reconcileOrphans(pi);
    for (const w of wakes) {
      pi.sendUserMessage(w, { deliverAs: "followUp" });
    }
    renderWidget(ctx);
    // poll every 20s and re-render every 5s, both bound to THIS session's ctx
    tickTimer = setInterval(() => tick(ctx), 20_000);
    tickTimer.unref?.();
    widgetTimer = setInterval(() => renderWidget(ctx), 5_000);
    widgetTimer.unref?.();
  });

  pi.on("session_shutdown", async () => {
    clearTimers();
  });

  const stateSummary = (): string => {
    const state = loadState();
    const rows = Object.values(state).map(
      (p) =>
        `${p.id}\t${p.status}\t${p.description}\t(interval ${p.intervalSec}s, timeout ${p.timeoutSec}s)${p.result ? `\n  ↳ ${p.result.slice(0, 300)}` : ""}`,
    );
    return rows.length ? rows.join("\n") : "no pollers";
  };

  pi.registerTool({
    name: "wait_for_start",
    label: "Wait For (start)",
    description:
      "Spawn a background condition poller. The command is run on an interval (default 20s) until it exits 0 (condition met) or times out (default 600s). While polling, the agent keeps working normally — no sleep loops. When the condition is met (or times out), pi is woken with a real message containing the command's output. Use for: ArgoCD syncs, GitLab pipelines, kubectl rollouts, HTTP probes, CI waits.",
    promptGuidelines: [
      "Use wait_for_start instead of sleep/polling loops whenever waiting on an external condition (deployments, pipelines, CI). The command must exit 0 exactly when the condition is met.",
    ],
    parameters: Type.Object({
      id: Type.String({ description: "Short unique id, e.g. uat-is-deploy" }),
      command: Type.String({
        description:
          "Shell command; exit 0 = condition met. Check only — do NOT mutate anything in the command.",
      }),
      description: Type.String({ description: "Human-readable what/why for the wake message" }),
      intervalSec: Type.Optional(Type.Number({ description: "Poll interval seconds (default 20, min 5)" })),
      timeoutSec: Type.Optional(Type.Number({ description: "Give up after N seconds (default 600)" })),
    }),
    async execute(_id, params) {
      const state = loadState();
      if (state[params.id] && state[params.id].status === "running") {
        return {
          content: [{ type: "text", text: `poller ${params.id} already running` }],
          details: { ok: false, poller: state[params.id] },
        };
      }
      const poller: Poller = {
        id: params.id,
        command: params.command,
        description: params.description,
        intervalSec: Math.max(params.intervalSec ?? 20, 5),
        timeoutSec: params.timeoutSec ?? 600,
        startedAt: Date.now(),
        status: "running",
      };
      state[params.id] = poller;
      saveState(state);

      // detached reaper process so the poller survives even if this pi session closes
      const child = spawn(
        "bash",
        [
          "-c",
          `while true; do
  if bash -c ${JSON.stringify(params.command)} >/tmp/pi-wait-for/${params.id}.out 2>&1; then echo met > /tmp/pi-wait-for/${params.id}.result; exit 0; fi
  if [ $(( $(date +%s) - ${Math.floor(poller.startedAt / 1000)} )) -ge ${poller.timeoutSec} ]; then echo timeout > /tmp/pi-wait-for/${params.id}.result; exit 1; fi
  sleep ${poller.intervalSec}
done`,
        ],
        { detached: true, stdio: "ignore" },
      );
      child.unref();
      poller.pid = child.pid;
      saveState(state);

      return {
        content: [
          {
            type: "text",
            text: `poller ${params.id} started (interval ${poller.intervalSec}s, timeout ${poller.timeoutSec}s). You will be woken automatically when it completes. Continue with other work.`,
          },
        ],
        details: { ok: true, poller },
      };
    },
  });

  // after wait_for_start returns, refresh the widget
  pi.on("agent_end", async (_event, ctx) => {
    if (ctx) renderWidget(ctx);
  });

  pi.registerTool({
    name: "wait_for_status",
    label: "Wait For (status)",
    description: "List all wait_for pollers and their current status/result. Pass an id to check one (runs an immediate check for running pollers).",
    parameters: Type.Object({
      id: Type.Optional(Type.String({ description: "Check a specific poller now" })),
    }),
    async execute(_id, params) {
      const state = loadState();
      if (params.id) {
        const p = state[params.id];
        if (!p) {
          return { content: [{ type: "text", text: `no poller ${params.id}` }], details: { ok: false } };
        }
        if (p.status === "running") {
          const res = await runOnce(p.command, 60);
          if (res.code === 0) {
            p.status = "met";
            p.finishedAt = Date.now();
            p.result = res.output || "condition met";
            saveState(state);
          }
        }
        const result: ToolResult = {
          content: [{ type: "text", text: `${p.id}: ${p.status}\n${p.result ?? ""}`.trim() }],
          details: { ok: true, poller: p },
        };
        return result;
      }
      return { content: [{ type: "text", text: stateSummary() }], details: { ok: true } };
    },
  });

  pi.registerTool({
    name: "wait_for_cancel",
    label: "Wait For (cancel)",
    description: "Cancel a running poller.",
    parameters: Type.Object({
      id: Type.String({ description: "Poller id" }),
    }),
    async execute(_id, params, _signal, _onUpdate, ctx) {
      const state = loadState();
      const p = state[params.id];
      if (!p) {
        return { content: [{ type: "text", text: `no poller ${params.id}` }], details: { ok: false } };
      }
      p.status = "cancelled";
      p.finishedAt = Date.now();
      saveState(state);
      if (p.pid) {
        try {
          process.kill(-p.pid, "SIGTERM"); // kill the detached group
        } catch {
          /* already gone */
        }
      }
      return { content: [{ type: "text", text: `cancelled ${params.id}` }], details: { ok: true } };
    },
  });

  // cancel + status should also refresh widget on next tick; do it immediately
  pi.registerCommand("wait-for", {
    description: "Toggle wait_for poller widget visibility",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) return;
      const state = loadState();
      const running = Object.values(state).filter((p) => p.status === "running");
      if (running.length === 0) {
        ctx.ui.notify("no active wait_for pollers", "info");
        ctx.ui.setWidget("wait-for", undefined);
        ctx.ui.setStatus("wait-for", undefined);
        widgetBound = false;
        return;
      }
      ctx.ui.setWidget("wait-for", undefined);
      ctx.ui.setStatus("wait-for", undefined);
      widgetBound = false;
      renderWidget(ctx);
      ctx.ui.notify(
        `wait_for: ${running.map((p) => p.id).join(", ")}`,
        "info",
      );
    },
  });
}
