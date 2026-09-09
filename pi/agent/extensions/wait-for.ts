/**
 * wait_for — background polling for pi (session-scoped).
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
 *   wait_for_cancel — cancel a running poller.
 *
 * Ownership: each poller belongs to the pi session that started it
 * (ctx.sessionManager.getSessionId()). State is kept in a per-session file
 * (/tmp/pi-wait-for/state-<sessionId>.json), so a poller finishing wakes only
 * its owning session — never every live session on the machine. The detached
 * reaper processes and per-session status files survive session restarts;
 * resuming the same session id reconciles and delivers the outcome.
 *
 * Wake: when a poller finishes, the extension calls
 * pi.sendUserMessage("wait_for: <description> — <result>", {triggerTurn:true})
 * so the agent genuinely continues the turn that was waiting.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { spawn, execFile } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const STATE_DIR = "/tmp/pi-wait-for";
/** Legacy pre-ownership state file; defused on first new-session start. */
const LEGACY_STATE_FILE = join(STATE_DIR, "state.json");

type ToolResult = { content: { type: "text"; text: string }[]; details: Record<string, unknown> };

type Poller = {
  id: string;
  command: string;
  description: string;
  intervalSec: number;
  timeoutSec: number;
  startedAt: number;
  /** Session id that started this poller — only that session may check/wake/cancel it. */
  owner?: string;
  pid?: number;
  status: "running" | "met" | "timeout" | "cancelled" | "error";
  result?: string;
  finishedAt?: number;
};

function ensureDir(): void {
  if (!existsSync(STATE_DIR)) mkdirSync(STATE_DIR, { recursive: true });
}

/** Filesystem-safe encoding of a session id for the per-session state file. */
function safeOwner(owner: string): string {
  return owner.replace(/[^A-Za-z0-9_.-]/g, "_");
}

function stateFileFor(owner: string): string {
  return join(STATE_DIR, `state-${safeOwner(owner)}.json`);
}

function loadFor(owner: string): Record<string, Poller> {
  ensureDir();
  const file = stateFileFor(owner);
  if (!existsSync(file)) return {};
  try {
    return JSON.parse(readFileSync(file, "utf-8"));
  } catch {
    return {};
  }
}

function saveFor(owner: string, state: Record<string, Poller>): void {
  ensureDir();
  writeFileSync(stateFileFor(owner), JSON.stringify(state, null, 2));
}

function loadLegacy(): Record<string, Poller> {
  if (!existsSync(LEGACY_STATE_FILE)) return {};
  try {
    return JSON.parse(readFileSync(LEGACY_STATE_FILE, "utf-8"));
  } catch {
    return {};
  }
}

function saveLegacy(state: Record<string, Poller>): void {
  ensureDir();
  writeFileSync(LEGACY_STATE_FILE, JSON.stringify(state, null, 2));
}

function runOnce(command: string, timeoutSec: number): Promise<{ code: number; output: string }> {
  return new Promise((resolve) => {
    execFile(
      "bash",
      ["-c", command],
      { timeout: Math.min(timeoutSec, 120) * 1000 },
      (err, stdout, stderr) => {
        const code =
          err && (err as any).code === undefined ? -1 : ((err as any)?.code ?? 0);
        resolve({
          code,
          output: `${stdout}${stderr}`.trim().slice(0, 2000),
        });
      },
    );
  });
}

/** One check pass over the pollers owned by {@code owner}. Returns wake text. */
async function checkRunning(owner: string): Promise<string[]> {
  const state = loadFor(owner);
  const now = Date.now();
  const wakes: string[] = [];
  let changed = false;

  for (const p of Object.values(state)) {
    if (p.status !== "running") continue;

    if (now - p.startedAt > p.timeoutSec * 1000) {
      p.status = "timeout";
      p.finishedAt = now;
      p.result = `timed out after ${p.timeoutSec}s`;
      wakes.push(`wait_for [${p.id}] TIMEOUT: ${p.description} — condition never met within ${p.timeoutSec}s`);
      changed = true;
      continue;
    }

    const res = await runOnce(p.command, 120);
    if (res.code === 0) {
      p.status = "met";
      p.finishedAt = now;
      p.result = res.output || "condition met";
      wakes.push(`wait_for [${p.id}] CONDITION MET: ${p.description}\n${res.output || ""}`.trim());
      changed = true;
    }
    // res.code === -1 && /ETIMEDOUT|killed/ = check command hung; leave running, next tick retries
  }

  if (changed) saveFor(owner, state);
  return wakes;
}

