# Access patterns — owner, role, tenant, and the two access arrays

How `alpha-form-resource-planner` maps access requirements onto Form.io constructs. Read this whenever the plan has any owner-, role-, or tenant-based access.

## Access patterns

| Pattern | Form.io construct |
| --- | --- |
| Owner-only ("my records") | Submission Access on the resource: `read_own`/`update_own`/`delete_own` for the authenticated role (plus `create_all` for administrators when admins create records on the user's behalf) |
| Role-based ("admins see all") | Project roles (`administrator`, `authenticated`, custom). Gate resource access with roles. Assign roles on signup with a Role Assignment action |
| Tenant-based ("strict customer isolation") — alpha primary | Owner-based tenancy: form `tags=[orgUuid]` + `*_own` submission ACLs (tenant-admin role) + `{basePath}-{orgUuid}` path scoping, applied at runtime by the middleware from `x-api-gw-organization-uuid`. `mdm-*` resources are exempt (CDC-managed shared reference data). See `../_shared/stack.md` → Tenancy |

There is **no group-based access pattern in this stack**: the CE fork registers no Group Assignment action (`../_shared/stack.md` → Absent). Do not plan join-resource access actions, field-based `submissionAccess` blocks on selects, or hidden calculated "mirror" fields — none of them have a runtime behind them. "My team's records" is modeled as owner-based access on records the team members create, optionally layered with roles; tenant isolation is owner-based tenancy, not group membership.

## Two different access arrays (don't conflate)

Every resource and form carries two access arrays. Keep them separate in your plan:

- **`access`** — who can _load the form/resource definition itself_ (the metadata, component tree). Default for every resource: `read_all` granted to **all three base roles** (`administrator`, `anonymous`, `authenticated`). The form definition is public metadata — locking it down here is rarely what the user wants.
- **`submissionAccess`** — who can _create/read/update/delete submissions_ (the actual data rows). This is where the real access-control story lives: `create_all`/`read_all`/... for administrators, `read_own`/`update_own` for owner-level access, and so on.

When the user describes access ("reps only see their own deals", "admins see everything"), they almost always mean `submissionAccess`. Say so explicitly in the output. Leave the `access` default wide-open unless the plan specifically needs a resource whose definition is not world-readable.

## Common `submissionAccess` shapes

- **Admin-only resource (joins, system records):** `create_all`/`read_all`/`update_all`/`delete_all` for `administrator`.
- **Owner-level (user-owned records):** the admin four above, plus `read_own`/`update_own` for `authenticated` (add `delete_own` when users may delete their own rows; keep `delete_all` admin-only when an audit obligation applies).
- **Public submit, admin read (feedback, contact us):** `create_own` for `anonymous`, admin `read_all`/`update_all`/`delete_all`.

Decide `delete` deliberately: owner-`delete_own` is right for a personal task list, usually wrong for a customer record with an audit obligation — in which case leave deletion to an administrator. Whatever you choose, the Access Matrix's `delete` column must say the same thing as the resource's `submissionAccess`.

## Silent failure modes to check

- **Missing `create_own`.** The plan says "users create their own records" but the resource's `submissionAccess` only grants admin create — every user POST returns `Unauthorized` while reads work. Nothing fails loudly on the way there: the import succeeds, the front-end builds, and the defect surfaces the first time a human clicks "New".
- **Roles written directly.** A plan that "assigns staff roles via the portal/API" by writing the submission `roles` array is a dead end — the server strips `roles` from POST/PUT/PATCH bodies. Use the `role` selectboxes + one conditional Role Assignment per persona pattern (see `template-json.md` → "Multi-role user systems").
- **`access` vs `submissionAccess` swapped.** Locking `access` down (so the form definition is hidden) instead of `submissionAccess` (the data) leaves the data wide open while breaking the UI.

Call out the access model in the Phase A map and emit the matching `submissionAccess` arrays in Phase B. `template-md.md` → "Token → `template.json` mapping" gives the per-cell mapping.

See `template-json.md` → "`submissionAccess` — the access-control story" for the exact arrays, and [`../../alpha-form-api/references/runtime-access-control.md`](../../alpha-form-api/references/runtime-access-control.md) for the runtime description.
