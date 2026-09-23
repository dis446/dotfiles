## Overview

The alpha formio stack has two auth layers. This reference is the single source for both; every other API reference defers here instead of restating the mechanics.

## Layer 1 — CE server (direct access)

The CE server (`{baseUrl}`) uses a custom token scheme — **no `x-api-key`, no SaaS auth, no token swap.**

| Header | Who | Meaning |
| --- | --- | --- |
| `x-token` | admin/server ops | An API key from the `API_KEYS` env var (comma-separated). Presence → `req.isAdmin = true`, bypasses permission checks. |
| `x-jwt-token` | end users | The user JWT, minted by the login actions. Verified against `jwtConfig.secret`; `440` on expiry. |

**Login endpoints** (the JWT comes back in the `x-jwt-token` **response header**, not the body):

- `POST /user/login` — end-user login (submission against the `user/login` login form).
- `POST /admin/login` — admin login (submission against the `admin/login` login form).
- `POST /user/submission` — registration (anonymous create on the `user` resource).

Other auth-adjacent endpoints: `GET /current` (current user document), `GET /logout`, `GET /token` (temporary token minted with `x-admin-key`/`ADMIN_KEY`).

Example admin call:

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/form"
```

Example user call after login:

```bash
curl -H "x-jwt-token: $USER_JWT" \
  "{baseUrl}/current"
```

## Layer 2 — middleware `/v1` (production surface)

Consumers hit the gateway, which authenticates via **Keycloak** and injects two identity headers:

| Header | Meaning |
| --- | --- |
| `x-api-gw-organization-uuid` | The organization (tenant) UUID. |
| `x-api-gw-user-uuid` | The end-user UUID. |

`x-request-id` carries correlation across the request; it is also the versioning key for middleware submission history (see `middleware-v1.md`).

The middleware maps the org UUID → the tenant admin user, logs into CE as that admin (`POST /admin/login`), and proxies each request with the tenant JWT (cached in Redis). The caller never sees the tenant JWT.

There is also `POST /v1/auth/registerTenant` — provisioning a new tenant (admin login form + login action + resource setup).

## Rules

- Never use both layers at once: `/v1/*` requests carry `x-api-gw-*` headers; direct CE requests carry `x-token` or `x-jwt-token`.
- Never send `x-api-gw-*` headers to the CE server directly; they mean nothing there.
- A JWT obtained from `POST /admin/login` is a CE-level admin token — keep it server-side, never ship it to a browser.
