## Overview

The runtime authentication API covers end-user (application user) account lifecycle inside a Form.io project: creating a new user via the default `user` resource, logging in, retrieving the currently authenticated user, logging out, and recognizing an expired session. This skill documents the default `user`/`userLogin` endpoints — for custom user types (e.g., `employee`) and role assignment wiring, see `runtime-custom-users.md`. For auth mechanics (both layers), see `our-auth.md`; for project-admin auth use `project-auth`.

## Root URL

All endpoints below are rooted at `{baseUrl}` — the CE server base URL. There is no `{projectUrl}`: the CE server is single-project, and the middleware proxies `/v1/*` to it.

## Authentication

End-user calls carry a user JWT in the `x-jwt-token` header, minted by the login endpoints below (returned in the `x-jwt-token` response header). Through the middleware, the gateway injects `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` and the middleware proxies with a tenant JWT — see [`our-auth.md`](./our-auth.md) and [`middleware-v1.md`](./middleware-v1.md).

## REST-first

These are **runtime** endpoints — no MCP server exists in this deployment, and there is no build-time tool for them. This document is a specification for the code you write: the app's login, registration, and current-user calls at runtime.

## Endpoints

### POST {baseUrl}/user/submission

Register a new end-user by submitting to the default `user` resource. Creates a new submission of the `user` resource with email/password credentials.

Request body (JSON):

```json
{
  "data": {
    "email": "Minerva.Sipes@yahoo.com",
    "password": "CHANGEME"
  }
}
```

Required fields: `data.email`, `data.password`. Additional fields are accepted if the `user` resource has been extended with more components.

Response: the created user submission document, including `_id`, `form` (the `user` resource ID), `owner`, `roles` (default Authenticated role), `access`, `metadata`, and `data` (with the password stripped). The response also sets an `x-jwt-token` response header containing the JWT for the newly created user.

Errors: `400` if email/password are missing or the email is already taken; `401`/`403` if anonymous submission is not permitted on the `user` resource.

Example:

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"data":{"email":"new.user@example.com","password":"CHANGEME"}}' \
  "{baseUrl}/user/submission"
```

### POST {baseUrl}/user/login/submission

Authenticate an existing end-user against the default `userLogin` form. On success, Form.io validates the credentials against the `user` resource and issues a JWT.

Request body (JSON):

```json
{
  "data": {
    "email": "Minerva.Sipes@yahoo.com",
    "password": "CHANGEME"
  }
}
```

Required fields: `data.email`, `data.password`.

Response: the user submission document for the authenticated user (same shape as the create response — `_id`, `form`, `owner`, `roles`, `access`, `metadata`, `data`). The JWT is returned in the `x-jwt-token` response header; clients MUST persist this value for subsequent authenticated requests.

Errors: `400` for malformed bodies; `401` for invalid credentials or locked accounts (if the Login action has `allowedAttempts`/`lockWait` configured).

Example:

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"data":{"email":"new.user@example.com","password":"CHANGEME"}}' \
  "{baseUrl}/user/login/submission"
```

### GET {baseUrl}/current

Return the currently authenticated user's submission document. Used to rehydrate user state on app start or to check that a stored JWT is still valid.

Response: the full user submission document (same shape as the login response). Fields include `_id`, `form`, `owner`, `roles`, `access`, `metadata`, and `data`.

Errors: see the `Session Expired` subsection below — a `440`-style plain-text `Session no longer valid.` response indicates the JWT has expired or been revoked.

Example:

```bash
curl -H "x-jwt-token: $USER_JWT" \
  "{baseUrl}/current"
```

### GET {baseUrl}/logout

Invalidate the current user session. Form.io clears the JWT server-side so it can no longer be used.

Response: plain text `OK` on success.

Errors: generally idempotent — calling `logout` with an invalid or missing JWT still returns `OK`.

Example:

```bash
curl -H "x-jwt-token: $USER_JWT" \
  "{baseUrl}/logout"
```

### GET {baseUrl}/current (session expired)

Same endpoint as `Get Current User`, but documents the expired-session behavior. When the supplied `x-jwt-token` has expired or been revoked (e.g., after calling `logout`), Form.io responds with a plain-text body:

```
Session no longer valid.
```

Clients should treat this as the signal to clear the locally stored JWT and redirect the user to the login flow.

Example:

```bash
curl -H "x-jwt-token: $EXPIRED_JWT" \
  "{baseUrl}/current"
```

## Related Skills

- [runtime-custom-users](./runtime-custom-users.md) — custom user types, custom roles, and Role actions for non-default auth flows
- [runtime-submissions](./runtime-submissions.md) — submitting form data after the user has authenticated
- [project-auth](./project-auth.md) — project-admin authentication (distinct from end-user auth)
- [project-roles](./project-roles.md) — configuring the roles that are assigned to authenticated users
