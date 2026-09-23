## Overview

This skill documents the runtime access-control patterns that exist in the alpha stack:

- **Own-access patterns** — a form whose `submissionAccess` is configured so each end user can only read and modify submissions where they are the `owner`. The same `GET /:formPath/submission` endpoint transparently returns different results per caller.
- **Org scoping (middleware)** — the middleware enforces tenant isolation on top of CE: forms carry `tags=[orgUuid]`, form paths are org-scoped (`{basePath}-{orgUuid}`), and `*_own` ACLs restrict submissions to their owner. `mdm-*` resources are exempt (CDC-managed shared reference data).

There is **no group-permission mechanism** in this deployment: no Group Assignment action, no per-submission `access[].resources` stamping from a group action (the `group` action type does not exist in the CE fork — the only 6 action types are `save, email, login, resetpass, role, webhook`). Multi-tenancy is done with `*_own` ACLs + org tags + path scoping, not groups.

All endpoints below are regular runtime Form/Submission/Action endpoints; the access behavior is produced by how the forms and actions are configured, not by special URLs. For the form and action definitions themselves see `project-forms.md` and `project-actions.md`.

## Root URL

All endpoints below are rooted at `{baseUrl}` — the CE server base URL. There is no `{projectUrl}`: the CE server is single-project, and the middleware proxies `/v1/*` to it.

## Authentication

End-user calls carry a user JWT in the `x-jwt-token` header, minted by the login endpoints (returned in the `x-jwt-token` response header). Through the middleware, the gateway injects `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` and the middleware proxies with a tenant JWT — see [`our-auth.md`](./our-auth.md) and [`middleware-v1.md`](./middleware-v1.md).

## REST-first

These are **runtime** endpoints — no MCP server exists in this deployment, and there is no build-time tool for them. Configure permissions through the REST form/role/action endpoints; do not exercise them by making requests as an end user.

## Endpoints

### POST {baseUrl}/form

Create a form whose `submissionAccess` is configured so each caller only sees their own submissions. The key pattern is `access: []` combined with `submissionAccess` entries that grant `create_own`/`read_own`/`update_own`/`delete_own` rather than `*_all`.

Request body (JSON):

```json
{
  "title": "Support",
  "display": "form",
  "type": "form",
  "name": "support",
  "path": "support",
  "components": [
    { "label": "First Name", "type": "textfield", "key": "firstName" },
    { "label": "Last Name", "type": "textfield", "key": "lastName" },
    { "label": "Email", "type": "email", "key": "email" },
    { "label": "Message", "type": "message", "key": "message" },
    { "type": "button", "label": "Submit", "key": "submit", "action": "submit" }
  ],
  "access": [],
  "submissionAccess": []
}
```

Response: the created form document with server-assigned `_id`, default access entries, and the `submissionAccess` you supplied.

Errors: `400` for duplicate `name`/`path` or invalid components; `401`/`403` if the caller lacks form-create permission.

### POST {baseUrl}/:supportFormPath/submission

Create a submission as Employee 1. The server records the caller's user ID in the submission's `owner` field; this is what downstream "own" filters key on.

Request body:

```json
{
  "data": {
    "firstName": "Thora",
    "lastName": "Hills",
    "email": "employee1@example.com",
    "message": "This is a test"
  }
}
```

Response: submission document with `owner` set to the calling user's `_id`.

Errors: `401`/`403` if the caller cannot create submissions on this form.

### POST {baseUrl}/:supportFormPath/submission

Create a submission as Employee 2. Identical shape to the call above but with a different JWT; the server stamps the new caller as `owner`.

```json
{
  "data": {
    "firstName": "Cory",
    "lastName": "Hand",
    "email": "employee2@example.com",
    "message": "This is a test"
  }
}
```

Response: submission owned by Employee 2.

### GET {baseUrl}/:supportFormPath/submission

List submissions as Employee 1. Because the form grants `read_own` only, the server returns exclusively submissions whose `owner` matches Employee 1's user ID — Employee 2's submissions are silently excluded from the array.

Response: JSON array of submissions owned by the caller.

Errors: `401` missing JWT; `403` if the role lacks even `read_own`.

### GET {baseUrl}/:supportFormPath/submission

List submissions as Employee 2. Same endpoint, different JWT — returns only Employee 2's submissions. No client-side filtering is required; the scoping is enforced server-side.

## Org scoping via middleware

When consumers go through the middleware, tenant isolation layers on top of the CE `*_own` model:

- Forms are tagged `tags=[orgUuid]`; `formVisibleToOrganization()` hides other orgs' forms.
- Form paths are org-scoped (`{basePath}-{orgUuid}`) — two orgs can have the same logical form without collision.
- `mdm-*` forms (`mdm-gender`, …) are exempt: CDC-managed shared reference data, `sharedAccess` `read_all` for everyone.
- `PROTECTED_FORMS = ['structure', 'admin', 'user', 'mdm-gender']` are never tenant-visible.

See [`middleware-v1.md`](./middleware-v1.md) for the full surface.

## Related Skills

- [runtime-submissions](./runtime-submissions.md) — the CRUD endpoints these access patterns filter
- [project-forms](./project-forms.md) — creating forms and resources with the `access` / `submissionAccess` arrays used above
- [project-actions](./project-actions.md) — the `role` and `login` actions that produce role membership
- [project-roles](./project-roles.md) — defining the roles referenced by `*_own` access entries
