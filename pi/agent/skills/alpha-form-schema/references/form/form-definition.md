# Form Definition Reference

Top-level form properties, settings, and access control. Load this file when working with form metadata — creating/updating a form, configuring display mode, setting permissions, or interpreting the envelope around `components`.

## Form object

The top-level object representing a form or resource. Only `components` is required.

| Property | Type | Required | Description |
| --- | --- | --- | --- |
| `_id` | `string` | No | MongoDB ObjectId. Assigned by the server. |
| `_vid` | `number` | No | Version ID for form revisions. |
| `title` | `string` | No | Human-readable form title (e.g., "User Registration"). |
| `name` | `string` | No | Machine name used for API references (e.g., "userRegister"). |
| `path` | `string` | No | URL path segment for the form (e.g., "user/register"). |
| `type` | `FormType` | No | Either `"form"` or `"resource"`. Resources are reusable data models; forms collect submissions. |
| `display` | `FormDisplay` | No | Rendering mode: `"form"` (single page), `"wizard"` (multi-step), or `"pdf"` (schema value only — no PDF support in this deployment). |
| `action` | `string` | No | URL to submit the form to. Defaults to the Form.io API. |
| `tags` | `string[]` | No | Arbitrary tags for categorization and filtering. Also the tenant visibility scope: forms carry `tags=[orgUuid]` marking tenant ownership (see `../../_shared/stack.md`). |
| `access` | `Access[]` | No | Form-level access permissions (who can read/write the form definition). |
| `submissionAccess` | `Access[]` | No | Submission-level access permissions (who can create/read/update/delete submissions). |
| `fieldMatchAccess` | `object` | No | Field-level access control rules. |
| `owner` | `string` | No | Submission ID of the form owner. |
| `machineName` | `string` | No | Globally unique machine name, **server-enforced** by the `machineName` plugin: `String`, `__readonly`, auto-set on save, unique per collection (index filtered to `deleted: null`). The exportable stable name — template import/export key forms/roles by it, and middleware tenant form lookup resolves by `path` + `machineName`. |
| `components` | `Component[]` | **Yes** | Array of form components defining the form's fields and layout. |
| `settings` | `FormSettings` | No | Form-level display and behavior settings. |
| `properties` | `Record<string, string>` | No | Custom key-value properties attached to the form. |
| `revisions` | `string` | No | Revision mode: `"current"`, `"original"`, or `""` — schema value only; this fork has no SaaS-style revision modes (CE fetches revisions via `?formRevision=` / `?submissionRevision=` query params only, see `alpha-form-api` → `../../../alpha-form-api/references/form-revisions.md`). |
| `submissionRevisions` | `string` | No | Whether submission revisions are enabled: `"true"` or `""`. |
| `controller` | `string` | No | Custom controller logic (server-side JavaScript). |
| `builder` | `boolean` | No | Whether to show this form in the form builder. |
| `page` | `number` | No | Current wizard page index. |
| `created` | `string` | No | ISO date when the form was created. |
| `modified` | `string` | No | ISO date when the form was last modified. |
| `deleted` | `string` | No | ISO date when the form was soft-deleted (null if active). |

## FormType

- `"form"` — A standard form that collects submissions.
- `"resource"` — A reusable data model (like a database table) that other forms can reference via `select` components with `dataSrc: "resource"`.

## FormDisplay

- `"form"` — Renders all components on a single page.
- `"wizard"` — Multi-step form with navigation between pages. Each top-level `panel` component becomes a step.
- `"pdf"` — Display value exists in the schema but is **not usable in this deployment**: the alpha CE fork has no hosted PDF server, so a PDF form cannot be built end to end. (See `../../_shared/stack.md` — "Absent".)

## FormSettings

| Property                 | Type      | Description                                               |
| ------------------------ | --------- | --------------------------------------------------------- |
| `collection`             | `string`  | Custom MongoDB collection name for submissions.           |
| `condensedMode`          | `boolean` | Render in condensed/compact mode.                         |
| `disableAutocomplete`    | `boolean` | Disable browser autocomplete on all fields.               |
| `fontSize`               | `number`  | Base font size for rendering (PDF-rendering use — no PDF support in this deployment).  |
| `hideTitle`              | `boolean` | Hide the form title when rendered.                        |
| `layout`                 | `string`  | Layout template name.                                     |
| `margins`                | `string`  | Page margins for rendering (PDF-rendering use — no PDF support in this deployment).  |
| `showCheckboxBackground` | `boolean` | Show background color on checkbox components.             |
| `theme`                  | `string`  | CSS theme name to apply.                                  |
| `viewAsHtml`             | `boolean` | Render submissions as static HTML instead of form fields. |
| `viewer`                 | `string`  | Viewer type for rendering.                                |
| `wizardHeaderType`       | `string`  | Wizard header style (e.g., breadcrumb).                   |
| `pdf`                    | `object`  | PDF source configuration: `{ src: string, id: string }` (schema-only — no PDF support in this deployment).  |

## Access

Each entry in `access` or `submissionAccess` is one role-to-permission mapping.

| Property | Type | Description |
| --- | --- | --- |
| `type` | `string` | Access type: `"read_all"`, `"create_own"`, `"create_all"`, `"update_own"`, `"update_all"`, `"delete_own"`, `"delete_all"`, `"self"`, `"team_read"`, `"team_write"`, `"team_admin"`. |
| `roles` | `string[]` | Role IDs that have this access type. |

**Access shape — names in templates, IDs on read.** On read from CE, `roles` entries are role **ObjectIds**. In template import/export documents (`default-template.json` shape) they are role **names** (`"anonymous"`, `"administrator"`) — e.g. `access: [{ type: "read_all", roles: ["anonymous"] }]`, `submissionAccess: [{ type: "create_own", roles: ["anonymous"] }]`. Template import resolves role machineName → ObjectId; `bootstrapNewRoleAccess` auto-grants `read_all` on newly created roles.

Form-level `access` governs who can see/modify the form definition itself. Submission-level `submissionAccess` governs who can create, read, update, or delete submissions against the form. In multi-tenant mode the middleware **overwrites** both arrays with tenant ACLs on form create (`assignPermissionsToForm` / `makeTenantAccess`), so supplied grants may not survive a middleware save.

**Never silently widen access.** When authoring a form definition on the user's behalf, any `access` or `submissionAccess` entry that makes the form MORE permissive than the tenant's defaults must be surfaced to the user for explicit confirmation before the form is saved. This applies to EVERY role and EVERY permission type — not just Anonymous. Examples that all require confirmation: Anonymous `create_all`/`create_own` (unauthenticated visitors can submit — a natural fit for public forms like "Contact Us", but confirm anyway); Authenticated `create_own`/`create_all` (any logged-in user can submit); Authenticated or Anonymous `read_own`/`read_all` (submitters — or everyone — can read submissions back); any `update_*`/`delete_*` grant. State plainly what is being granted and to whom (e.g., "This will let anyone on the internet submit this form without logging in — is that what you want?", "Any logged-in user will be able to read every submission on this form"). Omitting these arrays entirely (inheriting tenant defaults) needs no confirmation.

## Template envelope

Template import/export documents (`default-template.json`, imported via CE `POST /import`) have this envelope — object maps keyed by **machineName**, roles/forms referenced by name:

```json
{
  "title": "...",
  "name": "...",
  "version": "...",
  "description": "...",
  "roles": { "administrator": { ... } },
  "resources": { ... },
  "forms": { "userLogin": { ... } },
  "actions": { ... },
  "access": { ... }
}
```

See `alpha-form-resource-planner` for the full authoring guidance.
