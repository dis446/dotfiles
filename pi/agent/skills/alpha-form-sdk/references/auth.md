## Overview

Authentication and current-user access via `@formio/js`. Covers username/password login, logout, current-user lookup, and JWT decode. **No SSO in this stack** — no SAML, no Okta, no `ssoInit` (the `ssoInit`/`samlInit`/`oktaInit`/`oAuthCurrentUser` statics exist in the shared codebase but have no deployment behind them in alpha; authentication is Keycloak-at-gateway for the middleware, `x-token`/login for CE direct). Sourced from `packages/core/src/sdk/Formio.ts` in the monorepo fork.

## Imports

```ts
import { Formio } from '@formio/js';
```

## URL Configuration

Set the base URL once at bootstrap — see [setup.md](./setup.md). One base URL per environment: middleware `/v1` for consumers, CE direct for server ops. There is no `{projectUrl}`; login posts to `{baseUrl}/user/login` (user) or `{baseUrl}/admin/login` (admin).

## API

- `Formio.currentUser(formio?: Formio, options?): Promise<object>` — return the currently authenticated user (decodes the JWT, calls `${baseUrl}/current` if the cache is stale). Emits a `user` event on the global `Formio.events`.
- `Formio.logout(formio?: Formio, options?): Promise<void>` — `GET /logout`, clear stored tokens, clear request cache, emit `user` with `null`.
- `Formio.setToken(token: string, options?: { namespace?: string }): Promise<void>` — install a JWT; the SDK persists it to `localStorage` under `Formio.namespace`.
- `Formio.getToken(options?: { decode?: boolean }): string` — read the active JWT; with `{ decode: true }` returns the decoded payload (`{ user, exp, iat, ... }`).
- `Formio.setToken(null): Promise<void>` — clear the cached JWT/user payload. The SDK has no `clearTokens()` shortcut; pass `null` to `setToken` (and optionally clear `Formio.tokens` directly) for logout flows that should not hit `/logout`.
- `Formio.pageQuery(): object` — parse `window.location` query + hash params into a plain object.

There is no static `Formio.login`. Login is performed by `saveSubmission` on the login form, which is wrapped on the user resource:

```ts
const userLogin = new Formio(`${Formio.getBaseUrl()}/user/login`);
const submission = await userLogin.saveSubmission({
  data: { email, password },
});
// JWT is delivered in the x-jwt-token response header and auto-installed by the SDK.
```

## Examples

### Email / password login (CE direct)

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud');

const userLogin = new Formio(`${Formio.getBaseUrl()}/user/login`);
const submission = await userLogin.saveSubmission({
  data: { email: 'alice@example.com', password: 'hunter2' },
});

const user = await Formio.currentUser();
console.log('logged in:', user.data.email);
```

Against the middleware, no login call is needed in the app: the gateway (Keycloak) injects `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` and the middleware mints the tenant JWT. `setToken` is then only relevant for direct-CE server-side callers (who set an API key via the `x-token` header instead of a JWT — see `../../alpha-form-api/references/our-auth.md`).

### Read the decoded JWT

```ts
import { Formio } from '@formio/js';

const claims = Formio.getToken({ decode: true });
if (!claims || claims.exp * 1000 < Date.now()) {
  console.warn('token missing or expired');
}
```

### Logout

```ts
import { Formio } from '@formio/js';

await Formio.logout(); // GET /logout + clears cached tokens
```

### Clear the cached JWT without calling /logout

```ts
import { Formio } from '@formio/js';

await Formio.setToken(null); // empties Formio.tokens and removes the persisted JWT
```
