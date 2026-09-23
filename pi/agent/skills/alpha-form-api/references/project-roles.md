## Overview

The Project Roles API lets a project admin manage the roles that govern access inside a single Form.io project. Roles are referenced by `access` and `submissionAccess` entries on forms, and they are assigned to user submissions (for example, to admin submissions or to authenticated end users). This skill covers listing, creating, and updating roles. Every project is seeded with built-in roles such as `Administrator`, `Authenticated`, and `Anonymous`.

## Root URL

All endpoints below are rooted at `{baseUrl}` — the CE server base URL. There is no `{projectUrl}`: the CE server is single-project, and the middleware proxies `/v1/*` to it. Note: the middleware exposes `/v1/role` as **read-only** (list + get); role writes go through CE directly.

## Authentication

Every request MUST include an `x-token` header holding an API key from the `API_KEYS` env var (admin bypass), or a user JWT in `x-jwt-token`. Login endpoints (`/user/login`, `/admin/login`) return the JWT in the `x-jwt-token` response header. See [`our-auth.md`](./our-auth.md). When calling through the middleware, `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` replace both (see [`middleware-v1.md`](./middleware-v1.md)).

## REST-first

No MCP server exists in this deployment — use these HTTP endpoints directly. REST is the only surface.

## Endpoints

### GET {baseUrl}/role

List every role defined in the project, including built-in roles (`Administrator`, `Authenticated`, `Anonymous`) and any custom roles the admin has created.

Response: JSON array of role documents. Each entry contains:

```json
{
  "_id": "69d65f4e040fa2cea2572254",
  "title": "Administrator",
  "description": "A role for Administrative Users.",
  "default": false,
  "admin": true,
  "project": "69d65f4e040fa2cea257224d",
  "machineName": "example:administrator",
  "created": "2026-04-08T13:59:42.647Z",
  "modified": "2026-04-08T13:59:42.650Z"
}
```

Errors: `401` if the JWT is missing/expired; `403` if the caller lacks read access to project roles.

Example:

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/role"
```

### POST {baseUrl}/role

Create a new role inside the project.

Request body (JSON):

```json
{
  "title": "Employee",
  "description": "A person who belongs to a company."
}
```

Required fields: `title`. Optional fields: `description`, `default` (boolean — when `true`, the role is assigned to every new authenticated user), `admin` (boolean — when `true`, holders bypass access checks; use sparingly).

Response: the created role document with server-assigned `_id`, `project`, `machineName`, `created`, and `modified` fields. `default` and `admin` default to `false` when omitted.

```json
{
  "title": "Employee",
  "description": "A person who belongs to a company.",
  "default": false,
  "admin": false,
  "_id": "69d68310040fa2cea2572945",
  "project": "69d65f4e040fa2cea257224d",
  "created": "2026-04-08T16:32:16.889Z",
  "modified": "2026-04-08T16:32:16.892Z",
  "machineName": "example:employee"
}
```

Errors: `400` for validation errors (missing `title`, duplicate `machineName`); `401`/`403` as above.

Example:

```bash
curl -X POST -H "x-token: $API_KEY" -H "Content-Type: application/json" \
  -d '{"title":"Employee","description":"A person who belongs to a company."}' \
  "{baseUrl}/role"
```

### PUT {baseUrl}/role/:roleId

Update an existing role. This is a full replacement — include every field you want to preserve.

| Path parameter | Type   | Description                              |
| -------------- | ------ | ---------------------------------------- |
| `roleId`       | string | The MongoDB `_id` of the role to update. |

Request body (JSON):

```json
{
  "title": "Employee",
  "description": "A person who belongs to a company."
}
```

Any field from the create body can be included. Changing `admin` or `default` has immediate effect on access checks for all existing users with this role.

Response: the updated role document with a refreshed `modified` timestamp.

Errors: `400` for validation errors; `404` if the role does not exist; `401`/`403` as above.

Example:

```bash
curl -X PUT -H "x-token: $API_KEY" -H "Content-Type: application/json" \
  -d '{"title":"Employee","description":"A person who belongs to a company."}' \
  "{baseUrl}/role/69d68310040fa2cea2572945"
```

## Related Skills

- [project-forms](./project-forms.md) — forms whose `access` and `submissionAccess` entries reference these roles
- [project-auth](./project-auth.md) — admin submissions that receive the `Administrator` role
- [project-actions](./project-actions.md) — actions (such as `role` and `login`) that assign roles to submissions