/** Deliver outcomes of this session's own pollers left running by an earlier incarnation. */
async function reconcileOwn(owner: string): Promise<string[]> {
  const state = loadFor(owner);
  const now = Date.now();
  const wakes: string[] = [];
  let changed = false;
  for (const p of Object.values(state)) {
    if (p.status !== "running") continue;
    const res = await runOnce(p.command, 60);
    if (res.code === 0) {
      p.status = "met";
      p.finishedAt = now;
      p.result = res.output || "condition met";
      wakes.push(`wait_for [${p.id}] CONDITION MET (reconciled): ${p.description}\n${res.output || ""}`.trim());
      changed = true;
    } else if (now - p.startedAt > p.timeoutSec * 1000) {
      p.status = "timeout";
      p.finishedAt = now;
      p.result = "timed out (reconciled after restart)";
      wakes.push(`wait_for [${p.id}] TIMEOUT (reconciled): ${p.description}`);
      changed = true;
    }
  }
  if (changed) saveFor(owner, state);
  return wakes;
}

/**
 * Mark pre-ownership pollers cancelled so older buggy sessions (which tick the
 * shared legacy file) stop waking every session with their completions. One
 * write per new-session start; entries already cancelled stay cancelled.
 */
function defuseLegacy(): void {
  const legacy = loadLegacy();
  let changed = false;
  for (const p of Object.values(legacy)) {
    if (p.status === "running" && !p.owner) {
      p.status = "cancelled";
      p.finishedAt = Date.now();
      p.result = "superseded: wait_for is now session-scoped; restart the starting session and re-run";
      changed = true;
    }
  }
  if (changed) saveLegacy(legacy);
}

