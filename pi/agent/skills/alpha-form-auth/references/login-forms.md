# Login and registration forms

## Overview

Login and registration forms are the user-facing surface of resource-backed authentication. Both are standard Form.io forms — the difference is in their access rules, the components they expose, and which Actions they carry. A login form gates an existing user submission and issues a JWT; a registration form writes a new submission into the `user` Resource and (typically) issues a JWT immediately after.

## When to use this

Reach for this reference when the user wants to:

- Build a login form from scratch.
- Add a self-register flow with anonymous create access.
- Tighten or loosen `access` / `submissionAccess` on an existing login form.
- Configure brute-force protection on a login form.

Not for:

- The Login Action's role in the alpha auth flow → see [`resource-auth.md`](./resource-auth.md).
- Assigning roles or extending the permission matrix → see [`roles-and-permissions.md`](./roles-and-permissions.md).
- SSO — Keycloak at the gateway → see [`sso-keycloak.md`](./sso-keycloak.md).

## Configuration

### Login form

Components:

- `email` (type `email`, required, `persistent: true`).
- `password` (type `password`, required, `persistent: true`, `protected: true`).
- A submit `button`.

> **Never set `persistent: false` on `email` or `password`.** The login form does not store what the visitor typed because it carries NO Save Submission Action — only a Login Action — not because of `persistent`. `persistent: false` strips the field from the submission body server-side, so the same component block copied onto any form that DOES save into the `user` Resource (a registration form, or a combined login/register form) writes a user row with no credentials, and that user can never log in. Emit `persistent: true` on both fields on every login and registration form, matching Form.io's default `userLogin`.

Access:

- `access`: `read_all` granted to all three default roles (Administrator, Authenticated, Anonymous), so anonymous visitors can load the form definition.
- `submissionAccess`: `create_own` granted to Anonymous so visitors can post the form.

Actions:

- One Login Action with `settings.resources: ["user"]`, `settings.username: "email"`, `settings.password: "password"`, plus brute-force settings:
  - `allowedAttempts` — typically 5.
  - `attemptWindow` — seconds during which `allowedAttempts` is counted (typical 30).
  - `lockWait` — seconds the account stays locked after exceeding `allowedAttempts` (typical 1800 = 30 minutes).

For the full Login Action JSON shape (priority, handler, method, settings), see `../../alpha-form-resource-planner/references/template-json.md` → "Login".

### Registration form

Components:

- `email` (type `email`, required, `persistent: true`).
- `password` (type `password`, required, `persistent: true` — this row is the credential row).
- Any additional profile fields you want to capture at signup.
- A submit `button`.

Access:

- `access`: `read_all` to all three default roles.
- `submissionAccess`: `create_own` to Anonymous.

Actions (order matters because `priority` is the tie-breaker among handlers at the same phase):

1. **Save Submission** (built-in) — persists the new submission. Priority 10, `handler: ["before"]`.
2. **Role Assignment Action** — `settings.association: "new"`, `settings.type: "add"`, `settings.role: "authenticated"`. Priority 1, `handler: ["after"]`. Runs after the save so the new submission already has an `_id`.
3. **Login Action** — `settings.resources: ["user"]`, same field names as the login form. Priority 2, `handler: ["before"]`. Issues the JWT immediately so the new user is logged in without a second round-trip.

If the prompt specifically requires that "admins" log into the application, then you may include `"admin"` in the Login Action's `settings.resources`. Note that most administrative work is performed via the alpha admin-portal or CE direct REST with `x-token` (see [`service-auth.md`](./service-auth.md)), not through the end-user login form.

For the canonical action JSON shapes, see `../../alpha-form-resource-planner/references/template-json.md` → "Login" and "Role Assignment".

### Anonymous vs admin write paths

The Resource Map terminology used by the planner:

- **Anonymous self-register**: registration form has `submissionAccess: create_own` for Anonymous. End users sign themselves up.
- **Admin-issued accounts**: registration form has `submissionAccess: create_all` for Administrator only. Admins seed users via the Form.io project portal (not via the app's UI). The login form is the only user-facing form.

## REST endpoints

- `GET/POST {baseUrl}/v1/form` and `GET {baseUrl}/v1/form/{formId}` — create and read the login/registration forms; `access` and `submissionAccess` arrays are part of the form payload (middleware, `x-api-gw-*` headers).
- `POST {baseUrl}/v1/form/{formId}/submission` — submit the login/registration form.
- `GET/POST/PUT/DELETE {baseUrl}/form/{formId}/action[/{actionId}]` — attach the Login Action to the login form and the Role Assignment + Login Actions to the registration form; `GET .../actions/:name` returns each action's `settings` schema.
- Import: CE `POST /import` — when seeding from a planner-produced `template.json`, this single call creates both forms and all three actions at once. Prefer it over driving form + action CRUD individually for greenfield deployments.

## See also

- `alpha-form-resource-planner` — owns the canonical login and registration form JSON shapes plus the Login Action and Role Assignment Action shapes. Use the planner first if the forms do not yet exist. See `../../alpha-form-resource-planner/references/template-json.md` → "Login" and "Role Assignment" and `../../alpha-form-resource-planner/references/examples/task-manager/template.json` for a working end-to-end example.
- [`resource-auth.md`](./resource-auth.md) — the auth flow, the `x-jwt-token` header, and the `user` Resource shape.
- [`roles-and-permissions.md`](./roles-and-permissions.md) — what `access` and `submissionAccess` actually permit, and how the eight permission types interact.
- [`jwt-and-sessions.md`](./jwt-and-sessions.md) — the JWT that the Login Action returns and how the renderer carries it.
