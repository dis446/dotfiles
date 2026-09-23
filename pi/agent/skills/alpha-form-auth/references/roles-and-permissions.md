# Roles and permissions (RBAC)

## Overview

Form.io authorization is role-based. Every authenticated user object carries a `roles` array of MongoDB IDs; the deployment has its own set of Roles; and every Project, Form Definition, and Submission carries `access` / `submissionAccess` arrays that map permission types to roles. This reference covers the default roles, custom roles, the eight permission types, the three permission scopes (project / form-definition / submission-data), and the layered access model (Self Access Permissions).

## When to use this

Reach for this reference when the user wants to:

- Understand who can read / update / delete what.
- Tune `access` or `submissionAccess` on a Form or Resource.
- Add a custom role and decide what it can do.
- Reason about "own" vs "all" semantics.
- Pick between role-based and owner-based access models (there is no group-based model in this stack — no Group Assignment action; see `../_shared/stack.md` → Absent).

Not for:

- Wiring the actual login flow → see [`resource-auth.md`](./resource-auth.md).
- SSO — Keycloak at the gateway, outside Form.io → see [`sso-keycloak.md`](./sso-keycloak.md).

## Configuration

### Default roles

The CE fork's template (`default-template.json`) seeds three roles, plus the fixed-identity `everyone` baseline that the access machinery resolves (the ID `00000000000000000000000` appears in CE db-update scripts):

- **Anonymous** — for unauthenticated users. Cannot be deleted.
- **Everyone** — baseline applied to all users. Fixed ID `00000000000000000000000`. Cannot be deleted.
- **Administrator** — preconfigured with full CRUD across the deployment.
- **Authenticated** — preconfigured for logged-in workflows; assigned by the Role Assignment Action at signup.

In a planner-produced `template.json` the default roles are emitted as objects with `title`, `description`, `admin`, and `default` fields — see `../../alpha-form-resource-planner/references/template-json.md` → "Roles" for the canonical shape.

### Custom roles

Add custom roles when the default trio is not enough — for example `salesRep`, `moderator`, `supportAgent`. A custom role:

- Has `admin: false` and `default: false`.
- Is referenced by MongoDB ID in `access` / `submissionAccess` arrays on the Forms and Resources you want it to reach.

### Assigning roles to users — Role Assignment actions only, never direct `roles` writes

A user's `roles` array lives on their submission, but the submissions API **strips the `roles` key from POST/PUT/PATCH bodies** (`front-end/formio/formio/src/middleware/submissionHandler.js` picks only `data`, `owner`, `access`, `metadata`, `_vnote`; a direct write can only ever *intersect* the current roles, never add). Roles are assigned exclusively by the **Role Assignment action** (self-register forms assign the default persona unconditionally). For a multi-role application where all personas share ONE `user` resource (`student` / `collegeAdmin` / `scholarshipAdmin`) — the common default — the canonical pattern is a `role` selectboxes component on the user resource plus one CONDITIONAL Role Assignment action per persona (`condition.conditions: [{ component: "role", operator: "isEqual", value: "<persona>" }]`), so creating or editing a user in the portal (or via the API with `data.role.<persona> = true`) attaches the right role server-side. When the requirements instead call for a **resource per role** (e.g., a separate `admin` resource with the Login action's `settings.resources: ["user", "admin"]`), the selectboxes pattern is unnecessary — each user-type resource carries its own unconditional Role Assignment. Exact JSON shapes: `../../alpha-form-resource-planner/references/template-json.md` → "Multi-role user systems"; action mechanics: the `alpha-form-actions` skill's `../../alpha-form-actions/references/action-types.md` → "Role Assignment".

### The eight permission types

The same eight types appear across every scope:

| Type         | Meaning                                                                  |
| ------------ | ------------------------------------------------------------------------ |
| `create_own` | Create an entity; the actor becomes the owner.                           |
| `create_all` | Create an entity; the actor may set `owner` to any user.                 |
| `read_own`   | Read entities the actor owns.                                            |
| `read_all`   | Read every entity, regardless of ownership.                              |
| `update_own` | Update entities the actor owns.                                          |
| `update_all` | Update every entity. On Submissions, also lets the actor change `owner`. |
| `delete_own` | Delete entities the actor owns.                                          |
| `delete_all` | Delete every entity.                                                     |

