## Overview

The Project Authentication API covers everything a project admin does to manage administrative credentials for a Form.io project: inspecting the `admin` resource that backs admin accounts, creating/listing/retrieving/deleting project admin submissions, inspecting the admin login form and its actions, and exchanging admin credentials for a JWT via the admin login endpoint. These operations are for privileged users who configure the project; for regular end-user login flows, see `runtime-auth.md`.

## Root URL

All endpoints below are rooted at `{baseUrl}` — the CE server base URL. There is no `{projectUrl}`: the CE server is single-project, and the middleware proxies `/v1/*` to it.

## Authentication

Every request MUST include an `x-token` header holding an API key from the `API_KEYS` env var (admin bypass), or a user JWT in `x-jwt-token`. Login endpoints (`/user/login`, `/admin/login`) return the JWT in the `x-jwt-token` response header. See [`our-auth.md`](./our-auth.md). When calling through the middleware, `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` replace both (see [`middleware-v1.md`](./middleware-v1.md)).

## REST-first

No MCP server exists in this deployment — use these HTTP endpoints directly. REST is the only surface.

## Endpoints

### GET {baseUrl}/admin

Retrieve the `admin` resource definition — the Form.io resource that stores project admin records. Useful for discovering the admin submission schema (email/password fields, roles, access settings) before creating admins.

Response: the full resource document including `_id`, `title`, `name`, `path` (usually `admin`), `type` (`resource`), `components`, `access`, and `submissionAccess`. Response shape inferred from Form.io conventions and matches a standard resource payload.

Errors: `401` if the JWT is missing/expired; `403` if the caller lacks read access to project resources; `404` if the project has no admin resource.

Example:

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/admin"
```

### POST {baseUrl}/admin/submission

Create a new project admin. The body is a submission against the `admin` resource — the `data` object carries the admin's email and password.

Request body (JSON):

```json
{
  "data": {
    "email": "admin@example.com",
    "password": "CHANGEME"
  }
}
```

Required fields: `data.email`, `data.password`. Additional `data` fields can be included if the admin resource has been extended with custom components.

Response: the created submission document with server-assigned `_id`, the `form` reference (admin resource ID), `owner`, `roles` (including the Administrator role), `access`, `metadata`, `created`, and `modified`.

Errors: `400` for validation failures (duplicate email, weak password, missing required fields); `401`/`403` as above.

Example:

```bash
curl -X POST -H "x-token: $API_KEY" -H "Content-Type: application/json" \
  -d '{"data":{"email":"admin@example.com","password":"CHANGEME"}}' \
  "{baseUrl}/admin/submission"
```

### GET {baseUrl}/admin/submission

List all project admin submissions.

Response: JSON array of admin submission documents. Each entry includes `_id`, `form`, `owner`, `roles`, `access`, `metadata`, `data` (with the admin's email; password is never returned), `created`, and `modified`.

Errors: `401`/`403` as above.

Example:

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/admin/submission"
```

### GET {baseUrl}/admin/submission/:projectAdminId

Retrieve a single project admin submission by its ID.

| Path parameter   | Type   | Description                                         |
| ---------------- | ------ | --------------------------------------------------- |
| `projectAdminId` | string | The MongoDB `_id` of the admin submission to fetch. |

Response: the full admin submission document (same shape as list entries).

Errors: `404` if no admin with that ID exists; `401`/`403` as above.

Example:

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/admin/submission/69d6813b040fa2cea257285a"
```

### DELETE {baseUrl}/admin/submission/:projectAdminId

Delete a project admin by ID. Irreversible — the admin loses access immediately.

| Path parameter   | Type   | Description                                          |
| ---------------- | ------ | ---------------------------------------------------- |
| `projectAdminId` | string | The MongoDB `_id` of the admin submission to delete. |

Response: empty body with `200 OK` on success. Response shape inferred from Form.io conventions.

Errors: `404` if the admin does not exist; `401`/`403` as above.

Example:

```bash
curl -X DELETE -H "x-token: $API_KEY" \
  "{baseUrl}/admin/submission/69d6813b040fa2cea257285a"
```

### GET {baseUrl}/admin/login

Retrieve the admin login form definition. This is the form whose submission endpoint accepts admin credentials in exchange for a JWT.

Response: the admin login form document — `_id`, `title` ("Admin Login"), `name` (`adminLogin`), `path` (`admin/login`), `type` (`form`), `access`, `submissionAccess`, and `components` (typically `email` and `password` fields).

Errors: `401`/`403` as above; `404` if the admin login form has not been provisioned.

Example:

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/admin/login"
```

### GET {baseUrl}/admin/login/action

List the actions attached to the admin login form. Typically includes a `login` action that validates credentials against the `admin` resource and issues a JWT.

Response: JSON array of action documents. Each entry includes `_id`, `title`, `name` (`login`), `handler` (e.g., `["before"]`), `method` (e.g., `["create"]`), `priority`, and `settings` (with `resources`, `username`, `password`, `allowedAttempts`, `attemptWindow`, `lockWait`).

Errors: `401`/`403` as above.

Example:

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/admin/login/action"
```

### POST {baseUrl}/admin/login/submission

Submit admin credentials to the admin login form. On success, the response's `x-jwt-token` response header carries a JWT scoped to the admin user — this is the endpoint the middleware uses when it logs in as the tenant admin.

Request body (JSON):

```json
{
  "data": {
    "email": "admin@example.com",
    "password": "CHANGEME"
  }
}
```

Required fields: `data.email`, `data.password`.

Response: the authenticated admin submission document (same shape as `GET /admin/submission/:id`). The issued JWT is returned in the `x-jwt-token` response header, not the body.

Errors: `400` for missing credentials; `401` for invalid email/password; `429` if the login action's rate limit (`allowedAttempts`/`attemptWindow`/`lockWait`) has been tripped.

Example:

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"data":{"email":"admin@example.com","password":"CHANGEME"}}' \
  -D - \
  "{baseUrl}/admin/login/submission"
```

## Related Skills

- [project-roles](./project-roles.md) — roles assigned to admin submissions (e.g., Administrator)
- [project-forms](./project-forms.md) — managing the forms and resources that admin accounts can configure
- [project-actions](./project-actions.md) — inspecting and configuring login actions like the admin login action
