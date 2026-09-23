---
name: alpha-form-schema
description: >-
  Form.io JSON schema reference: form/resource definitions and submission shapes (data, access, drafts, metadata) on the alpha stack. Use when constructing, editing, or interpreting Form.io JSON — components, wizards, validation, template envelopes. Not for: REST endpoints (see `alpha-form-api`); server-side actions (see `alpha-form-actions`); resource planning (see `alpha-form-resource-planner`); app builds (see `alpha-form-application`).


license: MIT
---

# Form.io JSON Schema

This skill describes the JSON schemas for the two Form.io document types whose shape is non-trivial — forms (and resources), and submissions. (The upstream project/tenant document domain is **cut**: the alpha fork has no SaaS projects, stages, tenants, or teams.) Action configs live in the `alpha-form-actions` skill; role objects are simple enough to use directly from the `alpha-form-api` skill. Use this skill to construct new JSON payloads, interpret existing ones, or modify them via direct REST (middleware `/v1`, or CE direct with `x-token`).

Detail is split across reference files under `references/<domain>/`. Read only the files you need for the task at hand — the overview below is usually enough to orient yourself; load a reference file when you need a specific property list.

## Preflight — direct REST, no MCP tools

This fork has **no MCP server** and no MCP tooling. All schema work happens over direct REST against the alpha formio stack. Stack facts (auth layers, base URLs, tenancy) are pinned in [`_shared/stack.md`](_shared/stack.md) — read it before the first call and keep every statement below consistent with it.

- **Middleware `/v1` (production surface)** — with the gateway headers `x-api-gw-organization-uuid` + `x-api-gw-user-uuid` (Keycloak at the gateway; the middleware mints the tenant token, Redis-cached).
- **CE direct (admin/server ops)** — with the `x-token` header (from the `API_KEYS` env var) or an `x-jwt-token` for end-user auth. Base URL is `FORMIO_BASE_URL`.

There is no API-key header auth, no SaaS project mapping, no project-config commands, and nothing stored in a per-user formio config file. Schema documents read and write **definitions**, not submissions — submission endpoints are runtime application surface (see `alpha-form-api`).

## When to load which reference

References are partitioned by schema domain. Pick a domain first, then pick a reference inside that domain. Adding a new schema domain is purely additive — new subdirectory under `references/`, new row in the appropriate table below.

### Form definitions

| Working on… | Load |
| --- | --- |
| Top-level form properties (`title`, `path`, `display`, `access`, `settings`, etc.) | `references/form/form-definition.md` |
| Properties shared by all components (`key`, `label`, `validate`, `conditional`, `logic`, etc.) | `references/form/base-component.md` |
| A specific input field (textfield, number, select, checkbox, file, signature, button, …) | `references/form/input-components.md` |
| Visual layout containers (panel, columns, tabs, table, fieldset, well, content) | `references/form/layout-components.md` |
| Nested or repeatable data (container, datagrid, editgrid, datamap, nested form, address) | `references/form/data-components.md` |

### Submissions

| Working on… | Load |
| --- | --- |
| Top-level submission envelope (`_id`, `form`, `owner`, `roles`, `state`, `metadata`, etc.) | `references/submission/submission-definition.md` |
| Lifecycle state — `draft` vs `submitted`, when each is written | `references/submission/submission-state.md` |
| The `metadata` bag (timezone, browser, headers, extension keys) | `references/submission/submission-metadata.md` |
| Row-level `access` overrides and every `AccessType` value | `references/submission/submission-access.md` |
| Decoding the `data` envelope — key paths, nesting, address discriminated union | `references/submission/submission-data.md` |

### Projects

**Cut.** The alpha fork has no project/tenant documents — no SaaS projects, stages, tenants, or teams, and no `ProjectSettings`/`ProjectAccessInfo` shapes. The only project-domain artifact that survives is the **template envelope** used for import/export (see "Alpha-flavor additions" below).

For action configs, see the dedicated `alpha-form-actions` skill. For role objects, see the `alpha-form-api` skill directly — role JSON is shallow enough that a separate domain is not warranted.

You can load multiple references in parallel if a task spans categories (e.g., a wizard with data grids and a signature field touches every form reference).

## Top-level shape (form domain)

A form is a JSON object. The only required property is `components`; everything else is optional but commonly set:

```json
{
  "title": "User Registration",
  "name": "userRegister",
  "path": "user/register",
  "type": "form",
  "display": "form",
  "components": [
    /* ... */
  ]
}
```

- `type`: `"form"` (collects submissions) or `"resource"` (reusable data model referenced by other forms).
- `display`: `"form"` (single page) or `"wizard"` (each top-level `panel` becomes a page/step). The `"pdf"` display value exists in the schema but is **not usable in this deployment** — no hosted PDF server (see `_shared/stack.md`).
- `components`: ordered array of component objects — the body of the form.

