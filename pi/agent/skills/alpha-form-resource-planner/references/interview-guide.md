# Interview guide, Phase A map template, and worked example

The full round-by-round interview scripts for `alpha-form-resource-planner`, the exact Phase A Resource Map template, a complete worked example, and the interview heuristics. Read this before running the interview and before emitting the Phase A map.

## The interview

Work through these seven rounds. Compress or expand as the user's description warrants — if they named every entity and relationship explicitly, skip ahead; if they said only a brief phrase like "I want a CRM" or "build me a booking app," start from zero.

### 1. Extract the named entities

Re-read the user's prompt and list the nouns that sound like resources. For "Task Manager with Projects, Tasks assigned to Projects, and Users" → candidates: `Project`, `Task`, `User`.

Confirm the list with the user in one question. They may add or drop entities.

### 2. Classify each entity — Resource or Form

For every candidate from round 1, decide whether it is a **Resource** (a stored, reusable data model) or a **Form** (bespoke, purpose-specific data collection). Apply the litmus test in ["Resources vs. Forms"](planning-rules.md#resources-vs-forms--the-core-modeling-decision). Make the call deliberately per entity: most will be Resources (an all-Resource app is fine), so reach for a Form only when an entity is genuinely bespoke collection — don't force one either way.

Batch this with round 1's confirmation when you can: present the entity list already tagged `(Resource)` / `(Form)` and ask the user to correct any you misjudged. Explicitly call out any entity that looks like a bespoke Form referencing a Resource (e.g., a job application over an `Applicant` record, an RSVP over an `Attendee` record) so the user confirms the split between the reusable record (established first) and the per-interaction survey fields.

### 3. Determine the relationships

For every meaningful pair of entities, pin down the cardinality: 1:1, 1:N, or N:N. Ask as a batch. Draw a small ASCII sketch after the user answers.

### 4. Determine the user / auth model

Ask (together):

- Is the user the built-in `user` resource, or a custom user type (different fields, different login form)?
- Self-register vs admin-invite-only?
- Email/password (CE login, JWT in `x-jwt-token`) vs SSO via **Keycloak at the gateway** (the middleware injects `x-api-gw-organization-uuid` + `x-api-gw-user-uuid`)? There is no SSO inside Form.io.

When the app has **multiple personas** (e.g., applicants + reviewers + finance staff), decide deliberately between the two valid shapes — it is a requirements question, so ask when unclear: (a) **one shared `user` resource** with personas as roles (the common default — one login form, one owner story); this REQUIRES the multi-role assignment pattern, a `role` selectboxes component on the user resource plus one conditional Role Assignment action per persona, because direct `roles` writes are stripped by the API; or (b) **a resource per role** (e.g., separate `admin` resource, Login `settings.resources: ["user", "admin"]`) when the requirements call for separate credential pools or registration flows — then no selectboxes are needed and each user-type resource assigns its single role unconditionally. See [`template-json.md`](template-json.md) → "Multi-role user systems".

If the user has no authentication, say so explicitly and skip access rules — not every app needs login.

### 5. Determine the access / permission model

Ask (together):

- Is access **owner-level** (users see only their own records)?
- **Role-level** (admins see all, members see some, viewers see read-only)?
- **Tenant-level** (strict customer isolation)? On the alpha stack this is **owner-based tenancy** — `tags=[orgUuid]` + `*_own` submission ACLs + `{basePath}-{orgUuid}` path scoping applied by the middleware.
- Or some combination — e.g., "admins see everything, users see only their own records."

There is no **group-level** option: this stack has no Group Assignment action (`../_shared/stack.md` → Absent). "Users see only their team's data" is modeled as owner-based access plus roles, never a group action.

### 6. Determine tenancy / MDM awareness

Ask (together):

- Is the app tenant-scoped? If yes, plan for form `tags=[orgUuid]`, `*_own` submission access, and `{basePath}-{orgUuid}` path scoping (applied at runtime by the middleware — the template stays global/tenant-agnostic).
- Which existing `mdm-*` reference resources does the app consume (e.g., `mdm-gender`, `mdm-country`)? They are CDC-managed shared data — reference them via `dataSrc: "resource"` selects; never model them as user resources.
- Any planned form that collides with `PROTECTED_FORMS = ['structure', 'admin', 'user', 'mdm-gender']` must be renamed or routed around — those cannot be created through the middleware register path.

### 7. Produce the resource map, then gate on approval

Emit the Phase A Resource Map (see "Phase A — Resource Map for review" below) as a single artifact. Then stop and ask the user to approve or revise. Only after approval, produce the Phase B `template.json`.

## Phase A — Resource Map for review

When the interview has enough signal, emit the resource map as a single fenced markdown block for the user to review in the terminal. Use this exact template — the sections here are the same sections Phase B writes to `template.md`, with ONE substantive difference: Phase A uses **ASCII diagrams** (readable in a terminal) for `## ER Diagram` and `## Access Flow Diagram`, while Phase B writes **Mermaid diagrams** into the file (see [`template-md.md`](template-md.md)). Same topology, two renderings — the planner generates both from a single internal model in one run. Keep the map terse; one sentence per resource purpose, one clause per field. This is the artifact the user reviews before anything else happens.

```
# Resource Map — <App Name>

<1–2 sentence app summary>

## Resources

- <ResourceName> (type: resource)
  Purpose: <1 sentence>
  Fields:
    - <key>: <component> — <description>
    - ...
  Access: <owner / role(<roles>) / public>
  Actions:
    - <action name>: <key settings>
    - ...

- <JoinResourceName> (type: resource, join)
  Purpose: <which N:N relationship this implements>
  Fields:
    - <leftKey>: select (resource=<Left>)
    - <rightKey>: select (resource=<Right>)
  Access: <who can read/write the join rows>
  Actions:
    - <join>:save — plain membership data; no access action (no Group Assignment in this stack)
  ...

## Forms

(Include this section ONLY when the app has bespoke data-collection forms — job applications, surveys, RSVPs, intake/feedback forms. Omit the whole section for pure data-model apps. Auth forms — login/register — are described under "Users & Auth", NOT here.)

- <FormName> (type: form)
  Purpose: <1 sentence — the specific interaction this form captures>
  References: <ResourceName via disabled pre-selected Select | owner (1:1 with the user) | none>
  Fields:
    - <key>: <component> — <bespoke field specific to this form>
    - ...
  Access: <who can submit / who can read>
  Actions:
    - <action name>: <key settings>   ← Save to its OWN submission only; never a Save that creates the referenced Resource

## Users & Auth

- User resource: <default `user` | custom `<name>`>
- Login form: <form name> (Login action)
- Login resources: `user`
- Admin operations: <if any admin-only workflow in this plan, list each one in one line — e.g., "Seed initial Project rows; create ProjectUser membership rows; assign `administrator` role to specific users." — and note they are performed via the CE admin portal or CE admin API (`x-token` + `API_KEYS`), not via the app.>
- Registration: <self-register via form `<name>` with Role Assignment action | admin-invite only>
- SSO: <none | Keycloak at gateway>
- Tenancy: <none | tenant — org UUID `tags` + `*_own` ACLs + `{basePath}-{orgUuid}` path scoping (applied at runtime by the middleware)>
- MDM: <list the existing `mdm-*` reference resources this app consumes via `dataSrc: "resource"` selects, or `none`>
- Next steps for auth: when `SSO` is `Keycloak` (gateway integration), or the plan calls for admin auth beyond CE `x-token`/`API_KEYS`, tenant JWT mechanics, or RBAC tuning beyond default roles, hand off to the `alpha-form-auth` skill after this Resource Map is approved.

## Roles

- <roleName>: <capability summary>
- ...

## Access Matrix

| Resource | Actor          | create | read  | update | delete | Notes                   |
| -------- | -------------- | ------ | ----- | ------ | ------ | ----------------------- |
| <R>      | administrator  | all    | all   | all    | all    |                         |
| <R>      | authenticated  | own    | own   | own    | own    | owner-scoped            |
| ...      | ...            | ...    | ...   | ...    | ...    |                         |

(Actors are roles. Cell tokens: `all`, `own`, `role(<r>)`, `—`. One row per (resource, actor) pair with a non-trivial rule. No `group` token exists — no Group Assignment action in this stack; see `template-md.md` → "Access Matrix section".)

## ER Diagram

<ASCII diagram — every resource is a box, relationships labelled with cardinality, join resources sit on the line between the two sides. Keep text-editor friendly.>

## Access Flow Diagram

<ASCII diagram — how access reaches each resource at runtime. Show the roles users can hold, owner-based `*_own` submission-access rules from each role onto the resources they touch, and any admin bypass annotated inline. When the app is anonymous, this collapses to one line.>

## Companion artifact

`template.json` in this directory is the structured Form.io project-export
companion to this document. Use this `.md` for architectural intent; use the
`.json` for exact field shapes, component JSON, and action settings.
```

The full shape rules, vocabulary, and more ASCII examples live in [`template-md.md`](template-md.md). Read it before your first Phase B write — the section headings and the Access Matrix token vocabulary are load-bearing for downstream skills.

## Worked example

**User**: "I would like to build a Task Manager application. Projects have Tasks assigned to them. I want to assign users to projects, where the users only have access to Tasks within their Project."

**Interview** (abbreviated — in practice you'd ask, not assume):

- Entities: `Project`, `Task`, `User` ✓
- Relationships: `Project 1:N Task`, `Project N:N User` (many users per project, each user on many projects)
- Auth: default `user` resource, self-register, email/password
- Access: users see only the Tasks they created → owner-based access (`read_own`/`update_own`); the Project list is readable by all authenticated users so the task form's project select can populate; ProjectUser is admin-managed membership data (no access semantics)

**Phase A output** (shown to user for approval in the terminal — same content and section order that Phase B writes to `template.md`, but with ASCII diagrams. Phase B's file replaces these ASCII blocks with Mermaid `erDiagram` + `flowchart TD` equivalents):

```
# Resource Map — Task Manager

A multi-user task manager where each Project has a set of Tasks and a team of Users, and users see their own Tasks inside Projects.

## Resources

- Project (type: resource)
  Purpose: container for tasks assigned to a team of users.
  Fields:
    - name: textfield — human-readable project name
  Access: `read_all` for `authenticated` (so the task form's project select can populate); admin-managed otherwise
  Actions:
    - (save only)

- Task (type: resource)
  Purpose: a unit of work within a Project.
  Fields:
    - description: textfield — what needs doing
    - project: select (resource=Project, reference=true) — parent project
    - assignee: select (resource=User, optional) — who it is assigned to
  Access: owner-based — `create_own`/`read_own`/`update_own`/`delete_own` for `authenticated`; admins manage all
  Actions:
    - (save only)

- ProjectUser (type: resource, join)
  Purpose: many-to-many between Project and User; registers project memberships.
  Fields:
    - project: select (resource=Project)
    - user: select (resource=User)
  Access: admin-managed (membership data only; no access semantics)
  Actions:
    - (save only)

## Users & Auth

- User resource: default `user`
- Login form: `userLogin` (Login action)
- Login resources: `user`
- Admin operations: Seed initial `Project` rows; create `ProjectUser` membership rows; manage `administrator` role assignments. Performed via the CE admin portal or CE admin API (`x-token` + `API_KEYS`), NOT the app login form.
- Registration: self-register via `userRegister` (Role Assignment action → role=`authenticated`)
- SSO: none
- Tenancy: none

## Roles

- administrator: full access to all resources and memberships
- authenticated: default role on registration; owner-scoped access to Tasks
- anonymous: default unauthenticated role; no submission access

## Access Matrix

| Resource    | Actor          | create | read  | update | delete | Notes                                                                       |
| ----------- | -------------- | ------ | ----- | ------ | ------ | --------------------------------------------------------------------------- |
| Project     | administrator  | all    | all   | all    | all    | full admin                                                                  |
| Project     | authenticated  | —      | all   | —      | —      | read-only project list (populates the task form's project select)           |
| Task        | administrator  | all    | all   | all    | all    |                                                                             |
| Task        | authenticated  | own    | own   | own    | own    | owner-scoped: users manage the Tasks they created                           |
| ProjectUser | administrator  | all    | all   | all    | all    | admin-managed membership                                                    |
| ProjectUser | authenticated  | —      | —     | —      | —      | join rows are admin-created                                                  |

## ER Diagram

    User ◄──────── ProjectUser ────────► Project
                        │                    │
                        │                    │ 1:N
                        │                    ▼
                        │                  Task
                        └── (owner-based access)

## Access Flow Diagram

  [ administrator ] ── sees all ──► every resource

  [ authenticated ]
       │
       │ Submission Access: read_all
       ▼
    [ Project ]
       │
       │ Submission Access: create_own, read_own, update_own, delete_own
       ▼
     [ Task ]   (users manage only the Tasks they created)

## Companion artifact

`template.json` in this directory is the structured Form.io project-export
companion to this document. Use this `.md` for architectural intent; use the
`.json` for exact field shapes, component JSON, and action settings.
```

(Ask the user to approve or revise. If approved, continue to Phase B — which writes the same Resource Map content to `./template.md` alongside `./template.json`, with the two ASCII diagrams above replaced by their Mermaid equivalents. See [`template-md.md`](template-md.md) and the `examples/task-manager/template.md` canonical example for the Mermaid shape.)

**Phase B output** (emitted only after the user approves): writes BOTH `./template.md` and `./template.json` to disk, then renders both in the transcript (markdown first, JSON second), then prints `Wrote ./template.md and ./template.json.`, then the Next steps block.

See [`template-md.md`](template-md.md) for the full `template.md` spec and [`template-json.md`](template-json.md) for the JSON schema. A canonical paired example is checked in under `examples/`:

- **Task Manager** — owner-based access with a plain `ProjectUser` membership join: `examples/task-manager/template.md` + `template.json`

Use it as a structural reference when deciding how to shape a new app's output.

## Interview heuristics

- **When an entity carries survey-like or one-off fields** ("why should we hire you?", "rate 1–5", "any special requests?"), it is a **Form**, not a Resource — usually a Form that _references_ an established Resource (disabled Select or `owner`) plus those bespoke fields. Do not bolt survey fields onto a data-model Resource, and do not create that Resource from inside the Form. See ["Resources vs. Forms"](planning-rules.md#resources-vs-forms--the-core-modeling-decision).
- **When the user describes a workflow/interaction rather than a thing** ("people apply for a job", "guests RSVP", "customers file a complaint"), reach for a Form. When they describe a thing the app stores and reuses ("we track applicants", "we keep a product catalog"), reach for a Resource. A single feature often needs BOTH (an `Applicant` Resource and a `JobApplication` Form).
- **When the user names 3+ entities and never mentions users**, stop and ask whether the app has authenticated users. Don't assume.
- **When a relationship could be 1:N or N:N**, prefer N:N with a join resource if the relationship carries data (assigned-at, role-within-team, etc.). A join is cheap and backward-compatible; an embedded 1:N is not.
- **When the user says "only see their team's / project's data"**, model it as owner-based access on the records each team member creates, optionally layered with roles — there is no Group Assignment action in this stack, so no join-based access action exists.
- **When the user says "only see their tenant's / organization's data"**, that's **owner-based tenancy** on the alpha stack: form `tags=[orgUuid]`, `*_own` submission ACLs, `{basePath}-{orgUuid}` path scoping applied by the middleware.
- **When the user says "only see their own data"**, that's owner-based access. Submission Access owner rules alone are enough — no join needed.
- **When the user says "admins see everything"**, call out role-based layering on top of whichever owner/role rule is primary.
- **When the plan has 2+ assignable personas on one SHARED user resource**, the map must include the `role` selectboxes component on the user resource and one conditional Role Assignment per persona — "assign staff roles via the portal" is only true BECAUSE those actions exist; without them no persona beyond self-register can ever be assigned (the API strips direct `roles` writes). When the plan instead uses a resource per role, skip the selectboxes — each user-type resource assigns its single role unconditionally.
- **When the user skips auth entirely**, say so explicitly in the output (`Users & Auth: none`). Not every plan needs a user resource.
