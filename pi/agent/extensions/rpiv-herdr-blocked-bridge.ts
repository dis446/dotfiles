// Bridges @juicesharp/rpiv-ask-user-question's blocked wait onto herdr's pi
// integration. herdr's herdr-agent-state.ts classifies pi state solely from its
// own `herdr:blocked` event (screen detection is skipped, reason
// full_lifecycle_hook_authority), while rpiv publishes on a separate,
// immutable channel. Without this bridge a questionnaire still reads "working".
//
// Kept beside the herdr-managed extension on purpose: reinstalling or updating
// that integration overwrites herdr-agent-state.ts, not this file.
// @ts-nocheck

// Channel names are part of rpiv's public, immutable event contract
// (@juicesharp/rpiv-ask-user-question/events), so they are inlined rather than
// imported — no resolution dependency on the package's inversion-layer path.
const ASK_USER_PROMPT_EVENT = "rpiv:ask-user:prompt";
const ASK_USER_BLOCKED_EVENT = "rpiv:ask-user:blocked";

export default function (pi) {
  if (process.env.HERDR_ENV !== "1") {
    return;
  }

  let label = "question";

  // ask_user_question always emits the prompt event before the blocked event,
  // so the first header is available as the blocked-state message.
  pi.events.on(ASK_USER_PROMPT_EVENT, (data) => {
    const header = data?.questions?.[0]?.header;
    if (typeof header === "string" && header.length > 0) {
      label = header;
    }
  });

  pi.events.on(ASK_USER_BLOCKED_EVENT, (data) => {
    pi.events.emit("herdr:blocked", { active: !!data?.active, label });
  });
}
