# JWT and sessions

## Overview

Every authenticated Form.io request rides a JSON Web Token (JWT). The alpha stack uses two kinds of credential on the wire:

- `x-token` + `API_KEYS` — the CE server's **service/admin bypass** (stateless; see [`service-auth.md`](./service-auth.md)).
- `x-jwt-token` — the **user/tenant JWT** that CE issues at login and every renderer/API call carries afterwards.

This reference documents the `x-jwt-token` payload, the Session ID, the on-the-wire header, the logout semantics that invalidate a session, and token lifetime. It replaces the upstream JWT story wholesale: there is no MCP portal-login, no 2FA, no reCAPTCHA, and no customer-minted Custom JWT in this stack.

## When to use this

Reach for this reference when:

- You need to know what's in the JWT (decode the payload, name the claims, explain `jti`).
- You need to know which header carries it and when.
- You need to invalidate a session (logout).
- You need to integrate Form.io auth with another system that consumes JWTs.

Not for:

- Choosing an auth mechanism — see [`resource-auth.md`](./resource-auth.md), [`sso-keycloak.md`](./sso-keycloak.md), [`service-auth.md`](./service-auth.md).
- Designing role-keyed access — see [`roles-and-permissions.md`](./roles-and-permissions.md).

## Configuration

### The on-the-wire header

- **`x-jwt-token`** — the user/tenant JWT. Issued by CE at login: the middleware's `token.service.ts` POSTs `admin/login` and reads the `x-jwt-token` **response header**; the in-browser renderer logs users in through the Login Action the same way. Every subsequent request from that caller carries the JWT on `x-jwt-token`. The renderer persists it into `localStorage` under `formioToken` and re-attaches it on every request.
- **`x-token`** — service auth. Value must be one of the deployment's `API_KEYS` (admin bypass). See [`service-auth.md`](./service-auth.md).

The CE server verifies `x-jwt-token` with the deployment JWT secret (`front-end/formio/formio/src/middleware/tokenHandler.js`): expired → HTTP 440, malformed → HTTP 400, and it re-attaches the token via the `x-jwt-token` response header.

### JWT payload

A decoded Form.io JWT looks like this:

```json
{
  "user": { "_id": "5e5411ba1e29ee1aab5031d9" },
  "iss": "https://form-dev.alpha.looms.cloud",
  "sub": "5e5411ba1e29ee1aab5031d9",
  "jti": "5fffbb5646d76c292a7b5df1",
  "iat": 1610595158,
  "exp": 1610609558
}
```

Claim semantics:

- `user._id` — MongoDB ID of the user submission (the `user` Resource row) that authenticated.
- `iss` — issuer; the Form.io API base URL.
- `sub` — subject; same as `user._id`.
- `jti` — Session ID. Logging out invalidates this; see below.
- `iat`, `exp` — issued-at and expiry timestamps (unix seconds).

The CE fork's validator also understands `user._id === 'external'`, `temp`, and `isAdmin` claims (`tokenHandler.js`), but nothing in the alpha stack mints tokens with those claims — do not mint them.

### Session ID (`jti`) and logout

`jti` is a Form.io-issued Session ID. The relationship between JWTs and sessions:

- A login creates a Session ID and issues a JWT carrying that `jti`.
- A logout API call invalidates the Session ID. Every JWT that carries the invalidated `jti` immediately stops working — so logging out one device logs the user out of every device that holds a JWT for the same session.
- A user can hold multiple concurrent sessions (different devices, different logins) — each has its own `jti`. Invalidating one does not touch the others.

For the runtime logout endpoint URL and shape, see the `runtime-auth` reference in the `alpha-form-api` skill.

### Token lifetime and refresh

Form.io JWTs expire at `exp`. After expiry the renderer treats the user as anonymous and prompts for re-authentication. The deployment configures the lifetime.

In the middleware, tenant JWTs are **cached in Redis per tenant** and refreshed by re-running `admin/login` when they approach expiry (`token.service.ts` `generateNewToken`); the super-admin token auto-renews via `admin.service.ts`. See [`service-auth.md`](./service-auth.md).

### Decoding a JWT for debugging

The Form.io JWT is a standard JWS. Decode it with any standard JWT library to inspect the payload. Do not decode it client-side from untrusted input as a substitute for server-side validation.

## REST endpoints

- `POST {baseUrl}/admin/login` — CE login (JWT in the `x-jwt-token` response header).
- `POST {baseUrl}/user/login` — CE user login, same mechanism.
- Logout/session endpoints: see the `runtime-auth` reference in the `alpha-form-api` skill.

## See also

- [`resource-auth.md`](./resource-auth.md) — the auth flow that issues the JWT this reference describes.
- [`service-auth.md`](./service-auth.md) — the `x-token`/`API_KEYS` alternative and the middleware tenant-JWT sign-in.
- [`sso-keycloak.md`](./sso-keycloak.md) — the gateway chain that ends in a tenant JWT.
- [`roles-and-permissions.md`](./roles-and-permissions.md) — the role-keyed authorization the JWT identity is fed into at runtime.
