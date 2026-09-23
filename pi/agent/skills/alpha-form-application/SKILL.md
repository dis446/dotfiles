---
name: alpha-form-application
description: >-
  Build a Form.io application end to end from a plain-language idea: Intent → Plan (`alpha-form-resource-planner`) → template import (POST /import) → framework routing to React portals. Use when the user wants an app, tool, portal, dashboard, or tracker around data. Not for: data-model planning alone (see `alpha-form-resource-planner`); embedding a form (see `alpha-form-form`); standalone single forms (see `alpha-form-form-builder`); REST endpoints (see `alpha-form-api`).
---

# Form.io Application Orchestrator (alpha fork)

You are the library's default "build me an app" skill. When a user describes an app they want built — OR a feature they want added to an existing app — in any domain, in any phrasing, with or without naming a UI framework, your job is to drive the full pipeline from plain-language intent to a running application (or a running added feature). The user should never have to know Form.io terminology, choose a framework when only one is installed, or manually invoke the planner or any framework-specific skill. You do the routing; they describe what they want.

## Preflight — resolve the target deployment (direct REST, no MCP server)

This library has no MCP server and no `@formio/mcp` tooling — there is no `project get`/`project set`, no `~/.formio` mapping, no browser portal-login. The "project" is the **CE deployment** and its template. Before the first write, resolve three things:

1. **CE base URL** — `FORMIO_BASE_URL` (e.g. `https://form-dev.alpha.looms.cloud`). This is where the template imports land.
2. **Admin credential** — the `x-token` header whose value is in the CE server's `API_KEYS` env var (service auth; see [`alpha-form-auth`](../alpha-form-auth/SKILL.md) → [`references/service-auth.md`](../alpha-form-auth/references/service-auth.md)).
3. **Target template path** — where the planner's `template.json` goes. Default: the CE fork's `default-template.json` (bootstrap-style). For per-tenant work through the middleware, additionally confirm the tenant org UUID (`x-api-gw-organization-uuid`) — see [`_shared/stack.md`](_shared/stack.md).

Ask for the base URL and tenant UUID (when relevant) in one question round; never invent a base URL and never reuse one from another deployment. State the resolved base URL in one line before any write so a wrong target is caught.

The stack facts below are the single source of truth for every skill — see [`_shared/stack.md`](_shared/stack.md) and do not drift from it.

## Stance

- **Translate, do not interrogate.** Lead with a plain-language restatement of what the app (or the new feature) will DO and let the user confirm or correct. Never open the conversation with Form.io or framework jargon.
- **One step at a time, left to right.** Intent → Plan → Import → Framework, with the target deployment already resolved by the Preflight above. Each step that writes files or imports into a live deployment ends with an approval gate. A declined gate stops the flow; partial state is never left behind.
- **Route, do not reimplement.** Planning lives in `alpha-form-resource-planner`. Framework work lives in the React portals / `@formio/react` fork (monorepo `packages/react`). Your job is to orchestrate the handoffs, not to duplicate their logic.
- **A standalone form is not an app.** If, at any point — the opening request or a mid-orchestration clarification ("actually I just need a feedback form, not a whole app") — the intent turns out to be a single standalone FORM to collect responses (not a resource, not a data model, not an app), hand off to `alpha-form-form-builder` instead of running the planner/import pipeline. That skill captures embed intent itself, so "a form that might go into an app later" still belongs to it.
- **Pick the right kind per entity — Resource or Form.** Most of what users describe is a reusable **data model** (a Resource — Contact, Product, Project), and many apps are entirely Resources — that is correct and common. Some entities are instead **bespoke data collection** (a Form — a job application, a survey, an RSVP, an intake/feedback form). The planner makes this call per entity; do not force everything into Resources, and equally do not force an entity into a Form when a Resource fits. When the user's request is clearly survey-like or one-off (e.g., "a form for people to apply"), say so in your plain-language restatement so the planner can classify it as a Form. See `../alpha-form-resource-planner/SKILL.md` → "Resources vs. Forms — the core modeling decision".
- **Modify-existing still plans and imports.** If the user is extending an already-running app, still run the planner (in delta mode — it plans ONLY the new resources/fields/actions for the feature) and still import the delta template (import is additive — adding new resources to the existing deployment is safe). Then route to the framework's extend path with the new resources in hand.
- **Batch your questions.** When input is needed (the framework pick in Step 4), ask everything that step needs in ONE question round. Do not pepper.
- **Respect `mdm-*` and `PROTECTED_FORMS`.** Never model `mdm-*` resources as user resources (they are CDC-managed shared reference data), and never let the planner emit into `PROTECTED_FORMS` (`structure`, `admin`, `user`, `mdm-gender`) paths. See [`_shared/stack.md`](_shared/stack.md) → Tenancy.

