## Overview

Submissions are the backbone of any Form.io integration: they hold the data end users enter into a form. Reading and writing them is **application** work, done at runtime with the end user's own token — a list view, a detail page, a dashboard, a submit handler. This document is the reference for building that code; see "REST-first" below for why it is not a set of calls to make while configuring a project. It documents runtime-scope CRUD for submissions — creating new submissions, validating payloads without saving, listing and filtering existing submissions, fetching a single submission by ID, checking for existence by field value, updating (full and partial via JSON Patch), reading revisions, and deleting. Form and action definitions are covered by `project-forms.md` and `project-actions.md`.

Submission revisions require the parent form to have `submissionRevisions: "true"` enabled — a one-time form update performed via the Forms API before revision history will be recorded.

## Root URL

All endpoints below are rooted at `{baseUrl}` — the CE server base URL. There is no `{projectUrl}`: the CE server is single-project, and the middleware proxies `/v1/*` to it.

## Authentication

End-user calls carry a user JWT in the `x-jwt-token` header, minted by the login endpoints (returned in the `x-jwt-token` response header). Through the middleware, the gateway injects `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` and the middleware proxies with a tenant JWT — see [`our-auth.md`](./our-auth.md) and [`middleware-v1.md`](./middleware-v1.md).

## REST-first

These are **runtime** endpoints — no MCP server exists in this deployment, and there is no build-time tool for them. This document is a specification for the code you write, not a set of calls to make now.

## Endpoints

### POST {baseUrl}/:formPath/submission

