# SSO — Keycloak at the API gateway

## Overview

In the alpha stack, single sign-on is **Keycloak at the API gateway** — entirely **outside** Form.io. There is no SSO configuration inside Form.io: no OAuth/OIDC provider registration, no SAML/LDAP directory setup, no Remote Authentication, no SSO role mapping on the Form.io side. Form.io never sees the Identity Provider, never builds an ephemeral user from IdP claims, and never issues a token on the IdP's behalf.

The chain is: the user authenticates to Keycloak → the API gateway validates the Keycloak JWT and injects identity headers → the NestJS middleware trusts those headers and mints a **tenant JWT** against the CE server → CE authenticates on the `x-jwt-token`.

## When to use this

Reach for this reference when the user asks:

- "How does SSO work in the alpha stack?"
- "Where is OIDC/SAML/LDAP configured?" (Answer: at the gateway/Keycloak realm, never inside Form.io.)
- "How do users get from a Keycloak login to a Form.io session?"
- "Where does role mapping happen?" (Answer: in Keycloak / at the gateway, before Form.io is involved.)

Not for:

- Service/server authentication against the CE server → [`service-auth.md`](./service-auth.md).
- The resource-backed login form and Login Action → [`resource-auth.md`](./resource-auth.md).
- RBAC after authentication → [`roles-and-permissions.md`](./roles-and-permissions.md).

## Configuration

### The auth chain (no Form.io involvement until the end)

1. The user signs in to **Keycloak** (the IdP). The gateway validates the resulting Keycloak JWT.
2. The gateway injects the identity headers on the proxied request:
   - `x-api-gw-organization-uuid` — the tenant boundary (org UUID).
   - `x-api-gw-user-uuid` — the user identity.
   - `x-request-id` — correlation.
3. The **middleware trusts these headers** (no local JWT guard in the middleware — the `@and/nest-common` bootstrap exposes routes to the gateway, which is where validation happens). See `front-end/formio/middleware` `src/middleware/controllers/auth.controller.ts` and `src/middleware/utils/constants.ts`.
4. The middleware derives a **tenant JWT** by signing in to the CE server as the tenant user — see [`service-auth.md`](./service-auth.md) → "Tenant JWT sign-in (middleware)".
5. CE authenticates the proxied request on the tenant `x-jwt-token` header.

### Role mapping

Role mapping happens in **Keycloak / at the gateway**, before Form.io is involved — there is no SSO role-mapping table inside Form.io. Whatever roles the gateway's mapping attaches to the user are the roles the tenant JWT ends up carrying (via the tenant's CE user record), and those roles then gate `access` / `submissionAccess` inside Form.io exactly like any other role assignment.

### What does NOT exist here

- No OAuth/OIDC provider registration, SAML or LDAP directory config inside Form.io.
- No Remote Authentication (ephemeral in-token users from IdP claims).
- No SSO email-token (magic-link) authentication.
- No Token Swap — the host app's token is consumed by Keycloak at the gateway, never exchanged for a Form.io token.
- No 2FA or reCAPTCHA configuration inside Form.io (MFA, if any, is enforced at the IdP).

If the user asks for any of these, they are asking about a different platform — point them at the gateway/Keycloak side.

## REST endpoints

SSO itself has no Form.io REST surface — it is gateway infrastructure. The endpoints that appear in the chain are:

- Middleware: `POST {baseUrl}/v1/auth/registerTenant` — tenant bootstrap (the only middleware auth controller route; creates the tenant's CE user/role and login actions).
- Middleware: `GET {baseUrl}/v1/auth/hello` — health/probe, gated by `@RequiredPermissions('application-manage:APPLICATION_FORM')` at the gateway.
- CE: `POST {baseUrl}/admin/login` — the login the middleware drives to obtain the tenant JWT (see [`service-auth.md`](./service-auth.md)).

## See also

- [`service-auth.md`](./service-auth.md) — the `x-token`/`API_KEYS` service auth and the tenant-JWT sign-in the chain ends with.
- [`jwt-and-sessions.md`](./jwt-and-sessions.md) — the JWT payload CE issues and how it rides the `x-jwt-token` header.
- [`roles-and-permissions.md`](./roles-and-permissions.md) — how the roles carried by that JWT gate access at runtime.
