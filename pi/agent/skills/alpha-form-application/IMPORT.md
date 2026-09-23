# IMPORT — CE template import

> **The base URL and admin credential come from the Preflight, never from you.** The CE base URL is `FORMIO_BASE_URL` (e.g. `https://form-dev.alpha.looms.cloud`); the admin credential is the `x-token` header whose value is in the CE server's `API_KEYS` env var. Never compose, derive, or hand-type either one yourself.

This document is loaded by the parent `alpha-form-application` skill during Step 3. It is **not** a standalone skill — no frontmatter.

## What this covers

- **Step 3:** present an import-confirmation preview, call CE `POST /import`, handle the error branches.

Step 3 runs on BOTH branches of the orchestrator:

- **Build-new** → directly after Step 2 (Plan), in the same invocation. The Preflight resolved the target deployment, so there is nothing to reload. Import pushes the full-project `template.json` into a (presumably empty) deployment.
- **Modify-existing** → directly after Step 2 (Plan) as well. Import pushes the delta `template.json` (only the new resources / fields / actions) into the existing deployment, which merges additively on top of what is already there.

## Authentication — `x-token` + `API_KEYS`

There is no browser portal-login and no MCP server. The import call authenticates as the CE server's admin via the `x-token` header (service auth — see [`../alpha-form-auth/references/service-auth.md`](../alpha-form-auth/references/service-auth.md)). If the token is missing or invalid, the call fails with 401/403 — handle it per the error branches below.

### Where import runs

The CE fork exposes the import engine two ways:

1. **REST: `POST {baseUrl}/import`** — body `{ "template": <object> }` (the template may also be a JSON string). Same-machine-name items are overwritten in place; everything else merges additively. Returns `200 "Ok"` on success. This is the endpoint the orchestrator drives.
2. **Programmatic: `router.formio.template.import`** — the same engine as a CE-side server operation (used by `install.js` bootstrap and the db-update machinery). Use this only when the import must run inside the CE process (e.g. deployment bootstrapping).

The middleware has **no template-import proxy** — import runs against the CE server directly, never through `/v1`. The CE template envelope and the additive-merge semantics are documented in [`_shared/stack.md`](_shared/stack.md) → Templates.

## Step 3 — Import

### The offer-to-import gate

Before any import work, ask whether to import at all.

**Build-new:**

> I have the plan ready — the planner wrote `template.md` (architectural intent) and `template.json` (the Form.io structure). Do you want me to import `template.json` into the CE deployment at `<baseUrl>` now? (You can also skip this step and import later yourself, or build the framework app against a deployment you have already set up. `template.md` stays on disk regardless — it is the seed document the framework path reads.)

**Modify-existing:**

> I have the delta plan ready — the planner wrote a delta `template.md` (architectural intent for the additions) and a delta `template.json` containing ONLY the new resources and actions for this feature. Do you want me to additively import `template.json` into the existing CE deployment now? (You can also skip this and import manually later; the framework wiring in Step 4 can still proceed, but the wired UI will 404 until the import runs. `template.md` stays on disk regardless — the framework extend path reads it for intent.)

If the user declines, mark the Import step skipped and advance to Step 4 (Framework routing). Do not call `/import`.

### The confirmation preview

If the user accepts, print a preview BEFORE calling the endpoint.

**Build-new:**

```
About to import `template.json` into:

  CE Base URL:  <baseUrl>

Template contents:
  - <N> resources: <first-three names>, ...
  - <M> roles:     <role names>
  - <K> forms:     <first-three form names>, ...

WARNING: import merges into the existing deployment. Any existing resources,
forms, or actions with the same machine name will be overwritten. Consider
snapshotting the current template (CE template export) first.

Proceed with the import?
```

**Modify-existing:**

```
About to ADDITIVELY import delta `template.json` into:

  CE Base URL:  <baseUrl>

Delta contents (new resources only):
  - <N> resources: <names>
  - <M> actions:   <names>

Import is additive: existing resources, forms, and actions in the deployment
are preserved. Same-machine-name items would be overwritten — the planner
uses new names for new features, so collisions are rare, but review the
names above before approving.

Proceed with the additive import?
```

Wait for explicit approval. Declining returns to the skip path (Step 4 next, no import).

### Call `POST /import`

On approval, send the template content loaded from the planner's `template.json` file path:

```
POST {baseUrl}/import
x-token: <API_KEYS value>
Content-Type: application/json

{ "template": <the template object> }
```

On success the endpoint returns `200 "Ok"`. Surface it to the user in one sentence ("Imported X resources, Y roles, Z forms into `<baseUrl>`.") and advance to Step 4.

### `{{ config.<key> }}` tokens — do not expect them

Upstream projects carry a project public-config endpoint that resolves `{{ config.<key> }}` tokens (e.g. `{{ config.appUrl }}`) in email templates. **Our CE fork has no per-deployment public-config object** — `{{ config.* }}` tokens do not resolve here. If the planner's template contains any, remove or replace them before import and note it to the user.

## Error branches

Three failure modes. Handle each explicitly; do not silently retry or swallow errors.

#### 1. Auth failure (401/403)

The `x-token` was missing, not in `API_KEYS`, or rejected. Offer the user three choices:

1. Re-enter the CE base URL / check the `x-token` value (wrong environment is the usual cause).
2. Skip import and continue to Step 4 — the framework app can still be scaffolded/extended against any existing deployment whose resources are already set up out-of-band.
3. Bail out of the whole flow.

#### 2. Deployment not reachable (connection error / 404)

The base URL did not resolve. Tell the user plainly and offer:

1. Re-enter the CE base URL (typo case).
2. Skip import and continue to Step 4.
3. Bail out.

**Do NOT** auto-create anything. If the user needs a fresh deployment, point them at the platform provisioning flow — the template import is a bootstrap operation on an existing CE server.

#### 3. Import validation failure (400)

The server rejected the template. Surface the server's error message verbatim (it usually identifies the offending resource / form / field). Offer:

1. Re-run the planner to fix the template — the user can describe the issue and the planner can revise.
2. Skip import and continue to Step 4 with the already-emitted `template.json` as a local artifact.
3. Bail out.

## What Step 3 hands to Step 4

On successful import, Step 4 receives:

- `baseUrl` (as resolved by the Preflight, on both branches).
- Path to `template.md` on disk (planner wrote it; still there — architectural-intent seed for the framework path).
- Path to `template.json` on disk (planner wrote it; still there — structured companion).
- A flag: "import succeeded".
- For modify-existing: the list of newly-imported resource names.

On skipped import (user declined or error branch chose skip), Step 4 receives the same values but with the flag set to "import skipped".

On "bail out", the flow stops. Partial state: the planner's `template.md` + `template.json` pair still exists on disk (by design — they are artifacts the user can use later). Nothing has been written to the CE deployment on the server.