## Inputs you expect

Anything from a one-sentence domain description up to a fully-modeled workspace:

| What the user gives you | What you do |
| --- | --- |
| "I want to build a CRM" (no existing workspace, no plan, no URLs) | Run the full build-new pipeline — Intent → Plan (full) → Import → Framework routing, all in one invocation, on the deployment the Preflight resolved. |
| An approved planner `template.md` + `template.json` pair already in scope | Skip planner inference; start at Intent (confirm the user wants to proceed), then Import. |
| "Also track X in my event app" (existing workspace) | Run Intent → Plan (delta — only the new resources for X) → Import (additive merge) → Framework routing to the extend path. |
| Explicit framework naming ("build it in React") | Route directly to the framework path with that naming; do not re-ask in Step 4. |

## Using Resources within Forms — the anti-pattern to avoid

The highest-leverage modeling rule when an app has both a data model and bespoke forms: **never create a Resource record from inside a bespoke Form** (nested-form-for-creation is the anti-pattern). Establish the Resource first in its own flow, then have the Form _reference_ it via a disabled, pre-selected Select or the submission `owner`. Whenever the user's request implies a bespoke form over a data-model record, read [`references/resource-vs-form-anti-pattern.md`](./references/resource-vs-form-anti-pattern.md) — it explains why, shows the right flow, and lists exactly what to tell the planner.

## The four steps

### Step 1 — Intent

Determine whether this is a new app to build or an existing app to extend. See [`INTENT.md`](./INTENT.md) for the question script and the downstream routing consequence of each answer. The target deployment is already resolved by this point — the Preflight settles it before Step 1 is asked, on both branches.

- **Build-new** → continue to Step 2 (full-template plan).
- **Modify-existing** → continue to Step 2 (delta plan for the new feature only).

### Step 2 — Plan

Invoke `alpha-form-resource-planner` with the user's plain-language description. The planner runs its own two-phase approval gate (Phase A: Resource Map for review; Phase B: the paired artifacts `template.md` + `template.json` on approval) — do not add a second gate on top.

- **Build-new** → a full-template pair: `template.md` (architectural intent, Access Matrix, ER + Access Flow diagrams) and `template.json` (every resource, role, form, and action, in the CE template envelope — see [`_shared/stack.md`](_shared/stack.md) → Templates). The planner classifies each entity as a Resource or a bespoke Form per "Using Resources within Forms" above — a Form references an established Resource, never creates it inline.
- **Modify-existing** → a delta pair containing ONLY the new resources, fields, or actions; the planner is told the deployment already exists, to plan only what is new, and that the template merges additively. See [`INTENT.md`](./INTENT.md)'s "Downstream consequences" for the per-branch planner instructions.

The planner writes both files to the working directory as a paired set (same basename; same collision timestamp if either name is taken). Stash BOTH paths — Step 3 reads `template.json`; Step 4 hands both to the framework path. On modify-existing, additionally stash the list of delta resource names for the extend path in Step 4.

### Step 3 — Import