export default function (pi: ExtensionAPI) {
  ensureDir();

  /** This session's id, captured from ctx (stable across resume of the same session). */
  let mySessionId: string | null = null;

  const captureOwner = (ctx?: any): string => {
    const id = ctx?.sessionManager?.getSessionId?.() ?? null;
    if (id && typeof id === "string") mySessionId = id;
    return mySessionId ?? "default";
  };

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

  /** Render the wait_for widget for THIS session's own pollers. */
  const renderWidget = (ctx: any): void => {
    if (!ctx?.hasUI || widgetBound) return;
    widgetBound = true;
    const state = loadFor(captureOwner(ctx));
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
      const updated = Object.values(loadFor(captureOwner(ctx))).filter((p) => p.status === "running");
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

  const tick = async (ctx?: any): Promise<void> => {
    try {
      const owner = captureOwner(ctx);
      const wakes = await checkRunning(owner);
      for (const w of wakes) {
        pi.sendUserMessage(w, { deliverAs: "followUp" });
      }
      if (ctx) renderWidget(ctx);
    } catch {
      // never crash the timer
    }
  };

  pi.on("session_start", async (_event, ctx) => {
    // A previous session's timers may still be running (reload/new/resume/fork
    // emits session_shutdown, but clear defensively so we never reuse a stale
    // captured ctx from the old session).
    clearTimers();
    const owner = captureOwner(ctx);
    // Old shared-state pollers would otherwise wake every live session; defuse them.
    defuseLegacy();
    const wakes = await reconcileOwn(owner);
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

  const stateSummary = (owner: string): string => {
    const state = loadFor(owner);
    const rows = Object.values(state).map(
      (p) =>
        `${p.id}\t${p.status}\t${p.description}\t(interval ${p.intervalSec}s, timeout ${p.timeoutSec}s)${p.result ? `\n  ↳ ${p.result.slice(0, 300)}` : ""}`,
    );
    return rows.length ? rows.join("\n") : "no pollers for this session";
  };

  pi.registerTool({
    name: "wait_for_start",
    label: "Wait For (start)",
    description:
      "Spawn a background condition poller scoped to the current session. The command is run on an interval (default 20s) until it exits 0 (condition met) or times out (default 600s). While polling, the agent keeps working normally — no sleep loops. When the condition is met (or times out), ONLY this session is woken with a real message containing the command's output. Use for: ArgoCD syncs, GitLab pipelines, kubectl rollouts, HTTP probes, CI waits.",
    promptGuidelines: [
      "Use wait_for_start instead of sleep/polling loops whenever waiting on an external condition (deployments, pipelines, CI). The command must exit 0 exactly when the condition is met. Pollers are session-scoped: other pi sessions will not see or be woken by them.",
    ],
    parameters: Type.Object({
      id: Type.String({ description: "Short unique id within this session, e.g. uat-is-deploy" }),
      command: Type.String({
        description:
          "Shell command; exit 0 = condition met. Check only — do NOT mutate anything in the command.",
      }),
      description: Type.String({ description: "Human-readable what/why for the wake message" }),
      intervalSec: Type.Optional(Type.Number({ description: "Poll interval seconds (default 20, min 5)" })),
      timeoutSec: Type.Optional(Type.Number({ description: "Give up after N seconds (default 600)" })),
    }),
    async execute(_id, params, _signal, _onUpdate, ctx) {
      const owner = captureOwner(ctx);
      const state = loadFor(owner);
      if (state[params.id] && state[params.id].status === "running") {
        return {
          content: [{ type: "text", text: `poller ${params.id} already running in this session` }],
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
        owner,
        status: "running",
      };
      state[params.id] = poller;
      saveFor(owner, state);

      // detached reaper process so the poller survives even if this pi session closes
      const resultFile = `/tmp/pi-wait-for/${safeOwner(owner)}-${params.id}.result`;
      const child = spawn(
        "bash",
        [
          "-c",
          `while true; do
  if bash -c ${JSON.stringify(params.command)} >/tmp/pi-wait-for/${safeOwner(owner)}-${params.id}.out 2>&1; then echo met > ${resultFile}; exit 0; fi
  if [ $(( $(date +%s) - ${Math.floor(poller.startedAt / 1000)} )) -ge ${poller.timeoutSec} ]; then echo timeout > ${resultFile}; exit 1; fi
  sleep ${poller.intervalSec}
done`,
        ],
        { detached: true, stdio: "ignore" },
      );
      child.unref();
      poller.pid = child.pid;
      saveFor(owner, state);

      return {
        content: [
          {
            type: "text",
            text: `poller ${params.id} started for this session (interval ${poller.intervalSec}s, timeout ${poller.timeoutSec}s). You will be woken automatically when it completes; other sessions are not affected. Continue with other work.`,
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
    description:
      "List this session's wait_for pollers and their current status/result. Pass an id to check one (runs an immediate check for running pollers).",
    parameters: Type.Object({
      id: Type.Optional(Type.String({ description: "Check a specific poller now" })),
    }),
    async execute(_id, params, _signal, _onUpdate, ctx) {
      const owner = captureOwner(ctx);
      const state = loadFor(owner);
      if (params.id) {
        const p = state[params.id];
        if (!p) {
          return { content: [{ type: "text", text: `no poller ${params.id} in this session` }], details: { ok: false } };
        }
        if (p.status === "running") {
          const res = await runOnce(p.command, 60);
          if (res.code === 0) {
            p.status = "met";
            p.finishedAt = Date.now();
            p.result = res.output || "condition met";
            saveFor(owner, state);
          }
        }
        const result: ToolResult = {
          content: [{ type: "text", text: `${p.id}: ${p.status}\n${p.result ?? ""}`.trim() }],
          details: { ok: true, poller: p },
        };
        return result;
      }
      return { content: [{ type: "text", text: stateSummary(owner) }], details: { ok: true } };
    },
  });

  pi.registerTool({
    name: "wait_for_cancel",
    label: "Wait For (cancel)",
    description: "Cancel a running poller owned by this session.",
    parameters: Type.Object({
      id: Type.String({ description: "Poller id" }),
    }),
    async execute(_id, params, _signal, _onUpdate, ctx) {
      const owner = captureOwner(ctx);
      const state = loadFor(owner);
      const p = state[params.id];
      if (!p) {
        return { content: [{ type: "text", text: `no poller ${params.id} in this session` }], details: { ok: false } };
      }
      p.status = "cancelled";
      p.finishedAt = Date.now();
      saveFor(owner, state);
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
      const state = loadFor(captureOwner(ctx));
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
