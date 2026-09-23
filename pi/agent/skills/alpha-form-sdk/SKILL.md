---
name: alpha-form-sdk
description: >-
  Alpha Form.io JavaScript SDK reference (`@formio/js` 1.0.x CJS, `@formio/js/utils`, `@formio/core` helpers), authored from the monorepo fork source. Use when calling `Formio.*` statics, `new Formio(...)` instances, `Utils.*` helpers, plugins, or JSONLogic. Not for: REST endpoints (see `alpha-form-api`); app builds (see `alpha-form-application`); resource schemas (see `alpha-form-resource-planner`); embed-a-form tasks (see `alpha-form-form`).
---

# Form.io SDK Skills

Reference for `@formio/js`, `@formio/js/utils`, and the helpers exposed only by `@formio/core`. Covers SDK bootstrap, authentication, form / submission / role / file / action CRUD, plugin lifecycle, VanillaJS rendering, and the full `Utils` surface (Evaluator, traversal, conditions, logic actions, JSONLogic, mask, sanitize, date, DOM, i18n, fastCloneDeep, override, unwind).

## Preflight — REST-primary, no MCP

This is a pure SDK API reference. There is **no MCP server** in this deployment — no `@formio/mcp` tools, no `project get`/`project set`, no `~/.formio` mapping. The SDK talks to the deployment directly over REST (CE server or middleware `/v1`). Stack-wide facts (auth layers, base URLs, tenancy, versions) are pinned in [`_shared/stack.md`](_shared/stack.md) — read it before the first call. See [`../alpha-form-api/SKILL.md`](../alpha-form-api/SKILL.md) for the endpoint reference.

## Versions and registry

- `@formio/js` **1.0.115** and `@formio/core` **1.0.115**, published to the **private Nexus registry** (`nexus.andsystems.tech/repository/npm-private/`), **not** public npm.
- The middleware pins **1.0.47** — the monorepo line is ahead of what the middleware currently bundles; when a behavior differs, the deployed behavior wins.
- The js fork registers **47 custom loan-domain components** (`packages/js/src/components/custom/`) on top of the standard set — they affect rendering (see alpha-form-form), not the SDK surface below.

## Imports

**Both packages are CJS builds** — `@formio/js` resolves every export to `lib/cjs/*` and `@formio/core` to `lib/index.js`. `import` statements still work (the exports maps route both `import` and `require` to the same CJS files), but there is no ESM build: don't expect `lib/mjs`, and don't assume tree-shaking.

```ts
// Preferred — the renderer-extended SDK covers forms, submissions, roles,
// files, actions, plugins, rendering, and most Utils. The raw jsonLogic
// instance (with lodash operators) is re-exported from @formio/js.
import { Formio, Utils, jsonLogic } from '@formio/js';

// Fallbacks — only when @formio/js does not expose the surface.
// Confirmed in our fork: Evaluator/JSONLogicEvaluator, sanitize, override,
// unwind, dom, fastCloneDeep from @formio/core utils; the runtime logic
// processor from @formio/core/process.
import { Evaluator, JSONLogicEvaluator, sanitize, override, unwind, dom, fastCloneDeep } from '@formio/core';
import { logicProcessSync } from '@formio/core/process';
```

