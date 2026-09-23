---
name: alpha-form-auth
description: >-
  Form.io auth for the alpha stack: resource-backed login, role-based access control, Keycloak SSO at the gateway, service auth (`x-token`/`API_KEYS`), tenant JWTs, sessions. Use when configuring how users authenticate — login forms, roles, permissions, RBAC. Not for: resource/data-model design (see `alpha-form-resource-planner`); app builds (see `alpha-form-application`); per-form action settings (see `alpha-form-actions`); REST endpoints (see `alpha-form-api`).
---

# Form.io Auth Reference (alpha fork)

## Overview

Everything authentication and authorization in the alpha formio stack: how a user proves identity (resource-backed login, Keycloak at the gateway, `x-token`/`API_KEYS` service auth, tenant JWT), how the stack carries that identity on the wire (`x-jwt-token` header, JWT payload, `jti` Session ID), and how that identity gates access at three scopes (project, form definition, submission data) through role-based access control.

The skill is documentation-only. It does not emit `template.json`. When a configuration depends on resources, roles, or forms, this skill points to `alpha-form-resource-planner`, which owns the canonical JSON shapes for roles, the Login Action, the Role Assignment Action, `access` arrays, and `submissionAccess` arrays.

The stack facts below are the single source of truth for every skill — see [`_shared/stack.md`](_shared/stack.md) and do not drift from it.

## Preflight — direct REST, no MCP server

This library has no MCP server and no `@formio/mcp` tooling. All auth configuration is done with **direct REST calls** against one of two surfaces:

- **Middleware (production surface)** — `{baseUrl}/v1/*` with the identity headers `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` (injected by Keycloak at the API gateway) and `x-request-id` for correlation. The middleware mints a tenant JWT (Redis-cached) and proxies to the CE server.
- **CE server (admin/server ops)** — `{baseUrl}` direct. Admin: `x-token` header whose value is in the `API_KEYS` env var (bypass, not an identity). End users: `x-jwt-token` header; login is `POST /admin/login` (tenant/CE users) or `POST /user/login` — the JWT comes back in the `x-jwt-token` **response header**.

Resolve the target before the first call: ask for the CE base URL (`FORMIO_BASE_URL`, e.g. `https://form-dev.alpha.looms.cloud`) and, when writing through the middleware, the tenant org UUID. State the resolved base URL in one line before any write so a wrong target is caught. Never invent a base URL and never reuse one from another deployment.

**No `x-api-key`, no SaaS auth, no token swap, no SSO inside Form.io** — SSO is Keycloak at the gateway, outside Form.io (see [`references/sso-keycloak.md`](./references/sso-keycloak.md)).

## When to use this

Activate `alpha-form-auth` when the user is asking about identity, sessions, or access control in the alpha formio stack. Sample triggers:

- "How does SSO work in the alpha stack — where does Keycloak fit?"
- "How do I authenticate a service/server call against the CE server?"
- "How does a tenant get its JWT?"
- "Who can read submissions if the role has `read_own` but not `read_all`?"
- "How does logout work? What invalidates a JWT?"
- "What do `access` and `submissionAccess` actually permit?"

Not for:

- Designing roles or login forms inside a fresh resource map → `alpha-form-resource-planner`.
- "Build me a CRM" or "scaffold an app for this project" → `alpha-form-application`.
- "What's the URL of the `/admin/login` endpoint?" → `alpha-form-api`.
- Per-form action settings for one Login or Role Assignment Action → `alpha-form-actions`.

## Map of references

Each reference doc is self-contained and follows the section layout `Overview` → `When to use this` → `Configuration` → `REST endpoints` → `See also`.

- [`references/resource-auth.md`](./references/resource-auth.md) — Resource-backed login with the Login Action + Role Assignment Action, the alpha auth chain, and the `x-jwt-token` response header.
- [`references/login-forms.md`](./references/login-forms.md) — Login and registration form patterns: `access`, `submissionAccess`, anonymous self-register, brute-force protection settings.
- [`references/roles-and-permissions.md`](./references/roles-and-permissions.md) — Default roles, custom roles, the eight permission types (`create_own`, `create_all`, `read_own`, `read_all`, `update_own`, `update_all`, `delete_own`, `delete_all`) across project, form-definition, and submission-data scopes.
- [`references/sso-keycloak.md`](./references/sso-keycloak.md) — SSO is Keycloak at the API gateway: the header-injection chain and how the middleware derives the tenant JWT. Form.io never sees the IdP.
- [`references/service-auth.md`](./references/service-auth.md) — `x-token` + `API_KEYS` service auth on the CE server and the middleware's tenant-JWT sign-in (`token.service.ts` / `admin.service.ts`).
- [`references/jwt-and-sessions.md`](./references/jwt-and-sessions.md) — JWT payload, `x-jwt-token` header, `jti` Session ID, logout semantics, token lifetime.

## Handoff with alpha-form-resource-planner

The planner owns the data model. `alpha-form-auth` owns the auth configuration that runs on top of it. The contract:

- When the user is still designing roles, the user resource, or login/registration forms, run `alpha-form-resource-planner` first. The planner emits a `template.json` with role objects, the Login Action, the Role Assignment Action, `submissionAccess` arrays, and `access` arrays.
- When the user is configuring auth beyond the planner's defaults — RBAC tuning, service auth, the Keycloak chain, JWT/session questions — hand off to `alpha-form-auth`.

Action JSON shapes are NOT duplicated here — they live in `../alpha-form-resource-planner/references/template-json.md` and are referenced by file path from this skill.
