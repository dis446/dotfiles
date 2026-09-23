## Overview

The middleware (`{baseUrl}/v1`) is the **production surface** alpha consumers call. It proxies to the CE server as the tenant admin and enforces multi-tenancy. All endpoints live under the global `/v1` prefix. For the raw CE surface (admin/server ops), see the other references in this skill.

## Headers

| Header | Required | Meaning |
| --- | --- | --- |
| `x-api-gw-organization-uuid` | yes (except `/auth/hello`) | Org (tenant) UUID, injected by Keycloak at the gateway. |
| `x-api-gw-user-uuid` | yes | End-user UUID, injected by the gateway. |
| `x-request-id` | required for `GET /submission/bulk` | Correlation id; also the versioning key for submission history. |

The middleware maps the org → tenant admin, logs into CE (`POST /admin/login`), and proxies with the tenant JWT (Redis-cached). Callers never handle the tenant JWT.

## Tenancy model

- Form `tags=[orgUuid]` marks tenant ownership; `formVisibleToOrganization()` guards every controller.
- `*_own` submission ACLs scope reads/writes to the caller.
- Org-scoped form paths: `{basePath}-{orgUuid}`.
- `mdm-*` forms are exempt (CDC-managed shared reference data).
- `PROTECTED_FORMS = ['structure', 'admin', 'user', 'mdm-gender']` are not tenant-visible.

## Endpoints

### Forms

| Method + Path | Description |
| --- | --- |
| `GET /v1/form` | List forms visible to the org. |
| `GET /v1/form/:formId` | Get one form. |
| `POST /v1/form` | Create a form. |
| `PUT /v1/form/:formId` | Update a form. |
| `GET /v1/form/:formId/submission` | List submissions (org-scoped). |
| `GET /v1/form/:formId/submission/:submissionId` | Get a submission. |
| `POST /v1/form/:formId/submission` | Create a submission. |
| `POST /v1/form/:formId/submission/admin-edit` | Admin edit of a submission. |
| `POST /v1/form/:formId/return` | State-machine return submission. |

### Form path aliases (root controller)

`GET/POST /v1/:formPath/submission[/:submissionId]`, `POST /v1/:formPath`, `POST /v1/:formPath/admin-edit`, `POST /v1/:formPath/return` — same operations addressed by the form's path alias instead of `:formId`.

### Submissions

| Method + Path | Description |
| --- | --- |
| `GET /v1/submission/bulk` | Cross-form, versioned fetch by `_id__in` / `path__in`; requires `x-request-id`. Returns latest-by-request submissions (middleware submission versioning — each write with a new `x-request-id` creates a `submission_revisions` entry; the bulk read resolves the latest). |

### Roles

| Method + Path | Description |
| --- | --- |
| `GET /v1/role` | List roles. |
| `GET /v1/role/:roleId` | Get one role. |

**Read-only.** Role create/update/delete must go to the CE server directly (`POST/PUT/DELETE {baseUrl}/role[/:roleId]` with `x-token`) or via `default-template.json` import. The middleware deliberately does not expose role mutation.

### Paths

| Method + Path | Description |
| --- | --- |
| `GET /v1/path` | Path list. |
| `POST /v1/path/deref` | Dereference a path to a form. |

### MDM (master data)

| Method + Path | Description |
| --- | --- |
| `PUT /v1/mdm/:resource/submission/by-source-id/:sourceId` | CDC upsert / soft-delete of an `mdm-*` submission by its `source_id`. `mdm-*` forms are shared reference data, not tenant resources. |

### Auth

| Method + Path | Description |
| --- | --- |
| `POST /v1/auth/registerTenant` | Provision a tenant (admin login form + login action + resource setup). |
| `GET /v1/auth/hello` | Unauthenticated liveness of the middleware. |

### App

| Method + Path | Description |
| --- | --- |
| `GET /v1/` | Service info. |

## Related Skills

- [our-auth](./our-auth.md) — headers and token flow
- [runtime-submissions](./runtime-submissions.md) — CE submission CRUD the middleware proxies
- [project-roles](./project-roles.md) — role CRUD (middleware `/v1/role` is read-only; use CE for writes)
