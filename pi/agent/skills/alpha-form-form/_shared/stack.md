# Alpha Form.io Stack — shared facts

Single source of truth for every skill in this library. Skills state the
facts below **without divergence**; when a detail changes, change it here and
re-check the skills that reference it.

Targets: CE server hard fork (`front-end/formio/formio`), NestJS middleware
(`front-end/formio/middleware`), `@formio` monorepo forks
(`front-end/formio/monorepo`).

## Auth

**Layer 1 — CE server (direct access, admin/server ops):**

- `x-token` header + `API_KEYS` env var → admin bypass.
- `x-jwt-token` header → end-user auth.
- Login: `POST /user/login` (normal user) / `POST /admin/login` (admin) —
  the JWT comes back in the `x-jwt-token` **response header**.
- **No `x-api-key`, no SaaS auth, no token swap.**

**Layer 2 — middleware (`/v1`, production surface):**

- Keycloak at the gateway injects `x-api-gw-organization-uuid` +
  `x-api-gw-user-uuid` identity headers.
- Middleware mints a tenant JWT (Redis-cached) and proxies to CE.
- `x-request-id` correlation header.
- Global prefix `/v1`.

## URLs

- CE: `FORMIO_BASE_URL` env, e.g. `https://form-dev.alpha.looms.cloud`.
- Middleware: `{baseUrl}/v1/*` — **the production surface consumers call**;
  CE direct only for admin/server operations.
- One base URL per environment — no `{projectUrl}`, no SaaS
  projects/stages/tenants/teams.

## Tenancy

- Form `tags=[orgUuid]` marks tenant ownership.
- `*_own` ACLs (submission ownership) + `{basePath}-{orgUuid}` path scoping.
- `mdm-*` resources are **exempt** — CDC-managed shared reference data
  (`source_id`, `sharedAccess` `read_all` for everyone, mandatory `:save`
  action), never modeled as user resources.
- `PROTECTED_FORMS = ['structure', 'admin', 'user', 'mdm-gender']`.

## Templates

- Envelope: `{title, name, version, description, roles, resources, forms,
  actions, access}` — object maps keyed by **machineName**.
- Import: CE `POST /import` (bootstrap-style, matches
  `default-template.json`).
- Role machineName → ObjectId resolution; `bootstrapNewRoleAccess` auto-grants
  `read_all` on new roles.

## Actions

- Exactly **6 types**: `save, email, login, resetpass, role, webhook`.
- Priorities: save 10 / login 2 / role 1 / email+webhook 0.
- **No** group/oauth/ldap/2fa actions.

## Components & plugins

- Standard Form.io component types + **47 custom loan-domain components**
  (`packages/js/src/components/custom/`).
- `machineName` / `timestamps` plugins — server-set, read-only on submissions.

## Versions

- Monorepo `@formio/js` + `@formio/core`: **1.0.115** (Nexus private registry).
- Middleware pins **1.0.47** — reference line is 1.0.115; state the pin
  divergence explicitly where versions matter.

## i18n

- 6 bundles: `en/ja/mn/th/tl/vi`.
- Nested dotted keys + `{name}` placeholders.
- `Accept-Language`-driven.

## Absent — never document as existing

PDF server, SaaS projects/stages/tenants/teams, group permissions, Token Swap,
Custom JWT minting, 2FA, reCAPTCHA, SSO inside Form.io, `@formio/mcp` MCP
server, `project get`/`project set`, `~/.formio`, `api.form.io`, `x-api-key`,
`@formio/angular`/`angular.json`.
