# Resource-backed authentication

## Overview

Resource-backed authentication is Form.io's first-party identity mechanism. A submission of a Form.io Resource (typically the built-in `user` resource) represents an authenticated user; a Login Action on a login form verifies credentials against that Resource and issues a JWT, and a Role Assignment Action on a registration form attaches a Form.io Role to the new submission immediately on signup. Together they cover the full "log in" and "sign up" surface for any Form.io project that does not rely on an external Identity Provider.

## When to use this

Reach for resource auth when the user wants:

- Email-and-password login backed by a Form.io Resource.
- A self-register flow that assigns an initial role on signup.
- A first-party identity store (no external IdP, no SSO, no Custom JWT).
- Brute-force protection on a login form (allowed attempts, attempt window, lock duration).

Not for:

- SSO — Keycloak at the API gateway → [`sso-keycloak.md`](./sso-keycloak.md).
- Service/server auth (`x-token` + `API_KEYS`) and the middleware tenant-JWT sign-in → [`service-auth.md`](./service-auth.md).
- What a JWT contains, session invalidation → [`jwt-and-sessions.md`](./jwt-and-sessions.md).

## Configuration

### Six-step Form.io authentication flow

1. **Authentication Method Selection** — in the alpha stack the first-party mechanism is Resource-based (see [`sso-keycloak.md`](./sso-keycloak.md) for the SSO alternative, which runs at the gateway before Form.io is involved).
2. **Authentication Form Configuration** — build a login form that collects `email` and `password`, plus a registration form that collects the same fields and any profile data.
3. **Authentication Request** — the user submits the login form. The submission payload reaches the Form.io server.
4. **Verification** — the Login Action looks up a matching submission of the configured Resource (`settings.resources`), runs a one-way hash comparison on the password, and gates the submission.
5. **Authentication Success** — Form.io generates a JWT representing the matched user submission and attaches it to the response (`x-jwt-token` header); roles are assigned via the Role Assignment configured on the user.
6. **Brute-force protection** — the Login Action enforces `allowedAttempts`, `attemptWindow`, and `lockWait` (see below); there is no 2FA or reCAPTCHA layer in this stack.

### JWT on the wire

Every request to these endpoints carries the user JWT on the `x-jwt-token` header. In the alpha stack the JWT is obtained from the CE login endpoints — the middleware signs in as the tenant's CE user via `POST /admin/login` and reads the `x-jwt-token` **response header** (`token.service.ts`); the in-browser renderer logs users in through the Login Action and stores the returned token in `localStorage` under `formioToken`, re-attaching it on every subsequent request.

Service-to-service calls that need admin access use `x-token` + `API_KEYS` instead — see [`service-auth.md`](./service-auth.md). There is no MCP server, no browser portal-login flow, and no `x-api-key`.

### Login form + Login Action

The login form is a normal Form.io form with two components — `email` (type `email`, `persistent: true`) and `password` (type `password`, `persistent: true`, `protected: true`). Nothing is stored because the form carries no Save Submission Action, so never set `persistent: false` on either field — see [`login-forms.md`](./login-forms.md) → "Login form". It needs:

- `access`: `read_all` for all three default roles (Administrator, Authenticated, Anonymous), so unauthenticated visitors can load the form definition.
- `submissionAccess`: `create_own` for `anonymous` (so visitors can submit it).
- One Login Action attached to the form.

The Login Action's `settings.resources` should be `["user"]` for most cases (or whichever Resource holds the credentials, such as `"admin"` for applications requiring admin logins). `settings.username` names the field that holds the username/email (typically `"email"`); `settings.password` names the password field (typically `"password"`). Brute-force protection is controlled by `allowedAttempts`, `attemptWindow`, and `lockWait`.

In the alpha stack the login form is the CE `adminLogin` form and the login surface the middleware drives is `POST /admin/login`. During tenant provisioning the middleware creates the tenant's login actions (`tenant.service.ts`), including the admin-login action on `form/{adminLoginFormId}/action`. The Login Action also checks the primary project-admin role (hook `getPrimaryProjectAdminRole`) before granting admin.

For the canonical Login Action JSON shape (priority, handler, method, all field names), see `../../alpha-form-resource-planner/references/template-json.md` → "Login".

### Registration form + Role Assignment Action

The registration form is a separate form (typically `userRegister`) that writes a new submission into the `user` Resource. It needs:

- A Role Assignment Action (`name: "role"`, `settings.association: "new"`, `settings.type: "add"`, `settings.role: "authenticated"`, `priority: 1`, `handler: ["after"]`) to attach the initial role to the new submission.
- A Login Action immediately afterward (priority 2, `handler: ["before"]`) so the new user is logged in without a second round-trip.

Tenant registration creates one Role Assignment Action per tenant admin resource (`middleware` `tenant.service.ts` `createRoleAssignmentAction`).

For the canonical Role Assignment Action JSON shape, see `../../alpha-form-resource-planner/references/template-json.md` → "Role Assignment".

### The `user` Resource

The canonical `user` Resource holds `email` (unique, `protected: false`) and `password` (`protected: true`). Its `submissionAccess` grants the administrator full CRUD and the authenticated role `read_own` + `update_own`. See the planner reference at `../../alpha-form-resource-planner/references/template-json.md` → "The canonical `user` resource".

## REST endpoints

Auth configuration runs through the form/action REST surface:

- `GET {baseUrl}/v1/form/{formId}` / `POST {baseUrl}/v1/form` — create/read forms (middleware, `x-api-gw-*` headers).
- `GET/POST/PUT/DELETE {baseUrl}/form/{formId}/action[/{actionId}]` — attach and configure the Login Action and Role Assignment Action (CE direct with `x-token`, or proxied via middleware `/v1`).
- `POST {baseUrl}/admin/login` — the login endpoint the middleware drives.
- Import: CE `POST /import` — seed a whole template (user Resource, login/registration forms, actions, roles) in one call. See [`../../alpha-form-application/IMPORT.md`](../../alpha-form-application/IMPORT.md).

If you are seeding a fresh deployment from a planner-produced `template.json`, `POST /import` is the single call that creates the user Resource, the login/registration forms, and all three actions in one shot — no need to drive `form_create` + `action_create` individually.

## See also

- `alpha-form-resource-planner` — owns the canonical JSON shapes for the user Resource, login/registration forms, the Login Action, and the Role Assignment Action. Run the planner first if any of these do not yet exist. See `../../alpha-form-resource-planner/SKILL.md` and `../../alpha-form-resource-planner/references/template-json.md`.
- [`login-forms.md`](./login-forms.md) — login + registration form shapes in more detail.
- [`roles-and-permissions.md`](./roles-and-permissions.md) — what each role can do and how the eight permission types layer onto these forms.
- [`jwt-and-sessions.md`](./jwt-and-sessions.md) — the JWT payload Form.io returns, `jti` Session ID, logout.
- [`service-auth.md`](./service-auth.md) — the `x-token`/`API_KEYS` alternative for service callers.
