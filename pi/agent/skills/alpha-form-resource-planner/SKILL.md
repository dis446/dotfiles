---
name: alpha-form-resource-planner
description: >-
  Plan a Form.io application's resources, fields, and access model, then emit a ready-to-import `template.json` (Phase A: Resource Map for approval; Phase B: full template). Interview-driven. Use when designing or modeling resources, schema, data model, or access. Not for: building the app (see `alpha-form-application`); standalone single forms (see `alpha-form-form-builder`); auth/SSO config (see `alpha-form-auth`); endpoint lookups (see `alpha-form-api`).
---

# Form.io Resource Planner (alpha)

Turn a natural-language application description into a concrete Form.io resource map for the alpha stack — the minimum plan needed to actually build the app. All stack facts (auth layers, base URLs, tenancy, versions) come from [`_shared/stack.md`](_shared/stack.md) — read it before planning.

## Preflight — no MCP tools, direct REST

There is **no MCP server tooling in the alpha stack** — no MCP form/action/import tools, no project-mapping commands, no per-project config files. This skill never calls a deployment while planning; when it references the REST surface it means direct HTTPS calls:

- **Middleware `/v1`** — production surface for tenant-scoped app data: `{baseUrl}/v1/form/...`, `{baseUrl}/v1/submission/...`, with `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` gateway headers (Keycloak-injected; the middleware mints the tenant JWT).
- **CE direct** — `{FORMIO_BASE_URL}` (e.g. `https://form-dev.alpha.looms.cloud`) for admin/server ops, authenticated with `x-token` + `API_KEYS` (admin) or `x-jwt-token` (user).

The planner itself writes **nothing** to any deployment — it produces the artifact pair and stops. Importing is a separate, explicit step (CE `POST /import`; see "Phase B" and [`references/phase-b-emission.md`](references/phase-b-emission.md) → "Next steps").

## Stance

You are a thinking partner that plans before it builds. Two distinct phases with a hard approval gate between them.

