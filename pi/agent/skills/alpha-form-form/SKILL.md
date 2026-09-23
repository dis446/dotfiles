---
name: alpha-form-form
description: >-
  Embed and render Form.io forms with the Vanilla JS renderer (`@formio/js` alpha fork): render by URL/JSON, pre-fill, conditional fields, calculated values, validation, wizards. Use to put a form on a page or change field behavior inside a rendered form. Not for: building apps (see `alpha-form-application`); data models (see `alpha-form-resource-planner`); REST endpoints (see `alpha-form-api`); raw SDK reference (see `alpha-form-sdk`); creating new forms (see `alpha-form-form-builder`).
---

# Embedding Form.io Forms (Vanilla JS renderer)

Task guide for putting a Form.io form on a page and wiring its behavior with the `@formio/js` renderer (alpha fork — same codebase as upstream, `1.0.x`, see [`_shared/stack.md`](_shared/stack.md)). Everything routes through one API:

```js
const form = await Formio.createForm(element, srcOrJson, options);
```

## Preflight — no MCP tools, direct REST

There is **no MCP server tooling in the alpha stack**: no MCP form/action tools, no project-mapping commands, no per-project config files, no `formio.json`. Do not look for MCP tools or a setup skill for them; neither exists here.

The renderer talks to the deployment over plain HTTPS. Embed URLs resolve against **one base URL** per environment:

- **Middleware `/v1`** — the production surface consumers call. Keycloak at the gateway injects `x-api-gw-organization-uuid` + `x-api-gw-user-uuid`; the middleware mints the tenant JWT and proxies to CE. Form URLs are `{baseUrl}/v1/form/{formPath}`.
- **CE direct** — `{FORMIO_BASE_URL}` (e.g. `https://form-dev.alpha.looms.cloud`), admin/server ops only, authenticated with `x-token` + `API_KEYS` (admin) or `x-jwt-token` (user).

When the embed needs the form definition or a write (changing components, saving a NEW form), use the REST surface directly — `GET {baseUrl}/v1/form/{formPath}` to fetch a definition, `alpha-form-form-builder` for authoring — not MCP tools. Configuring forms and actions is build-time work done against the deployment with the caller's own credentials; see [`_shared/stack.md`](_shared/stack.md) for the exact auth model.

## How to navigate this skill

Read the reference that matches the task; each is self-contained and states which behaviors compose with which.

| Task | Reference |
| --- | --- |
| Page prerequisites — bundle inclusion, target `<div>`, URL configuration | [references/setup.md](./references/setup.md) |
| Render a form by URL, by JSON, or with a submission (pre-fill) | [references/rendering.md](./references/rendering.md) |
| Control the form from JavaScript — events, submission data, components | [references/javascript-api.md](./references/javascript-api.md) |
| Renderer options (`readOnly`, `noAlerts`, `hooks`, `i18n`, `sanitizeConfig`, …) | [references/options.md](./references/options.md) |
| JSON Logic primer — operations and `var` resolution (`data`, `row`, `input`) | [references/json-logic.md](./references/json-logic.md) |
| Show/hide components conditionally (simple and JSON Logic) | [references/conditionals.md](./references/conditionals.md) |
| Compute a field from other fields (`calculateValue`) | [references/calculated-values.md](./references/calculated-values.md) |
| Custom validation rules (`validate.json`) | [references/validation.md](./references/validation.md) |
| Advanced field logic (`logic` triggers and actions) | [references/field-logic.md](./references/field-logic.md) |
| External data sources and cascading selects (make → model → year) | [references/external-data.md](./references/external-data.md) |
| Wizards — conditional pages, custom navigation | [references/wizards.md](./references/wizards.md) |

## Security — a form definition is executable code

A form definition is not inert data. `calculateValue`, `validate.custom`, `logic` actions, HTML/Content component bodies, and select `template` strings are all evaluated by the renderer at render time, in the page's own JavaScript context. Anything that can supply a form definition can therefore run code in your page. Four rules follow, and they apply to every reference in this skill:

- **Render only definitions from a deployment you control.** A form URL or JSON blob is a code-execution channel: never render a definition supplied by an end user, uploaded as a file, pasted into your app, or fetched from a third-party host. `Formio.setBaseUrl` must point at your own Form.io deployment (middleware `/v1` origin or CE root — see [references/setup.md](./references/setup.md)).
- **`fetch.authenticate: true` sends the user's Form.io token.** On a Data Source component (and on select URLs) it attaches the current session's auth token to the outbound request, so pointing that URL at a host you do not own hands your users' credentials to that host. Enable it only for endpoints on your own deployment; for any third-party API leave it `false` and authenticate server-side instead. Same rule for `fetch.forwardHeaders`, which forwards the incoming request's headers verbatim.
- **Do not widen the HTML sanitizer to allow script execution.** The renderer sanitizes labels and HTML content through DOMPurify. `sanitizeConfig.addTags` / `addAttr` ([references/options.md](./references/options.md)) exist for markup like `<iframe>` or `target`; adding `script`, `on*` event attributes, or `srcdoc` turns component content into an XSS vector for anyone who can edit the form.
- **Submitted `data.*` is untrusted in the code you write around the form.** Embedding is build-time work; the values arrive at runtime, in the deployed app, from whoever fills the form in. Anywhere your own code puts a submitted value back into the page — a confirmation screen, a summary table, an `innerHTML`, a URL you build — escape it there, because the renderer's sanitizer covers what it renders and not what you render. The server-side half of the same rule (email bodies, webhook payloads, recipient lists) is in `alpha-form-actions`.

Forms in the alpha stack carry `machineName`, `created`, and `modified` fields set by the server (`machineName`/`timestamps` plugins). They are read-only — never overwrite them from embed code or a submission payload.

## When the form does not exist yet

This skill embeds forms that already exist. If the embed request reveals the form is not in the deployment yet (a `GET {baseUrl}/v1/form/{formPath}` misses, or the user is describing a form from scratch — "embed a multi-step intake wizard on my page"), route to `alpha-form-form-builder` first: it determines the form type (webform vs wizard), authors the definition, and saves it via `POST /v1/form` with `x-api-gw-*` headers (the middleware mints the tenant token). When it finishes, embedding resumes here with the saved form URL.

## URL terminology

- `baseUrl` refers to **one thing**: the deployment the form lives on. Consumers use the **middleware origin** and address forms as `{baseUrl}/v1/form/{formPath}` — that is the production surface. Direct CE access (`{FORMIO_BASE_URL}/{formPath}`) exists for admin/server operations with `x-token`/`API_KEYS`.
- There is **no project URL** — no project-scoped form URLs. `Formio.setProjectUrl` does not exist in this stack's usage; configure only `Formio.setBaseUrl`.

Form URLs passed to `Formio.createForm` live under that one base URL. See [references/setup.md](./references/setup.md) for configuring it.

## Components — standard + 47 custom loan-domain

This stack's renderer is the same `@formio/js` codebase as upstream (1.0.x line), so every standard component type renders identically — but the fork registers **47 custom loan-domain components** on top of the standard set (`packages/js/src/components/custom/` in the monorepo fork). They render from ordinary component definitions and need no special handling on the embed side; their existence matters when a form uses one and you must not second-guess the unknown `type`.

Two plugin-set fields are server-owned and **read-only** at render time: `machineName` (stable machine key on every form/resource/submission) and `created`/`modified` (timestamps). See [`alpha-form-schema`](../alpha-form-schema/SKILL.md) for the full component/field reference.

## REST Tool Preference

When an embed task requires reading or changing the form definition itself, prefer direct REST over ad-hoc scraping:

- `GET {baseUrl}/v1/form/{formPath}` — fetch the form JSON you are about to render or inspect its components.
- `GET {baseUrl}/v1/form/{formPath}/submission` — read submissions (runtime data; see `alpha-form-api` for the full surface).
- Writing component changes or creating a form belongs to `alpha-form-form-builder` (save path: `POST /v1/form` with `x-api-gw-*` headers).

There is no browser-based portal-login flow to capture, no PKCE, no API keys — the caller authenticates per [`_shared/stack.md`](_shared/stack.md): Keycloak gateway headers via the middleware, or `x-token`/`API_KEYS` straight to CE.
