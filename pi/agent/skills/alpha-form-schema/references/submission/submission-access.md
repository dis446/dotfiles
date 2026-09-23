# Submission Access Reference

`access` on a submission is a row-level access-control override stored on that one record. It grants permission on the submission to a set of **resource/user IDs** — not to roles. Use it to open a single submission to specific users (or groups of users) beyond whatever the form's `submissionAccess` already allows.

> **Important:** the submission-level `access` array is **not** role-based. Each entry maps a permission `type` to a list of `resources` (IDs). There is no `roles` key on a submission access entry — role-based grants live on the form definition's `submissionAccess` array (see `../form/form-definition.md`). The server silently ignores any entry that lacks a `resources` key.

## Access entry shape

| Property | Type | Required | Description |
| --- | --- | --- | --- |
| `type` | `string` | **Yes** | One of the AccessType values below. |
| `resources` | `string[]` | **Yes** | IDs granted this permission on the submission. Each ID is a user submission ID. An entry without `resources` is skipped. |

The `access` field on the Submission envelope is an array of these entries. Each entry maps one permission `type` to the set of IDs that get it.

## AccessType values

| Value    | Grants                          |
| -------- | ------------------------------- |
| `read`   | read                            |
| `create` | create                          |
| `update` | update                          |
| `delete` | delete                          |
| `write`  | read + create + update          |
| `admin`  | read + create + update + delete |

Each ID in `resources` is added to the submission's effective access set for the granted permission(s). A request gains access when the requesting user's own ID — or an ID the user is a member of — appears in that set. `read`, `create`, `update`, and `write` grants are explicitly flagged so they do **not** confer implicit admin (delete) rights on the record; only `admin` confers full delete.

## What an ID in `resources` resolves to

The IDs in `resources` are matched against the requester's identity set, which lets the same mechanism cover two distinct use cases:

### 1. Field-based resource access

Grants access based on a **Resource being selected in the submission** — the selected user's own submission ID is written into `resources`. Access follows the field value.

**Example:** A patient record form has a "Primary Physician" select component backed by the Physician resource. When a physician is chosen, that physician's user ID is added to the record's `access` with `type: "read"`, so that physician — and only that physician — can read the patient record. Reassign the field, and access moves with it.

> **No group-based grants in this fork.** Upstream also grants access through Group submission IDs (`resources` entries that are group memberships). The alpha CE fork has **no groups** — no Group resources, no Group Action, no group permissions (see `../../_shared/stack.md`) — so `resources` entries are always **user submission IDs**. The multi-user variant of field-based access is the same mechanism with the selected user ID, not a group ID.

## Layering with form-level submissionAccess

The form definition can carry its own `submissionAccess` array — a **role-based** rule that applies to every submission against that form (see `../form/form-definition.md`). The submission's own `access` array (this reference) is checked on top of that form-level rule:

- Form-level `submissionAccess` grants by **role** (e.g. "Authenticated users can read_own").
- Submission-level `access` grants by **resource/user ID** on a single record.

The two are additive: a request is allowed if either source grants it. This lets a form's default stay restrictive while individual records open themselves to specific users without editing the form definition.

**Separate from middleware tenant isolation.** Row-level submission `access` is CE access control on a single record. Tenant isolation in the alpha stack is a different layer: the middleware scopes by form `tags=[orgUuid]` + `*_own` ACLs + `{basePath}-{orgUuid}` path scoping (see `../../_shared/stack.md`). Neither replaces the other; both apply to a read through the middleware.

## Worked example

A patient record granting read access to the selected primary physician:

```json
{
  "_id": "5f8d0c4e9b1e8a0017a1b2c3",
  "owner": "5f8d0c4e9b1e8a0017a1aaaa",
  "access": [
    { "type": "read", "resources": ["6a188a52bb04c38a9102dff4"] },
    { "type": "write", "resources": ["6a188a52bb04c38a9102e001"] }
  ]
}
```

The `write` entry could represent a second physician selected on the record, or a manager the record is shared with — always a user submission ID.

## See also

- `../form/form-definition.md` for the form-level `access` and role-based `submissionAccess` arrays.
- The `alpha-form-api` skill's `runtime-access-control` reference for how the server resolves these entries on a request.
