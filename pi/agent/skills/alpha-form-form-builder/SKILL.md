---
name: alpha-form-form-builder
description: >-
  Build a single Form.io form end to end: form type (webform/wizard), schema authoring (`alpha-form-schema`), save via REST, optional embed handoff. Use for "build me a form", surveys, questionnaires, or editing a form's fields. Boundary: collecting into one standalone form belongs here; tracking data over time belongs to `alpha-form-application` / `alpha-form-resource-planner`. Not for: embedding existing forms (see `alpha-form-form`); apps (see `alpha-form-application`); resource/permission design (see `alpha-form-resource-planner`); JSON schemas (see `alpha-form-schema`); REST endpoints (see `alpha-form-api`).
---

# Form.io Form Builder Orchestrator

You are the library's default "build me a form" skill. When a user asks for a single form — a survey, a contact form, an intake wizard — your job is to drive the full pipeline from plain-language intent to a saved form in the alpha formio stack, and, only when they asked for it, on to embedding. The user should never have to know form-type terminology, author component JSON, or manually invoke the schema skill.

## Preflight — direct REST, no MCP tools

This fork has **no MCP server** and no MCP tooling. All form work happens over direct REST against the alpha formio stack. Stack facts (auth layers, base URLs, tenancy) are pinned in [`_shared/stack.md`](_shared/stack.md) — read it before the first call.

Forms are created on the **middleware `/v1` surface** (the production surface consumers call). Every request carries the gateway identity headers `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` (Keycloak at the gateway); the middleware mints the tenant token (Redis-cached) and proxies to CE. **Know your tenant headers** — ask the user for the org UUID and user UUID the form belongs to before any write. For admin/server operations that bypass tenancy, the CE server is reachable directly with the `x-token` header (from the `API_KEYS` env var). There is no API-key header auth, no SaaS project mapping, no project-config commands, and nothing in a per-user formio config file.

## Stance

- **One form, end to end.** You own the pipeline INTENT → SCHEMA → SAVE → EMBED (conditional). You do not plan data models, resources, roles, or apps — the moment the request turns into "an app around the data", hand off to `alpha-form-application`.
- **Batch your questions.** The INTENT step asks everything it needs — form type AND embed intent — in ONE question round, using the client's structured question mechanism (in Claude Code, `AskUserQuestion`). Do not pepper.
- **Route, do not reimplement.** Component selection and form JSON authoring live in `alpha-form-schema`. Embedding lives in `alpha-form-form`. Your job is orchestration and handoffs, never duplicating their guidance.
- **Gate before writing.** Saving into the deployment is an approval gate: show what will be created and where before writing. Any `access`/`submissionAccess` grant that widens permissions beyond tenant defaults must be named explicitly at the gate and confirmed on its own — never buried in the general save approval (see `SAVE.md`). Note: in multi-tenant mode the middleware **overwrites** supplied `access`/`submissionAccess` with tenant ACLs (`assignPermissionsToForm`), so a widened grant may not survive the save — the call-out still matters when multi-tenancy is disabled or when the grant is part of a tenant template. A declined gate stops the flow.
- **Fast by default.** A standalone "make me a survey" runs INTENT → SCHEMA → SAVE and ends with the saved form URL. The EMBED step fires ONLY when the user answered an explicit yes at INTENT.

## The four steps

### Step 1 — INTENT

Determine, in one batched interview, (a) the form type — `webform` (single-page form) or `wizard` (multi-page form) — inferring from phrasing when unambiguous and confirming, asking when ambiguous; and (b) whether the user wants the form embedded in an application afterward. See [`INTENT.md`](./INTENT.md) for the question script and [`FORM_TYPES.md`](./FORM_TYPES.md) for what each type is and the phrasing signals that distinguish them.

### Step 2 — SCHEMA

Invoke the `alpha-form-schema` skill to select the right components and author the complete form JSON definition for the confirmed form type and the user's described fields. Defer to it entirely — no component or schema documentation lives in this skill. Carry the confirmed form type into the definition (`display: "form"` for a webform, `display: "wizard"` for a wizard — `alpha-form-schema` owns the exact shapes).

### Step 3 — SAVE

Persist the authored definition into the deployment via **`POST /v1/form`** on the middleware, behind an approval gate. Confirm the saved form path back to the user. Auth comes from the `x-api-gw-*` gateway headers (Keycloak) — the middleware mints the tenant token automatically; there is no manual token to set. See [`SAVE.md`](./SAVE.md) for the gate script and error branches.

### Step 4 — EMBED (conditional)

Only if the user answered an explicit yes to embed intent at INTENT: hand off to the `alpha-form-form` skill to embed the saved form by its form URL in the user's application. See [`EMBED.md`](./EMBED.md) for the handoff contract.

## Edit lane — changing an existing form

When the trigger is a field change on an existing form ("add a phone field to my registration form", "remove a question", "make this field required"), run a shortened pipeline instead of the four steps: fetch the current definition (`GET /v1/form/:formId`, resolving a loosely-named form to its id first), invoke `alpha-form-schema` to author the component change against the fetched JSON, then persist with `PUT /v1/form/:formId` behind the same approval gate as SAVE — show what will change before writing. Skip INTENT's form-type interview (the saved form already fixes the type); EMBED still fires only on an explicit yes.

## Forms with behavior — login, registration, email notifications

A form request that carries server-side behavior stays in this skill for the form itself; the behavior is attached afterward, not handed off up front. "Create a registration form with login", "a contact form that emails me on submit": build and save the form through the normal four steps, then invoke `alpha-form-actions` to attach the behavior (Login Action, Role Assignment Action, Email Action) to the saved form. Do NOT route these to `alpha-form-auth` — that skill owns auth architecture (roles-and-permissions, Keycloak at the gateway, tenant JWT minting), not per-form actions. Hand off to `alpha-form-auth` only when the user's ask goes beyond form-attached actions into roles-and-permissions design or gateway-level identity.

## URL terminology

There is **one base URL per environment** — no SaaS project URLs. The middleware surface is `{baseUrl}/v1/*`; the CE server is `{baseUrl}` direct (admin/server ops only). The saved form is reachable by its **unscoped form path** under the middleware surface (the middleware scopes the stored path with the org suffix internally and serves the unscoped path). This is the URL SAVE confirms and EMBED hands off.

## REST endpoints

Prefer the middleware's REST surface over ad-hoc requests:

- `POST /v1/form` — persist the authored form definition (Step 3); body = FormDto (`type: 'form'|'resource'`, `display: 'form'|'wizard'`, `title`, `path`, `name`, `machineName`, `components`, `access`, `submissionAccess`, `tags`, `properties`).
- `GET /v1/form` / `GET /v1/form/:formId` — resolve a loosely-named form or re-fetch the saved definition (edit lane).
- `PUT /v1/form/:formId` — persist a change to an existing form's definition (edit lane).

All with `x-api-gw-user-uuid` + `x-api-gw-organization-uuid` headers. The middleware enforces tenant scoping (forces `tags=[org]`, scopes the path) and rejects `PROTECTED_FORMS` paths (`structure`, `admin`, `user`, `mdm-gender`).

## Links

- [`FORM_TYPES.md`](./FORM_TYPES.md) — webform vs wizard, when to choose each
- [`INTENT.md`](./INTENT.md) — Step 1 batched interview script
- [`SAVE.md`](./SAVE.md) — Step 3 `POST /v1/form` gate + error branches
- [`EMBED.md`](./EMBED.md) — Step 4 conditional embed handoff
