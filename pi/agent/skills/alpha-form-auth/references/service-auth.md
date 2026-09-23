# Service auth — `x-token` + `API_KEYS` and the tenant JWT

## Overview

Two mechanisms authenticate non-interactive callers in the alpha stack:

1. **CE service auth (`x-token` + `API_KEYS`)** — the CE server's admin bypass for server-to-server calls: a request carrying an `x-token` header whose value appears in the `API_KEYS` environment variable is treated as an admin, no user identity attached.
2. **Tenant JWT sign-in (middleware)** — the NestJS middleware authenticates to the CE server as a tenant's user via `POST /admin/login`, caches the returned `x-jwt-token` (Redis), and forwards it on proxied requests.

This reference is the replacement for the upstream "Custom JWT" story: nothing in the alpha stack mints Form.io tokens with a shared secret (`JWT_SECRET` forging does not exist here). The CE fork still *validates* tokens that carry `external` / `temp` / `isAdmin` claims (`tokenHandler.js`), but no alpha component mints them — do not mint them.

## When to use this

Reach for this reference when:

- A service, script, or CI pipeline needs admin access to the CE server (use `x-token` + `API_KEYS`).
- You need to understand how a tenant's requests get their JWT (middleware sign-in).
- The user asks "how do I authenticate a backend call to Form.io?"

Not for:

- End-user browser authentication → [`resource-auth.md`](./resource-auth.md).
- SSO / where Keycloak fits → [`sso-keycloak.md`](./sso-keycloak.md).
- What a JWT contains → [`jwt-and-sessions.md`](./jwt-and-sessions.md).

## Configuration

### CE service auth — `x-token` + `API_KEYS`

Implemented in `front-end/formio/formio/src/middleware/tokenHandler.js`:

- The handler reads `req.headers['x-token']`. If its value is present in `process.env.API_KEYS` (comma-separated), it sets `req.isAdmin = true`, `req.permissionsChecked = true`, `req.user = null`, `req.token = null`, and proceeds.
- This is a **bypass, not an identity** — no user submission is loaded, no roles are attached. Requests authenticated this way act as the server's admin for the duration of the call.
- Otherwise the handler verifies the `x-jwt-token` JWT with the deployment's JWT secret; on `TokenExpiredError` → HTTP 440, on `JsonWebTokenError` → HTTP 400. It re-attaches the token via `res.setHeader('x-jwt-token', token)`.

Usage: send the header on every request that must act as admin:

```
x-token: <one of the API_KEYS values>
```

**There is no `x-api-key`, no SaaS API key management.** Rotate `API_KEYS` at the deployment level; leakage lets any caller act as admin on the CE server.

### Tenant JWT sign-in (middleware)

The middleware authenticates to the CE server on behalf of a tenant and forwards the tenant's JWT downstream.

`front-end/formio/middleware/src/middleware/services/token.service.ts`:

- `generateNewToken` POSTs to `{ceBaseUrl}/admin/login` with `email` / `password` of the **tenant's** CE user (created at tenant registration), reads the returned `x-jwt-token` **response header**, and decodes `exp`.
- The tenant JWT is cached (Redis) per tenant and refreshed as needed — this is the token forwarded to CE on proxied requests.

`front-end/formio/middleware/src/middleware/services/admin.service.ts`:

- The **super admin** (`FORMIO_ADMIN_EMAIL` / `FORMIO_ADMIN_PASSWORD`) signs in once, caches `adminToken`, and exposes `getAdminToken()` / `getAdminRoleId()` with auto-renewal.
- Middleware server-side operations (e.g. form CRUD for tenant provisioning) use this admin token — see `form.service.ts` / `submission.service.ts` `proxyRequestAsAdmin`.

### Multi-tenancy note

Each tenant is an org UUID and has its own CE user/role (`<tenant>-admin`) and its own JWT. Isolation layers: request identity headers (`x-api-gw-*`), form `tags` containing the tenant UUID, and `owner` + `submissionAccess` on submissions. See `front-end/formio/middleware/docs/multi-tenancy.md`.

## REST endpoints

- `POST {baseUrl}/admin/login` — CE login; JWT returned in the `x-jwt-token` response header.
- `POST {baseUrl}/user/login` — CE user login (same mechanism, normal users).
- Middleware `/v1/*` — all proxied endpoints accept the `x-api-gw-*` identity headers and forward the tenant JWT.

## See also

- [`sso-keycloak.md`](./sso-keycloak.md) — the gateway chain that produces the identity headers driving the tenant sign-in.
- [`jwt-and-sessions.md`](./jwt-and-sessions.md) — the payload of the JWT this flow obtains.
- [`resource-auth.md`](./resource-auth.md) — the Login Action, which is what `/admin/login` drives server-side.