Create a new submission for the form identified by `:formPath` (the form's URL alias; the ID also works in the same segment). The server runs validation and any `before`/`after` actions attached to the form.

Request body (JSON) — the shape is `{ "data": { ...componentKey: value } }`. Nested and multi-row components (containers, data grids, edit grids) are represented as nested objects or arrays keyed by the component `key`.

```json
{
  "data": {
    "firstName": "Ashlynn",
    "lastName": "Flatley",
    "email": "Lucie94@yahoo.com",
    "numberOfPets": 406,
    "birthday": "08/10/2000",
    "emailNotify": true,
    "topicsOfInterest": {
      "artsCrafts": false,
      "business": false,
      "finance": true,
      "politics": true,
      "sports": false,
      "technology": false
    },
    "children": [
      { "firstName": "Reggie", "lastName": "Fritsch", "birthday": "02/03/2010" },
      { "firstName": "Sheila", "lastName": "Walker", "birthday": "03/15/2014" }
    ]
  }
}
```

Response: the created submission document with server-assigned `_id`, `form`, `owner`, `roles`, `access`, `metadata`, `created`, and `modified`.

Errors: `400` `ValidationError` when required fields are missing or component validators fail (see the `POST .../submission` validate pattern below); `401` if the JWT is missing/expired; `403` if the caller lacks `create_own` / `create_all` permission on the form's `submissionAccess`.

Example:

```bash
curl -X POST -H "x-jwt-token: $USER_JWT" -H "Content-Type: application/json" \
  -d '{"data":{"firstName":"Ashlynn","lastName":"Flatley","email":"Lucie94@yahoo.com"}}' \
  "{baseUrl}/onboarding-872/submission"
```

### POST {baseUrl}/:formPath/submission (validate only)

Validate a submission payload without persisting it. Form.io exposes validation through the same endpoint shape — send the submission with the query/header convention your client library uses to request dry-run validation, or simply inspect the `400 ValidationError` response to surface form-level errors to the UI.

Request body: identical shape to the create endpoint.

Response when valid: same as create.

Response when invalid (`400`):

```json
{
  "name": "ValidationError",
  "details": [
    {
      "message": "First Name is required",
      "level": "error",
      "path": ["firstName"],
      "context": {
        "validator": "required",
        "key": "firstName",
        "label": "First Name",
        "path": "firstName"
      }
    }
  ]
}
```

Errors: `400` with `name: "ValidationError"` and a `details[]` array of per-component failures; `401`/`403` as above.

### GET {baseUrl}/:formPath/submission

List submissions for the form. Supports Form.io's standard list controls and `data.*` filters.

| Query parameter | Type | Description |
| --- | --- | --- |
| `data.<key>` | string | Filter by submission data field (e.g., `data.email=foo@bar.com`). Supports `__regex`, `__gt`, `__lt`, `__in`, etc. |
| `limit`, `skip`, `sort` | — | Standard Form.io pagination/sort controls. |
| `select` | string | Comma-separated projection of top-level fields to include. |

Response: JSON array of submission documents. When the form's `submissionAccess` restricts callers to their own data, the server transparently filters the list to submissions the caller owns.

Errors: `401` missing JWT; `403` no read access to the form's submissions.

Example:

```bash
curl -H "x-jwt-token: $USER_JWT" \
  "{baseUrl}/onboarding-872/submission?limit=25&sort=-created"
```

### GET {baseUrl}/:formPath/submission/:submissionId

Retrieve a single submission by ID.

Response: full submission document (`_id`, `form`, `owner`, `data`, `roles`, `access`, `metadata`, `created`, `modified`, `externalIds`).

Errors: `404` if not found or the caller lacks access; `401`/`403` otherwise.

Example:

```bash
curl -H "x-jwt-token: $USER_JWT" \
  "{baseUrl}/onboarding-872/submission/69dd37ba040fa2cea2579ee2"
```

### GET {baseUrl}/:formPath/exists

Check whether a submission matching the query exists without returning its full body. Useful for uniqueness checks (e.g., "has anyone with this email already submitted?").

| Query parameter | Type | Description |
| --- | --- | --- |
| `data.<key>` | string | Field match predicate, same semantics as `GET .../submission`. At least one is required. |

Response when a match is found:

```json
{ "_id": "69dd37ba040fa2cea2579ee2" }
```

Response when no match: `404`.

Example:

```bash
curl -H "x-jwt-token: $USER_JWT" \
  "{baseUrl}/onboarding-872/exists?data.email=Lucie94@yahoo.com"
```

### PUT {baseUrl}/:formPath/submission/:submissionId

Full replace of a submission. The body SHOULD include `_id` and `form`; any field omitted from the body is treated as reset per Form.io's replace semantics. For single-field edits prefer the `PATCH` endpoint below.

Request body: a full submission document (at minimum `_id`, `form`, `data`).

Response: the updated submission document. When submission revisions are enabled, a new revision entry is appended, retrievable via `?submissionRevision=` (see `form-revisions.md`).

Errors: `400` validation errors; `404` submission not found; `401`/`403` as above.

### GET {baseUrl}/:formPath/submission/:submissionId?submissionRevision=:revisionId

Retrieve a single historical revision of a submission by its revision `_id`. This is the only revision-read mechanism on the CE server — there is no `/v` list endpoint (see `form-revisions.md`).

Response: the submission document as it existed at that revision, including `metadata` captured at the time.

Errors: `404` if the revision does not exist.

### PATCH {baseUrl}/:formPath/submission/:submissionId

Apply a JSON Patch (RFC 6902) to a submission. Ideal for partial updates without round-tripping the full document.

Request body (JSON array of patch operations):

```json
[
  { "op": "replace", "path": "/data/firstName", "value": "James" },
  { "op": "remove", "path": "/data/lastName" },
  { "op": "add", "path": "/data/lastName", "value": "Thompson" }
]
```

Response: the updated submission document.

Errors: `400` for invalid patch operations or validation failures after the patch is applied; `404` if the submission does not exist; `401`/`403` as above.

Example:

```bash
curl -X PATCH -H "x-jwt-token: $USER_JWT" -H "Content-Type: application/json" \
  -d '[{"op":"replace","path":"/data/firstName","value":"James"}]' \
  "{baseUrl}/onboarding-872/submission/69dd37ba040fa2cea2579ee2"
```

### DELETE {baseUrl}/:formPath/submission/:submissionId

Delete a submission. Hard-deletes the document unless the form configures soft-delete behavior.

Response: empty object `{}` on success.

Errors: `404` if not found; `401`/`403` as above.

Example:

```bash
curl -X DELETE -H "x-jwt-token: $USER_JWT" \
  "{baseUrl}/onboarding-872/submission/69dd37ba040fa2cea2579ee2"
```

## Related Skills

- [project-forms](./project-forms.md) — form definitions these submissions target
- [form-revisions](./form-revisions.md) — `?submissionRevision=` historical fetch
- [runtime-access-control](./runtime-access-control.md) — `*_own` access patterns that filter `GET /submission` results
- [middleware-v1](./middleware-v1.md) — production surface with `x-request-id` submission versioning and `GET /v1/submission/bulk`