Key rules:

- `update_all` on Submissions implicitly grants `create_all`.
- `read_all` at the Project scope controls index access for forms and roles.
- Submission access is disabled by default — every role that needs to see submissions (including Anonymous on a public form) must be granted explicit `submissionAccess`.
- Only the Project owner can delete the Project itself.

### The three permission scopes

| Scope | Where it lives | Controls |
| --- | --- | --- |
| Project | `access[]` on the Project object | Who can create, read, update, delete forms/resources/roles inside the project. |
| Form Definition | `access[]` on each Form/Resource | Who can read/update/delete the form's JSON definition. `read_all` is required for users to load the form's renderer. |
| Submission Data | `submissionAccess[]` on each Form/Resource | Who can create/read/update/delete actual submission rows. This is "the real access-control story". |

The planner reference at `../../alpha-form-resource-planner/references/template-json.md` → "Top-level `access`" and "`access` vs `submissionAccess` — keep these straight" carries the canonical `access` and `submissionAccess` JSON shapes; common patterns (admin-only, owner-level, public-submit) are documented there.

### Layered access models

Beyond the role-keyed `access` / `submissionAccess` arrays, Form.io supports one overlay model:

1. **Self Access Permissions** — write the submission's own `_id` into its `owner` property. The submission becomes its own owner; useful for "users see only their own records" patterns without a separate user lookup.

(Upstream's Field Match-Based Access and Field-Based Resource Access are not documented in this library: field-based resource access was the group-permissions mechanism, which does not exist in this stack — `../_shared/stack.md` → Absent.)

### Worked examples

**Admin-only resource:**

```json
"submissionAccess": [
  { "type": "create_all", "roles": ["<administrator-id>"] },
  { "type": "read_all",   "roles": ["<administrator-id>"] },
  { "type": "update_all", "roles": ["<administrator-id>"] },
  { "type": "delete_all", "roles": ["<administrator-id>"] }
]
```

**Owner-only resource (user sees only own records):**

```json
"submissionAccess": [
  { "type": "create_all", "roles": ["<administrator-id>"] },
  { "type": "read_all",   "roles": ["<administrator-id>"] },
  { "type": "update_all", "roles": ["<administrator-id>"] },
  { "type": "delete_all", "roles": ["<administrator-id>"] },
  { "type": "read_own",   "roles": ["<authenticated-id>"] },
  { "type": "update_own", "roles": ["<authenticated-id>"] }
]
```

**Public submit (anonymous feedback form):**

```json
"submissionAccess": [
  { "type": "create_own", "roles": ["<anonymous-id>"] },
  { "type": "read_all",   "roles": ["<administrator-id>"] },
  { "type": "update_all", "roles": ["<administrator-id>"] },
  { "type": "delete_all", "roles": ["<administrator-id>"] }
]
```

## REST endpoints

Roles and permissions are plain resources on the CE REST surface:

- `GET/POST/PUT/DELETE {baseUrl}/role[/{roleId}]` — list, create, update, delete roles (CE direct with `x-token`, or proxied via middleware `/v1`).
- `GET {baseUrl}/form/{formId}` / `PUT {baseUrl}/form/{formId}` — read and write `access` / `submissionAccess` arrays on a Form or Resource.
- `GET {baseUrl}/form/{formId}/submission` — list submissions to reason about ownership and grants.
- Import: CE `POST /import` — round-trip the entire role + permission graph in a `template.json` (additive merge; same-machine-name items overwrite).

Use the alpha admin-portal (or CE direct REST) for interactive single-deployment edits; use the REST surface when scripting or driving multi-tenant changes from an agent.

## See also

- `alpha-form-resource-planner` — owns the canonical role objects, `access` arrays, and `submissionAccess` arrays for `template.json`. Start there when designing a new deployment's permission matrix. See `../../alpha-form-resource-planner/references/template-json.md` → "Roles", "Top-level `access`", and "`access` vs `submissionAccess` — keep these straight".
- [`resource-auth.md`](./resource-auth.md) — how roles get attached to a user at login and signup.
- [`sso-keycloak.md`](./sso-keycloak.md) — where role mapping happens for federated logins (at the gateway, before Form.io).
