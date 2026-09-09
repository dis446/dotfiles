---
description: Deep-review a GitLab MR of this repo against AGENTS.md + repo standards (accuracy, viability, maintainability, code quality, standards)
argument-hint: "<MR number>"
---
Review GitLab MR $1
(https://git.and.global/alpha/back-end/bpm/flow-generator/-/merge_requests/$1)
of this repo (AND Alpha flow config) for: accuracy, viability, maintainability,
code quality, and adherence to repo standards. You are READ-ONLY: do not edit
definitions, do not seed any environment, do not merge. Produce a findings
report and a recommendation.

## 1. Orient before judging

- Read `AGENTS.md` (repo root) — the authoritative convention set (authoring
  model, status vocabulary, pitfalls, collaboration guardrails).
- Load matching skills from `.agents/skills/` by MR surface:
  `afs-flow-config-editing` (definition/n8n traps), `state-machine-visual-layout`
  (positions/layout), `n8n-api` (workflow/execution diagnosis),
  `afs-requirements` (spec — only if the afs-spec checkout is reachable; never
  guess the spec).
- Read `docs/AFS-LOS-Onboarding-Flow-Analysis.md` for the shared machinery the
  flows compose (state kinds, mocks, relation-store structures, engine gaps).

## 2. Identify the MR and read its description

- `glab mr view $1` — title, author, state, source → target (usually → dev),
  draft, mergeable.
- `glab ci get --merge-request $1 -F json` — head pipeline status.
- `glab api projects/:id/merge_requests/$1/approvals` — approval state.
- `git merge-base origin/dev origin/<source-branch>` and
  `git log --oneline dev..origin/<source-branch>` (source branch from the mr
  view). `git diff --stat dev...origin/<source-branch>`.
- These MRs document design + DELIBERATE spec deviations in the MR description
  AND the state machine's `metadata.description`. Read both, then cross-check
  claims against the files — discrepancies are findings.

## 3. Standards & semantic checklist

Judge against the closest MERGED sibling of the same family (onboarding /
change-* / shared), not in the abstract.

- State machine: one start; one transition per (from, to); conditions unique
  per source state; every rule-engine decision exists as a transition on the
  gate's state; FAIL edges/terminals follow family convention (norm even though
  the engine blocks FAIL walking — documented platform gap, not an MR bug).
- `@kind:name` placeholders: every @form/@evalgroup/@task/@template the SM uses
  is listed in the flow's `manifest.sh` and resolves to a real owner; borrowed
  defs are referenced cross-flow (onboarding / tenants/<tenant>/shared), never
  forked.
- AUTO_REJECT pitfall: fixable / verification-failure outcomes must NOT fall
  back to REJECT/REJECTED (rule-engine handler maps those to decisionCode
  AUTO_REJECT + lockout flag). Expect CANCEL or a distinct condition instead.
- Status vocabulary: no invented statuses; application_status backbone
  DRAFT→UNDERWRITING→APPROVED→CONTRACTED + RETURNED loop, terminals
  REJECTED/CANCELLED; kyc/income/employment sub-statuses per AGENTS.md;
  decisionCode→MainStatus (REJECT→REJECTED, CANCEL→CANCELLED, else COMPLETE)
  consistent with each decision-state continue call.
- Forms: unscoped `_name`; labels bilingual "EN | JA" (never translate API
  tokens/enums); `canonicalKey` only on real data forms, never informational/
  reject screens.
- Rule sets: executionType + pass/fallback sane; description records WHY (esp.
  spec approximations); rule vars deref against structures the vendor mocks
  actually persist.
- n8n: every N8N_TRIGGER path registered in `tenants/<tenant>/n8n/vendors.sh`
  (mock vs real); webhook path = idempotency key; mock response
  `decision`/`transition` matches the SM edge the state expects; new real
  workflows sourced + dispatched in `seed/n8n/afs-n8n.sh`; borrowed mocks reused.
- Tasks: MANUAL, `_roleGroupNames`, `roleGroupIds` resolved at seed; shared
  tasks borrowed from owners.
- bruno/: flow change requires the collection in sync — new flow → top-level
  folder `<NN>-<Flow-Name>` (seq pattern 00=1, 10=2, 20=3 …), per-folder seq
  strictly increasing, folder.yml present, every `{{var}}` resolves (env or
  captured), environments yml updated. Check mechanically (yaml + seq + var
  scan).
- test/: `test/form` submitters are onboarding+POC only — flag, don't block, on
  missing k6/walker coverage. But if the MR's docs claim the walker/k6 can drive
  a form with no registered submitter (handleFormSubmission aborts on unknown
  forms), call that doc inaccuracy out.
- New flows: plan doc in `docs/plans/`; seed sequencing documented (70-n8n
  before 60-state-machine; AFS_SM_ALLOW_CREATE=true on first SM seed, then the
  metadata.deployedIds pin is committed); missing deployedIds is expected
  pre-first-seed.

## 4. Code-quality pass (n8n builders: bash heredoc + JS + jq)

- Trap awareness: HTTP nodes REPLACE output json (deref earlier nodes BY NAME,
  not $json); onError=continueRegularOutput turns failures into {error} items —
  read `json.error`, not isError/statusCode; Execute Sub-workflow returns the
  callee's LAST node output (mocks end the sub-workflow leg on Sub-workflow
  Return emitting the {requestId, status, data} envelope); executeWorkflow nodes
  address by seed-time-resolved workflow id; free-text bodies via
  JSON.stringify.
- Stable literal ids inside `parameters` (If-node conditions) so the seeder's
  convergence check does not re-PUT on every run; no committed instance-specific
  ids.
- Helpers reused from lib/change/common.sh / lib/cis/common.sh / lib/workflow.sh
  — duplicated logic is a finding.
- shellcheck-clean; comment density matches siblings (dense on purpose).

## 5. Verification — run the CI gates in a worktree (strongest signal)

    git worktree add /tmp/mr-review-$1 origin/<source-branch> && cd /tmp/mr-review-$1
    git diff --name-only dev...HEAD -- '*.sh'   | xargs -r shellcheck --severity=error
    git diff --name-only dev...HEAD -- '*.json' | xargs -r -n1 jq empty
    git diff --name-only dev...HEAD -- '*.json' | xargs -r npx -y @biomejs/biome@2 lint
    git diff --name-only -z dev...HEAD -- '*.yml' | xargs -0 -n1 python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))'
    python3 validate.py    # deep flow checks — warnings (re-use, missing deployedIds) often expected

Use `-z`/`-0` for bruno yml (spaces in filenames). Remove the worktree after.

## 6. Report — structure the reply

1. Verdict: approve / approve-with-follow-ups / changes-requested.
2. Findings by severity (blocker / major / minor / nit): file path, what's
   wrong, concrete fix, why it matters. No severity inflation.
3. Verified-correct list: what you actually checked and confirmed.
4. Merge readiness: pipeline status, approvals, mergeable, branch vs dev state.

Do NOT merge or edit — that stays with the requester/lead.