Caveat: the `I18n` bundle lives in the js package (`src/i18n.js`, default export) and is **not** in the published `exports` map of either package — do not import it from `@formio/core` (it isn't there).

## URL Configuration

Configure the base URL exactly once at application bootstrap, **before** any `new Formio(...)` call or `Formio.createForm(...)`. There is **one** base URL per environment — no project URL, no SaaS:

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud'); // CE server (FORMIO_BASE_URL)
```

- Consumers normally go through the **middleware**: `Formio.setBaseUrl('https://.../v1')` (production surface, Keycloak identity at the gateway). See `../alpha-form-api/references/middleware-v1.md`.
- Direct CE access (`setBaseUrl` to the bare CE origin) is for admin/server operations with `x-token` auth.
- `setProjectUrl`/`setPathType` exist on the class (same codebase) but are **inert for this stack** — there are no projects. Do not set them.

## Authentication

The SDK attaches the token you install via `Formio.setToken(...)` to every request. What token to install depends on the surface:

- **Middleware `/v1`:** the gateway (Keycloak) injects `x-api-gw-organization-uuid` + `x-api-gw-user-uuid`; the middleware mints the tenant JWT and proxies. The browser/Node consumer does not handle JWTs at all.
- **CE direct (server-side):** an API key from the `API_KEYS` env var in the `x-token` header (admin), or a user JWT in `x-jwt-token` obtained from `POST /user/login` / `POST /admin/login` (returned in the `x-jwt-token` response header).

`Formio.login(email, password)` posts to the login form and installs the returned token — valid against CE direct. `Formio.currentUser()`, `Formio.getUser()`, `Formio.logout()`, and the JWT decode helpers are unchanged. There is no SSO init in this stack: no SAML, no Okta, no `ssoInit` (see `../alpha-form-auth/SKILL.md` for the Keycloak-at-gateway story).

## REST-first, not MCP-tool-first

Every SDK method below maps 1:1 to a REST endpoint (documented in `../alpha-form-api`). There are no MCP tools to prefer over the SDK — when you are authoring consumer code, the SDK **is** the interface.

## Navigation

| Intent | Reference |
| --- | --- |
| Bootstrap a consumer: `setBaseUrl`, `setToken`, lazy-load | [setup.md](./references/setup.md) |
| Log in / out a user, fetch current user, JWT handling | [auth.md](./references/auth.md) |
| Form CRUD via `new Formio(formUrl).loadForm()` / `saveForm()` / `deleteForm()` / `loadForms()` | [forms.md](./references/forms.md) |
| Submission CRUD, querying, patching, `availableActions`, download URLs | [submissions.md](./references/submissions.md) |
| Role CRUD | [roles.md](./references/roles.md) |
| Upload, download, delete files via storage providers | [files.md](./references/files.md) |
| Register / deregister plugins, lifecycle hooks (`preRequest`, `request`, `wrapRequestPromise`, …) | [plugins.md](./references/plugins.md) |
| Render a form in a VanillaJS / framework consumer via `Formio.createForm` — events, prefill, wizard, read-only | [rendering.md](./references/rendering.md) |
| Evaluate templates and expressions: `Utils.Evaluator`, `interpolate`, `evaluate`, `noeval` | [utils-evaluator.md](./references/utils-evaluator.md) |
| Traverse and search component trees: `eachComponent`, `eachComponentData`, `getComponent`, `findComponent`, `flattenComponents` | [utils-form-traversal.md](./references/utils-form-traversal.md) |
| Evaluate conditional logic: simple / JSON / legacy / custom conditionals | [utils-conditions.md](./references/utils-conditions.md) |
| Run logic actions and triggers (`checkTrigger`) | [utils-logic.md](./references/utils-logic.md) |
| JSONLogic operators and Form.io custom operators | [utils-jsonlogic.md](./references/utils-jsonlogic.md) |
| Input masks, HTML sanitization, DOM helpers | [utils-mask-sanitize.md](./references/utils-mask-sanitize.md) |
| Misc: date helpers, i18n, `unwind`, `fastCloneDeep`, `override` | [utils-misc.md](./references/utils-misc.md) |

## How to use this skill

1. Identify the intent (configure URLs, render a form, query submissions, evaluate a condition, …).
2. Open the matching reference in the table above.
3. Copy the example, swap the URLs for your deployment, and run.

Sourced from `packages/core/src/sdk/Formio.ts`, `packages/core/src/sdk/Plugins.ts`, `packages/js/src/Formio.js`, and `packages/core/src/utils/*` + `packages/js/src/utils/*` in the monorepo fork.