Offer to import the planner's `template.json` into the target CE deployment. Approval gate before the call, citing the base URL + plain-language template summary + merge-overwrite warning. On approval, import via **CE `POST /import`** (or the equivalent programmatic `router.formio.template.import` for CE-side server operations — the middleware has no template-import proxy today, so import runs against the CE server directly with `x-token`). Import is additive — existing resources, roles, and forms are preserved; same-machine-name items are overwritten in place.

- **Build-new** → imports the full template into a (presumably empty) deployment.
- **Modify-existing** → imports the delta template; the new resources/fields/actions land alongside what is already there.

Authentication is `x-token` + `API_KEYS` (service auth) — there is no portal-login. See [`IMPORT.md`](./IMPORT.md) for the full script including the error-handling branches (auth failure, template validation failure).

### Step 3.5 — Auth handoff (conditional)

After a successful (or user-skipped) import, check the planner's `template.md` `## Users & Auth` section. If it flags any auth concern beyond resource-backed login plus Role Assignment — custom `x-token`/`API_KEYS` service auth, tenant JWT questions, RBAC tuning beyond the planner's defaults — invoke the `alpha-form-auth` skill now, before framework routing. Pass it the `template.md` path (its `Users & Auth` section is the requirements source) and the target base URL.

SSO is **Keycloak at the API gateway, outside Form.io** — there is nothing to configure inside Form.io for it; if the user asks, point them at [`alpha-form-auth`](../alpha-form-auth/SKILL.md) → [`references/sso-keycloak.md`](../alpha-form-auth/references/sso-keycloak.md).

If the `Users & Auth` section lists only resource-backed login (Login Action + Role Assignment) or the app has no auth at all, skip this step silently — the planner's template already contains everything needed.

### Step 4 — Framework routing

Consult the registry in [`FRAMEWORK.md`](./FRAMEWORK.md) and route:

- **Build-new, single installed framework** → silent routing. Today this is React (`@formio/react` fork, monorepo `packages/react`).
- **Build-new, multiple installed frameworks** → present them in one question round, let the user pick, then route.
- **Modify-existing** → use the "Detection signal" column of the registry to pick the right framework from the workspace itself (e.g., React deps in `package.json`). If detection matches exactly one, route directly to the framework's extend path; if ambiguous, ask the user.

The framework path receives a handoff context with the workspace root, the middleware base URL (`{baseUrl}/v1`), tenant identity headers, BOTH planner artifact paths (`template.md` + `template.json`), and (for modify-existing) the list of newly-imported resource names so it knows exactly what to scaffold for the delta. Note: a dedicated `formio-react` scaffold skill is **deferred** — until it exists, route embedding/render work to [`alpha-form-form`](../alpha-form-form/SKILL.md) (see [`FRAMEWORK.md`](./FRAMEWORK.md)).

## Handoff contracts

When handing off on the build-new branch, pass:

- Absolute workspace path.
- `baseUrl` (the resolved CE/middleware base URL from the Preflight) and tenant org UUID when applicable.
- The planner-emitted `template.md` file path (architectural-intent seed).
- The planner-emitted `template.json` file path (structured companion).
- A flag indicating whether Import ran successfully.

When handing off on the modify-existing branch, pass:

- Absolute workspace path.
- `baseUrl` and tenant org UUID (as above).
- The planner-emitted delta `template.md` file path.
- The planner-emitted delta `template.json` file path.
- The list of newly-imported resource names.
- The user's plain-language feature request verbatim (the extend path translates domain terms into framework primitives).

## When a step fails

Any failure surfaces a clear, short message to the user and offers a choice: retry, skip, or bail. The user is never left in an ambiguous half-done state. See the per-step docs for the specific error branches each step handles.

## Links

- [`INTENT.md`](./INTENT.md) — Step 1 build-vs-modify script
- [`IMPORT.md`](./IMPORT.md) — Step 3 import confirmation + error branches
- [`FRAMEWORK.md`](./FRAMEWORK.md) — Step 4 registry and routing
- [`references/resource-vs-form-anti-pattern.md`](./references/resource-vs-form-anti-pattern.md) — Resource-inside-Form anti-pattern + the right reference flow