For the full list of form-level properties including `access`, `submissionAccess`, `settings`, `revisions`, and `controller`, see `references/form/form-definition.md`.

## Components at a glance

Every component has at minimum:

```json
{ "type": "textfield", "key": "firstName", "input": true, "label": "First Name" }
```

- `type` — which kind of component (see catalog below).
- `key` — unique identifier within the form; becomes the submission data path.
- `input` — `true` for data-collecting fields, `false` for layout-only components.
- `label` — displayed above the field.

All other shared properties (validation, conditional display, calculated values, access, logic, etc.) live in `references/form/base-component.md`.

### Component catalog

Components fall into three categories. Pick a category, load its reference for full property tables.

**Input components** (`references/form/input-components.md`) — collect user data:

| `type` | Purpose |
| --- | --- |
| `textfield` | Single-line text |
| `textarea` | Multi-line text, optional WYSIWYG |
| `number` | Numeric input |
| `password` | Masked text |
| `email` | Email with optional Kickbox verification |
| `phoneNumber` | Phone input |
| `url` | URL input |
| `datetime` | Date and/or time picker |
| `day` | Separate day/month/year fields |
| `time` | Time-only input |
| `checkbox` | Single boolean |
| `radio` | Single-select radio group |
| `selectboxes` | Multi-select checkbox group |
| `select` | Dropdown (values can be static, fetched from a URL, or loaded from a Form.io resource, or from custom JS) |
| `resource` | Select referencing a Form.io resource |
| `hidden` | Stored data without UI |
| `button` | Submit / reset / event / OAuth / URL action |
| `signature` | Signature pad |
| `file` | File upload |
| `tags` | Tag input |
| `survey` | Matrix-style survey grid |

**Layout components** (`references/form/layout-components.md`) — structure the form visually, set `input: false`:

| `type`        | Purpose                                      |
| ------------- | -------------------------------------------- |
| `panel`       | Collapsible section; also a wizard page/step |
| `columns`     | Multi-column row                             |
| `table`       | HTML table of components                     |
| `tabs`        | Tabbed sections                              |
| `fieldset`    | Legend-labeled group                         |
| `well`        | Styled container                             |
| `content`     | Static HTML block                            |
| `htmlelement` | Custom HTML tag                              |

**Data components** (`references/form/data-components.md`) — manage nested or repeatable data:

| `type`       | Purpose                                                            |
| ------------ | ------------------------------------------------------------------ |
| `container`  | Groups children under a nested object                              |
| `datagrid`   | Repeatable row-based table                                         |
| `editgrid`   | Repeatable list with inline/modal editing                          |
| `datamap`    | Key-value pair editor                                              |
| `form`       | Embeds another form                                                |
| `address`    | Address autocomplete with manual fallback                          |
| `datasource` | Fetches external data that can be used by other components (no UI) |
| `recaptcha`  | Google reCAPTCHA component (type exists in the js fork)            |

## Alpha-flavor additions

Three things this fork adds over upstream stock Form.io schema docs (`_shared/stack.md` has the pinned facts):

- **`machineName` plugin** (`front-end/formio/formio/src/plugins/machineName.js`) — every model (form, submission, resource, action, role) gets a `machineName` (`String`, `__readonly`, unique per collection) auto-set on save. It is the exportable stable name: template import/export key forms/roles by machineName, and middleware tenant form lookup resolves by `path` + `machineName`.
- **`timestamps` plugin** (`front-end/formio/formio/src/plugins/timestamps.js`) — every model gets `created` + `modified` (`Date`, `__readonly`), maintained by the server (distinct from middleware `submission_revisions` `createdAt`/`updatedAt` Mongoose timestamps).
- **Template envelope** (`default-template.json`) — template import/export documents have the shape `{title, name, version, description, roles, resources, forms, actions, access}`, with `roles`/`forms` maps keyed by **machineName** and `access` entries referencing roles by **name** (`"anonymous"`, `"administrator"`). Import is CE `POST /import`.

i18n note: form labels come from each component's `label`/`defaultValue`, not from a schema-level localization block. CE error strings are localized via `accept-language` (bundles: `en`, `ja`, `mn`, `th`, `tl`, `vi`).

## Tips for writing forms

- **Keys must be unique within a form.** Nested components (inside a `container`, `datagrid`, etc.) namespace their keys under the parent.
- **Wizards are built from panels.** Set `display: "wizard"` on the form; each top-level `panel` component becomes one step.
- **Resources vs forms.** Use `type: "resource"` for reusable data objects that can be referenced by `select` components with `dataSrc: "resource"`. Use `type: "form"` for anything that collects submissions.
- **Conditional visibility.** Three formats exist: simple, JSON Logic, and legacy. An advanced conditional can also be written with custom JS. See `references/form/base-component.md` for syntax.
- **Avoid `calculateValue` without `allowCalculateOverride`** unless the field should truly be read-only-by-computation — users cannot edit a calculated field by default.
