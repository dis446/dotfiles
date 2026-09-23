---
name: alpha-form-api
description: >-
  Form.io REST API reference for the alpha stack: CE server (config/project admin, runtime) and middleware `/v1` — auth, forms, resources, revisions, actions, roles, submissions, health. Use when calling, scripting, or documenting any Form.io endpoint. Not for: building apps (see `alpha-form-application`); data-model planning (see `alpha-form-resource-planner`); JSON schemas (see `alpha-form-schema`); JS SDK (see `alpha-form-sdk`).
---

# Form.io API Skills

Single entry point for the alpha formio REST API surface. Detailed endpoint references live under [`./references/`](./references/) — one file per capability group.

## Preflight — REST-primary, no MCP

There is **no MCP server** in this deployment. Do not look for `@formio/mcp` tools, `project get`/`project set`, or a `~/.formio/projects.json` mapping — none exist here. All work is done with direct HTTP calls against one of the two surfaces below. This skill documents the whole REST surface; use it directly.

Two surfaces exist, and these references never conflate them. Stack-wide facts (auth layers, base URLs, tenancy, versions, i18n) are pinned in [`_shared/stack.md`](_shared/stack.md) — read it before the first call and keep every statement here consistent with it:

- **CE server — `{baseUrl}`** (e.g. `https://form-dev.alpha.looms.cloud`, from the `FORMIO_BASE_URL` env). Single-project Express server: form/resource CRUD, role CRUD, action CRUD, submission CRUD, login, export, `/health`. Used directly for **admin/server operations**.
- **Middleware — `{baseUrl}/v1/*`** — NestJS proxy that is the **production surface consumers call**. Keycloak identity at the gateway; tenant-JWT minting; multi-tenant scoping (`tags`, `*_own` ACLs, org path scoping); submission versioning via `x-request-id`; `GET /v1/submission/bulk`; MDM upsert endpoints. See [`middleware-v1.md`](./references/middleware-v1.md).

Never invent a base URL and never reuse one from another environment. Ask for it (or read `FORMIO_BASE_URL`) when it is not already known.

## Authentication

Two auth layers exist — see [`our-auth.md`](./references/our-auth.md) for the full picture:

- **CE direct:** `x-token` header with an API key from the `API_KEYS` env var (admin bypass) or a user JWT in `x-jwt-token`. Login = `POST /user/login` (user) / `POST /admin/login` (admin); the JWT comes back in the `x-jwt-token` **response header**. No `x-api-key`, no portal login, no token swap.
- **Middleware `/v1`:** Keycloak at the gateway injects `x-api-gw-organization-uuid` + `x-api-gw-user-uuid`; the middleware mints a tenant JWT (Redis-cached) and proxies to CE. `x-request-id` for correlation.

## Scope map

### Project scope — `{baseUrl}/` (CE server, config/admin)

- [our-auth](./references/our-auth.md) — both auth layers, login endpoints, tokens
- [project-auth](./references/project-auth.md) — the `admin` resource and admin login form
- [project-roles](./references/project-roles.md) — role CRUD (CE full CRUD; middleware `/v1/role` is read-only)
- [project-forms](./references/project-forms.md) — form/resource CRUD, path aliases, export
- [form-revisions](./references/form-revisions.md) — CE revisions: `?formRevision=` / `?submissionRevision=` query-param fetch
- [project-actions](./references/project-actions.md) — form action CRUD (6 types: save, email, login, resetpass, role, webhook)
- [server-status](./references/server-status.md) — `/health` liveness

### Runtime scope — `{baseUrl}/` (end-user flows)

- [runtime-auth](./references/runtime-auth.md) — end-user registration and login on the built-in `user` resource
- [runtime-custom-users](./references/runtime-custom-users.md) — custom user resources, custom roles, Login/Role actions
- [runtime-access-control](./references/runtime-access-control.md) — `*_own` submission access, org scoping via middleware
- [runtime-submissions](./references/runtime-submissions.md) — submission CRUD, validate, patch, `?submissionRevision=`

### Middleware scope — `{baseUrl}/v1/`

- [middleware-v1](./references/middleware-v1.md) — the production surface: form/formPath/submission/role/path/mdm controllers, headers, tenancy, versioning

## How to use this skill

When the user asks an API-oriented question, identify the scope (project / runtime / middleware) and open the matching reference file under [`./references/`](./references/). Each reference documents:

- Endpoints (method + path relative to the scope's root URL)
- Request / response shapes
- Related reference docs

Do not merge content across scopes — each reference names its own base URL and endpoint set.
