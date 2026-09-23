## Overview

Bootstrap a consumer of `@formio/js` (1.0.x, CJS). Configure the base URL, install an authentication token, register plugins, and lazy-load auxiliary libraries before any `new Formio(...)` call or `Formio.createForm(...)`. Sourced from `packages/core/src/sdk/Formio.ts` and `packages/js/src/Formio.js` in the monorepo fork.

## Imports

```ts
import { Formio } from '@formio/js';
```

## URL Configuration

There is **one** base URL per environment. The `Formio` class is a static singleton — URLs are global and must be set once at application bootstrap.

- **Middleware `/v1` (production surface, default for consumers):** `Formio.setBaseUrl('https://<host>/v1')` — Keycloak identity at the gateway; see `../../alpha-form-api/references/middleware-v1.md`.
- **CE server direct (admin/server ops):** `Formio.setBaseUrl('https://form-dev.alpha.looms.cloud')` (the `FORMIO_BASE_URL` env value).

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');
```

`Formio.getBaseUrl()` returns the configured value. `setProjectUrl`, `setPathType`, and `setAuthUrl` exist on the class (same codebase) but are **inert in this stack** — there are no projects and no SSO bridge; do not set them.

## API

Static URL / token methods on `Formio`:

- `setBaseUrl(url: string): void` — set the deployment root.
- `getBaseUrl(): string` — return the current base URL.
- `setToken(token: string, options?: { namespace?: string }): Promise<void>` — store a JWT in local storage and emit a `user` event.
- `getToken(options?: { decode?: boolean }): string` — read the JWT from storage; with `{ decode: true }` it returns the decoded payload object.
- `setToken(null): Promise<void>` — clear the cached JWT (passing `null` removes it from `Formio.tokens` and `localStorage`). The SDK has no `clearTokens()` shortcut; use `setToken(null)` for logout flows that should not also hit the network.
- `setUser(user, options?): void` / `getUser(options?): object` — store / read the cached current-user payload.

Lazy-library helpers:

- `Formio.requireLibrary(name, property, src, polling?, onload?, rootElement?): Promise` — inject a script/stylesheet (or array of sources) and resolve when the named global property is present.
- `Formio.libraryReady(name): Promise` — resolve when a previously required library finishes loading.
- `Formio.cdn` — exposes `Formio.cdn.baseUrl`, `Formio.cdn.libs`, and `Formio.cdn.setBaseUrl(url)` to repoint the CDN root (useful when self-hosting third-party assets like ChoicesJS or Flatpickr).
- `Formio.addLibrary(name, src, flag?)` — register a library so the renderer can lazy-load it on demand.
- `Formio.addLoader(loader)` — install a custom asset loader.

Plugin glue (covered in depth in [plugins.md](./plugins.md)):

- `Formio.registerPlugin(plugin, name): void`
- `Formio.deregisterPlugin(plugin | name): boolean`
- `Formio.getPlugin(name): Plugin | null`

## Examples

### Bootstrap a consumer against the middleware

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');
```

### Repoint the CDN for offline / air-gapped builds

```ts
import { Formio } from '@formio/js';

Formio.cdn.setBaseUrl('https://assets.mysite.com/formio');
Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');
```

### Read a decoded token

```ts
import { Formio } from '@formio/js';

const claims = Formio.getToken({ decode: true });
if (claims && claims.user) {
  console.log('logged in as', claims.user._id);
}
```
