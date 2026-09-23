# SAVE — persist the form via `POST /v1/form`

This document is loaded by the parent `alpha-form-form-builder` skill during Step 3. It is **not** a standalone skill — no frontmatter, no independent trigger.

By this point Step 2 (SCHEMA) has produced the complete form JSON definition via `alpha-form-schema`. This step writes it into the alpha formio stack through the **middleware** (`/v1`, the production surface).

## The approval gate

Saving writes into the live deployment, so it sits behind an approval gate. Before calling `POST /v1/form`, show the user a short plain-language summary and get a yes:

- **Title** — the form's display title.
- **Path** — the form path it will live at (the middleware scopes the stored path with the org suffix internally; the unscoped path is what the user sees).
- **Type** — webform or wizard (from INTENT).
- **Target** — the middleware base URL (`{baseUrl}/v1`) and the tenant org UUID the form will be created under.
- A one-line component summary ("12 fields across 3 pages", "6 fields including a signature").
- **Access grants beyond defaults (call-out).** If the definition carries any `access` or `submissionAccess` entry more permissive than the tenant's defaults, the gate MUST name each grant in plain language and get an explicit yes on it — never bury a widened permission inside a general "save it?" approval. Note: in multi-tenant mode the middleware **overwrites** supplied `access`/`submissionAccess` with tenant ACLs (`assignPermissionsToForm` / `makeTenantAccess`), so widened grants may be overridden at save time; the call-out still matters when multi-tenancy is disabled or the grant is authored as part of a tenant template. A definition with no `access`/`submissionAccess` arrays inherits tenant defaults and needs no call-out.

A declined gate stops the flow — do not save, do not proceed to EMBED, leave nothing behind. Declining only the access grant is not a declined gate: strip the widened entries and re-present the summary.

## The call

On approval, `POST /v1/form` on the middleware with the authored definition as the body (FormDto: `type: 'form'|'resource'`, `display: 'form'|'wizard'`, `title`, `path`, `name`, `machineName`, `components`, `access`, `submissionAccess`, `tags`, `properties`), and the gateway identity headers:

```
x-api-gw-organization-uuid: <org-uuid>
x-api-gw-user-uuid: <user-uuid>
```

The middleware validates (`assertCanonicalConformance` when a `canonicalKey` is present), rejects `PROTECTED_FORMS` paths (`structure`, `admin`, `user`, `mdm-gender`), forces `tags=[org]`, scopes the stored path with the org suffix, and — in multi-tenant mode — replaces the access arrays with tenant ACLs.

Before the call, if there is any doubt the path is free, resolve it first (`GET /v1/form` or path lookup) — a hit means the path is taken; pick a new path with the user rather than overwriting.

## On success — confirm the saved form

Report back, always including the saved form path:

```
Saved ✓  "{title}" is live at {baseUrl}/v1/{formPath}
```

The unscoped form path is the handle everything downstream uses — it is what EMBED hands to `alpha-form-form`, and what the user shares, renders, or revisits. If INTENT captured `embedIntent: yes`, continue to Step 4 (EMBED); otherwise the flow ends here — remind the user they can embed later by asking to embed this form.

## Error branches

### Auth failure (401 / missing tenant identity)

The middleware authenticates from the gateway headers `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` (Keycloak at the gateway); it mints the tenant token itself (Redis-cached) — there is no manual token to set, no portal login. On an auth error:

1. Tell the user the gateway identity headers are missing or rejected.
2. Get the correct org + user UUIDs (or a CE admin `x-token` for admin/server operations) and retry the same call.

Do not attempt API keys or a browser login flow — neither is how this stack authenticates.

### Validation failure (400 / schema rejected)

The server rejected the definition. Quote the shortest decisive error line, route the fix back through `alpha-form-schema` (Step 2 owns the definition), and offer the user a choice: retry with the corrected definition, or bail. Never hand-patch the JSON outside the schema skill.

### Protected path rejected

`PROTECTED_FORMS` paths (`structure`, `admin`, `user`, `mdm-gender`) cannot be created through the middleware. Pick a different path with the user.

### Path already taken

Resolve the path first; on a hit, offer a new path rather than overwriting an existing form.
