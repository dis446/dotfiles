## Overview

The Forms API covers everything a project admin does with form and resource definitions: listing, filtering by type/name/tag, retrieving by ID or alias, creating new forms, updating existing forms, and exporting form data as JSON or CSV. It does NOT cover form submissions (see `runtime-submissions.md`) or form revisions (see `form-revisions.md`).

## Root URL

All endpoints below are rooted at `{baseUrl}` — the CE server base URL. There is no `{projectUrl}`: the CE server is single-project, and the middleware proxies `/v1/*` to it.

## Authentication

Every request MUST include an `x-token` header holding an API key from the `API_KEYS` env var (admin bypass), or a user JWT in `x-jwt-token`. Login endpoints (`/user/login`, `/admin/login`) return the JWT in the `x-jwt-token` response header. See [`our-auth.md`](./our-auth.md). When calling through the middleware, `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` replace both (see [`middleware-v1.md`](./middleware-v1.md)).

## REST-first

No MCP server exists in this deployment — use these HTTP endpoints directly. REST is the only surface.

## Endpoints

### GET {baseUrl}/form

List forms and resources in the project, optionally filtered by type, name, or tag.

| Query parameter | Type | Description |
| --- | --- | --- |
| `type` | string | `form` to return only forms, `resource` to return only resources. Omit to return both. |
| `name__regex` | string | MongoDB-style regex filter (e.g., `/^user/i` for names starting with "user", case-insensitive). |
| `tag` | string | Comma-separated list of tags — forms matching any tag are returned. |
| `select` | string | Comma-separated projection of fields to include (e.g., `title,name,type,path`). Reduces payload. |
| `limit`, `skip`, `sort` | — | Standard Form.io list controls. See the `alpha-form-api` README for cross-cutting pagination/sorting notes. |

Response: JSON array of form documents. Each document contains `_id`, `title`, `name`, `path`, `type`, and whatever additional fields `select` requested.

Errors: `401` if the JWT is missing/expired; `403` if the caller lacks read access to the project's forms.

Example:

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/form?type=form&select=title,name,path,type"
```

### GET {baseUrl}/form/:idOrName

Retrieve a single form by its MongoDB ID or machine name. Form.io accepts either in the same path segment.

Response: the full form document (components, settings, access, etc.). Use `form-revisions.md` if you need a specific historical revision.

Errors: `404` if no form matches; `401`/`403` as above.

Example:

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/form/user-registration"
```

### GET {baseUrl}/:formPath

Retrieve a form by its URL alias (path). Useful when the caller has the path but not the ID.

Response: same shape as the ID-based GET.

Errors: `404` if no form has that path.

### POST {baseUrl}/form

Create a new form or resource. The request body is a form definition.

Request body (JSON):

```json
{
  "title": "Example Form",
  "display": "form",
  "type": "form",
  "name": "exampleForm",
  "path": "example-form",
  "tags": ["example"],
  "components": [
    {
      "type": "textfield",
      "label": "First Name",
      "key": "firstName",
      "validate": { "required": true }
    },
    { "type": "email", "label": "Email", "key": "email", "validate": { "required": true } }
  ]
}
```

Required fields: `title`, `type` (`form` or `resource`), `name`, `path`, `components`. Optional fields: `tags`, `display`, `settings`, `access`, `submissionAccess`. See the `alpha-form-schema` skill for the full component schema.

Response: the created form document with server-assigned `_id`, `machineName`, `created`, and `modified` fields.

Errors: `400` for validation errors (duplicate `name`/`path`, missing required fields, invalid component definitions); `401`/`403` as above.

Example:

```bash
curl -X POST -H "x-token: $API_KEY" -H "Content-Type: application/json" \
  -d @form-definition.json \
  "{baseUrl}/form"
```

### PUT {baseUrl}/form/:idOrName

Replace an existing form definition. The body SHOULD include the `_id` of the form being updated (Form.io treats this as a full document replacement; omitted fields are reset to defaults).

Request body: same shape as the create body, plus `_id`. Include every field you want to preserve.

Response: the updated form document.

Errors: `400` for validation errors; `404` if the form does not exist; `409` if `_vid` version checks fail (when revisions are enabled).

Note: prefer `PATCH` (via `runtime-submissions.md` patterns extended to forms) if partial updates are needed — this endpoint is a full replacement.

### PUT {baseUrl}/:formPath

Alias-based update. Equivalent to the ID-based PUT but addressed by `path`. Useful when the caller has the alias but not the ID.

### GET {baseUrl}/form/:idOrName/export

Export all submission data for a form as JSON (default) or CSV.

| Query parameter | Type   | Description                |
| --------------- | ------ | -------------------------- |
| `format`        | string | `json` (default) or `csv`. |

Response: streamed file. `Content-Type` is `application/json` or `text/csv`. For large forms, expect streaming — consume via a streaming HTTP client rather than buffering in memory.

Errors: `401`/`403` for insufficient access; `404` if the form does not exist.

Example (CSV):

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/form/example-form/export?format=csv" \
  -o submissions.csv
```

## Related Skills

- [form-revisions](./form-revisions.md) — CE form revisions (`?formRevision=` fetch)
- [project-actions](./project-actions.md) — form actions (email, webhook, etc.) attached to a form
- [runtime-submissions](./runtime-submissions.md) — submitting and reading submission data for these forms
- [project-roles](./project-roles.md) — configuring form-level access via project roles