- **Curious, not prescriptive.** The user's domain words are signal; the Form.io vocabulary is yours to translate.
- **Batch your questions.** When multiple related questions come up (e.g., all relationship cardinalities), ask them together in ONE question round, using the client's structured question mechanism (in Claude Code, `AskUserQuestion`). Peppering the user one question at a time burns trust.
- **Visualize twice, in two formats.** The map is visualised by two diagrams: an ER diagram (who relates to whom) AND an Access Flow diagram (how the runtime ACL reaches each resource). Phase A (chat approval gate) renders both as ASCII so the user can review them in the terminal. Phase B (file on disk) renders both as Mermaid (`erDiagram` + `flowchart TD`) so downstream skills and GitHub/IDE readers get semantic edges + native rendering. Both surfaces describe the same topology — generated from one internal model per run.
- **Ground in Form.io primitives.** Every output claim must map to a real Form.io construct: resource, form, component, action, role, or the alpha tenancy primitives (`tags`, `*_own`, `{basePath}-{orgUuid}`).
- **Pick the right kind per entity.** Classify every entity as a **Resource** (a stored, reusable data model) or a **Form** (bespoke, purpose-specific data collection) BEFORE modeling its fields. Most entities are Resources, and an app that is all Resources is perfectly valid — just make the call deliberately rather than reflexively, and reach for a Form only when the entity is genuinely bespoke collection. See ["Resources vs. Forms"](#resources-vs-forms--the-core-modeling-decision) below.
- **Gate on approval.** Phase A (Resource Map) is for review. Do not emit `template.json` / `template.md` until the user has explicitly approved the map. See "The approval gate" below.
- **Phase B is a pair.** Every Phase B emission writes `template.md` AND `template.json` together — same basename, same timestamp on collision. `template.md` is the architectural-intent artifact downstream skills seed from; `template.json` is its structured companion. Never emit one without the other.
- **Actions follow intent — add them per use-case, never blindly.** A resource or form gets exactly the actions its purpose requires: a Save on anything meant to persist to the submission API, Login on a login form, Role Assignment on a register form, Email/Webhook on a notification form. **A form or resource with NO actions is valid** — it renders and collects data client-side but never sends anything to the submission API (e.g. an embedded Search form whose data the app reads in the browser to build a query for a separate API). The common mistake is the opposite: forgetting Save on something that WAS meant to store records — so whenever a resource or form is meant to persist submissions, it MUST have a `<name>:save`, and a missing one there is a bug. When in doubt about whether a given form persists, decide deliberately (and ask the user if unclear) rather than defaulting either way. See [`references/phase-b-emission.md`](references/phase-b-emission.md) → "Actions emission — per use-case", and [`references/template-json.md`](references/template-json.md) for exact shapes.
- **Never writes to a live deployment.** The skill produces plans plus the `template.md` / `template.json` artifact pair. It does not import, create forms, or call any deployment API, which is why it needs no credentials of its own and probes for none. Importing is a separate, explicit user action: Phase B prints it as a next step, and whoever carries it out — `alpha-form-application` on its own flow, or you in a later turn once the user asks — confirms the target deployment first, on the terms [`references/phase-b-emission.md`](references/phase-b-emission.md) → "Next steps" sets out.

## Alpha stack conventions the plan must respect

Every emitted template is judged against these (details: [`_shared/stack.md`](_shared/stack.md)):

- **Tenancy is owner-based.** A tenant is an org UUID. Isolation = form `tags: [<orgUuid>]` + `*_own` submission ACLs + `{basePath}-{orgUuid}` path scoping applied at runtime by the middleware. There is **no Group Assignment action in this stack** (`_shared/stack.md` → Absent) — owner-based `*_own` access is the isolation mechanism.
- **`mdm-*` resources are never planned as user resources.** They are CDC-managed shared reference data (`source_id`, `sharedAccess` `read_all` for everyone, mandatory `:save` action). Reference them from your app's resources via `dataSrc: "resource"` selects; never model, duplicate, or create them.
- **`PROTECTED_FORMS = ['structure', 'admin', 'user', 'mdm-gender']`** — never plan creating these through the middleware register path (`user` may appear as a credential resource in a template, but it is not middleware-creatable).
- **Custom roles auto-grant `read_all`.** `bootstrapNewRoleAccess` adds every new role to `read_all` of all forms — do NOT emit an "add the custom role to project read_all" instruction; it is automatic.
- **Envelope is byte-compatible with `default-template.json`**: `title, name, version, description, roles, resources, forms, actions, access` (object maps keyed by machineName); import via CE `POST /import` with `{ "template": <the json> }`.
- **Auth**: CE `x-token` + `API_KEYS` (admin), `x-jwt-token` (user), login `POST /user/login` / `POST /admin/login`; middleware Keycloak gateway headers. No alternate API-key headers, no token swap, no cloud project tiers.

## Resources vs. Forms — the core modeling decision

Form.io has two kinds of entries — **Resources** (stored, reusable data models; the nouns of the app, each auto-generating a REST API) and **Forms** (bespoke, purpose-specific data collection — a job application, a survey, an RSVP). Classify every entity BEFORE modeling its fields with the litmus test: a record the app stores and reuses → Resource; a response to a specific ask, possibly wrapping a record → Form. A bespoke Form _references_ an already-established Resource (disabled pre-selected Select, or the submission `owner`) — never create the Resource from inside the Form. The full decision guide — definitions, the Job Application worked example, the quick classification table, and the anti-pattern — is in [`references/planning-rules.md`](references/planning-rules.md) → "Resources vs. Forms"; read it before classifying, and when in doubt, ask the user rather than silently defaulting to Resource.

## The interview

Work through seven rounds — compress or expand as the user's description warrants (skip ahead if they named every entity and relationship; start from zero for a bare "I want a CRM"). The full round-by-round scripts, question batching, and the "Interview heuristics" for ambiguous cases are in [`references/interview-guide.md`](references/interview-guide.md).

1. **Extract the named entities** — list the resource-sounding nouns in the prompt and confirm the list with the user in one question.
2. **Classify each entity — Resource or Form** — apply the litmus test per entity; batch with round 1's confirmation and call out any bespoke-Form-over-Resource splits.
3. **Determine the relationships** — pin down 1:1 / 1:N / N:N for every meaningful pair, asked as a batch.
4. **Determine the user / auth model** — default vs custom user resource, self-register vs admin-invite, email/password vs Keycloak at the gateway; a no-auth app skips access rules.
5. **Determine the access / permission model** — owner-, role-, or tenant-level, or a combination.
6. **Determine tenancy / MDM awareness** — is the app tenant-scoped (org UUID `tags`, `*_own`, `{basePath}-{orgUuid}`)? Which existing `mdm-*` reference resources does it consume? (Never plan `mdm-*` as user resources.)
7. **Produce the resource map, then gate on approval** — emit the Phase A Resource Map, stop, and ask the user to approve or revise.

## Tenancy and MDM

- **Alpha tenant isolation is owner-based.** The runtime model is: form `tags=[orgUuid]` + `*_own` submission ACLs (tenant-admin role) + `{basePath}-{orgUuid}` path scoping — applied by the middleware at runtime, keyed on `x-api-gw-organization-uuid`. When the user says "tenant data isolation", model owner-level `*_own` access. There are **no group permissions in this stack** (no Group Assignment action — see `_shared/stack.md` → Absent); team/project scoping inside an app is modeled with `*_own` ACLs plus roles, never a group action.
- **`mdm-*` resources** are shared reference data managed by CDC (`source_id`, `sharedAccess` read_all everyone, mandatory `:save` action). Reference them via `dataSrc: "resource"` selects (the import machinery resolves them); never plan to create, edit, or duplicate them.
- **PROTECTED_FORMS** (`structure`, `admin`, `user`, `mdm-gender`) are not creatable through the middleware register path — route around them.

## Form.io primitives you will use

Two planning references cover the primitives; open them while building the map:

- [`references/planning-rules.md`](references/planning-rules.md) — the relationship → construct mapping (foreign-key `select`s, N:N join resources), the component cheat sheet, and the action cheat sheet.
- [`references/access-patterns.md`](references/access-patterns.md) — the owner/role/tenant pattern table; the `access` vs `submissionAccess` distinction (users describing access almost always mean `submissionAccess`); how tenant isolation is owner-based and why there is no group action in this stack. Read it whenever the plan has any owner-, role-, or tenant-based access.

## Phase A — Resource Map for review

When the interview has enough signal, emit the Resource Map as a single fenced markdown block for the user to review in the terminal — the same sections Phase B writes to `template.md`, with ONE substantive difference: Phase A uses ASCII diagrams for `## ER Diagram` and `## Access Flow Diagram`, while Phase B's file uses Mermaid (same topology, generated from one internal model per run). Keep the map terse — one sentence per resource purpose, one clause per field. Follow the exact Phase A template in [`references/interview-guide.md`](references/interview-guide.md) → "Phase A — Resource Map for review"; the full shape rules and Access Matrix token vocabulary are in [`references/template-md.md`](references/template-md.md).

## The approval gate

After emitting the Resource Map, stop. Ask the user one question, in one round:

> "Does this map look right? I can write `template.md` + `template.json` once you approve it, or revise the map based on your feedback."

Offer two options: **Approve & write template.md + template.json** and **Revise the map** (with free-text "Other" always available for specific tweaks).

**Do not skip this gate**. Even if the user's original prompt sounds decisive ("build me a task manager and give me the JSON"), always produce the map first, then ask. The gate exists because the JSON is 200–600 lines and a single wrong field propagates everywhere — cheaper to catch mistakes in the ~50-line map than the 500-line export.

If the user says "revise" or flags specific issues: update the map, re-show it, re-ask. Iterate until they approve.

## Phase B — template.md + template.json after approval

Only when the user has approved the map, emit the artifact PAIR — always both, always together:

1. **`template.md`** — the approved Resource Map, saved to disk as the architectural-intent document. Same structure as the Phase A map (Resources, optional Forms, Users & Auth, Roles, Access Matrix, ER Diagram, Access Flow Diagram, Companion artifact). See [`references/template-md.md`](references/template-md.md) for the complete spec.
2. **`template.json`** — the Form.io template envelope, byte-compatible with the alpha `default-template.json` (`title, name, version, description, roles, resources, forms, actions, access`; object maps keyed by machineName). Importable via CE `POST /import` with `{ "template": <the json> }`.

Each file is emitted in TWO forms at the same time:

- **As a fenced block in the chat transcript** (`markdown` for `template.md`, `json` for `template.json`) — so the user sees both ASCII diagrams and the structure inline.
- **As files on disk using the `Write` tool** — so downstream skills (like `alpha-form-application`'s Import step) can pass real file paths.

### File-write rules

- **Default filenames:** `./template.md` and `./template.json` in the user's current working directory (cwd — the directory the user was in when they invoked the flow). Use the `Write` tool; local filesystem writes do NOT count as "calling a deployment", so the skill's "never writes to a live deployment" stance is preserved.
- **Paired collision handling:** if EITHER file already exists in cwd, append the SAME sortable UTC timestamp (e.g. `20260420T153000Z`) to BOTH filenames so the pair stays matched — even if only one of the two collided — and report both chosen filenames in the Phase B confirmation message. Exact rule and format: [`references/template-md.md`](references/template-md.md) → "File pairing rules".
- **Both standalone and orchestrated runs:** write both files in every Phase B emission — whether the planner is running standalone or invoked from `alpha-form-application` (which will then pass the paths to its Import step and the framework handoff). Do not make this conditional.
- **Never emit one without the other.** If for any reason you can only emit one, stop and explain the problem — the pair is the contract downstream skills rely on.

### Transcript requirements

The markdown block MUST follow the section order in [`references/template-md.md`](references/template-md.md) exactly (`# Resource Map — <App Name>` → `## Resources` → optional `## Forms` → `## Users & Auth` → `## Roles` → `## Access Matrix` → `## ER Diagram` → `## Access Flow Diagram` → `## Companion artifact` — downstream graders key on these headings), with Mermaid — not ASCII — diagram blocks. The JSON block MUST be a valid, importable template with the top-level keys in exactly this order: `title`, `name`, `version`, `description`, `roles`, `resources`, `forms`, `actions`, `access`; read [`references/template-json.md`](references/template-json.md) before writing — do not improvise structure. Full requirements (Mermaid node coverage, empty-object rules, the optional `description` key, the non-empty project-level `access` array): [`references/phase-b-emission.md`](references/phase-b-emission.md) → "Transcript requirements".

### Actions emission — per use-case

Right before writing `template.json`, run the emission algorithm in [`references/phase-b-emission.md`](references/phase-b-emission.md) → "Actions emission — per use-case" exactly once. In brief: every persisting resource and form gets `<name>:save` (a missing Save silently drops submissions; a deliberately client-only entry with no actions is valid); login forms get `<name>:login` (a login-form `save` must NEVER set `settings.resource`); register forms get Save → Login → Role Assignment; Email/Webhook only when explicitly requested. The reference holds the full emission algorithm, the Login `settings.resources` rules, the admin-work-via-portal rule, the Email action rules, the minimum-viable-action-set table, priority ordering, and the pre-emit self-check.

### Order in the transcript

Render the markdown block first, then the JSON block, then the one-line confirmation (`Wrote ./template.md and ./template.json.`, using the collision-aware filenames), then the "Next steps" section. The exact confirmation line and Next-steps block to reproduce are in [`references/phase-b-emission.md`](references/phase-b-emission.md) → "Order in the transcript".

## Handoffs

- **`alpha-form-auth`** — when the approved map's `Users & Auth` section has an `SSO` of `Keycloak` (integration work at the gateway), an admin-auth requirement beyond the CE `x-token`/`API_KEYS` story, or any auth concern beyond resource-backed login + Role Assignment (tenant JWT mechanics, RBAC tuning beyond default roles), hand off to the `alpha-form-auth` skill immediately after the Resource Map is approved. There is no SSO inside Form.io, no token swap, no 2FA, no reCAPTCHA in this stack.
- **`alpha-form-application`** — when invoked as the orchestrator's planning step, run the same two phases and gates; the Phase B file paths are what the orchestrator passes to its Import step and the framework-specific scaffolding skill.

## Worked example

A complete Task Manager run — the abbreviated interview, the full Phase A ASCII Resource Map, and the Phase B handoff — is in [`references/interview-guide.md`](references/interview-guide.md) → "Worked example". A canonical paired example is checked in under `references/examples/`: [`task-manager/`](references/examples/task-manager/) (owner-based access, join resource as plain membership data). Use it as a structural reference when deciding how to shape a new app's output.

## When to look up more

- Stack facts (auth layers, base URLs, tenancy, versions, i18n): [`_shared/stack.md`](_shared/stack.md) — the single source of truth; never restate conflicting values in a plan.
- Component/schema shapes beyond the planner's minimal set: `alpha-form-schema`.
- REST endpoints and runtime access control: `alpha-form-api` → `../alpha-form-api/references/runtime-access-control.md`.
- Auth architecture: `alpha-form-auth`.

Consult these when the user's requirements touch an edge case this skill doesn't cover (e.g., conditional access, multi-level tenancy, federated SSO at the gateway).

## What this skill does NOT do

- **Does not write to a live deployment, skip the approval gate, or emit one artifact without the other** — see "Stance", "The approval gate", and "File-write rules" above; importing the template is a separate, explicit user action (CE `POST /import`).
- **Does not look up endpoints.** The `alpha-form-api` skill handles endpoint reference.
- **Does not deep-dive a single form's component schema.** For exhaustive component options (conditional logic, calculated values, custom validation), see `alpha-form-schema`. This skill's template.json uses the minimum viable component shape for each field.
- **Does not make the plan "complete" beyond what the user described.** If they didn't mention reporting, don't add a report resource.

## Reference files

All one hop from here — open the one matching the phase you are in:

- [`references/planning-rules.md`](references/planning-rules.md) — Resources vs. Forms decision guide; relationship → construct; component and action cheat sheets.
- [`references/access-patterns.md`](references/access-patterns.md) — owner/role/tenant patterns; the `access` vs `submissionAccess` distinction; owner-based tenancy; why there is no group action.
- [`references/interview-guide.md`](references/interview-guide.md) — full interview scripts; the exact Phase A map template; the Task Manager worked example; interview heuristics.
- [`references/phase-b-emission.md`](references/phase-b-emission.md) — Phase B transcript requirements; the actions-emission algorithm; output order and the Next-steps block.
- [`references/template-md.md`](references/template-md.md) — full `template.md` spec: section shapes, Mermaid diagram conventions, Access Matrix tokens, file pairing, chat-output rules.
- [`references/template-json.md`](references/template-json.md) — full `template.json` schema: component shapes, action shapes, access arrays, assembly checklist.
