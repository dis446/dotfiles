# Action Types — Detailed Settings Reference

> **Every `{{ data.* }}` token below resolves at runtime to a value some submitter typed.** Configuring an action is build-time work; the action then runs inside the Form.io server on every matching submission, carrying those values into email bodies, webhook URLs and payloads, and recipient lists. The settings written here are the only place that handling gets decided, so keep webhook and template hosts literal and HTTPS, and constrain any field whose value lands in markup or an address. Stated once in [../SKILL.md](../SKILL.md) → "Build time vs runtime" and "Security"; applies to every action type below.

## Table of Contents

### Open Source

1. [Save Submission](#save-submission)
2. [Login](#login)
3. [Role Assignment](#role-assignment)
4. [Email](#email)
5. [Webhook](#webhook)
6. [Reset Password](#reset-password)

---

## Save Submission

**Name:** `save` | **Priority:** 10 | **Handler:** `before` | **Method:** `create`, `update`

The save action persists the submission to the database. Add it to any form or resource meant to store its submissions — most are. Omit it when the form is not meant to persist: a login form (auth only), a notification-only form (fires an Email or Webhook on submit but stores nothing), or a client-only form whose data the app reads in the browser and never sends to the submission API. It runs at priority 10 so other actions can depend on the saved submission.

### Settings

| Field | Key | Type | Description |
| --- | --- | --- | --- |
| Save to Resource | `resource` | resource select | Optional. Maps submission data to a different resource form |

### Field Mapping (when saving to another resource)

When `resource` is set, use `settings.fields` to map fields:

```json
{
  "settings": {
    "resource": "<target-resource-id>",
    "fields": {
      "<target-field-key>": "<source-field-key>"
    }
  }
}
```

Use the special value `"data"` to map the entire data object.

### Alpha customizations (beyond upstream docs)

The alpha CE fork's `SaveSubmission` adds three settings upstream does not document (`formio/src/actions/SaveSubmission.js`):

| Setting | Key | Description |
| --- | --- | --- |
| Transform | `transform` | Server-side JS evaluated against the submission before saving — lets the mapped payload be computed rather than copied |
| Property | `property` | Stores a reference back on the source submission (in addition to the `externalIds` back-reference) |
| Whole-object mapping | `fields["data"]` | Special `"data"` key maps the entire data object (see above) |

### External IDs

When saving to a resource, the server creates a back-reference in the source submission's `externalIds` array:

```json
{
  "externalIds": [
    { "type": "resource", "resource": "<resource-id>", "id": "<created-submission-id>" }
  ]
}
```

---

## Login

**Name:** `login` | **Priority:** 2 | **Handler:** `before` | **Method:** `create`

Authenticates a user against one or more resource forms. Does not create a submission — it intercepts the POST and performs authentication instead.

### Settings

| Field | Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- | --- |
| Resources | `resources` | string[] | Yes | — | Resource form IDs to authenticate against |
| Username Field | `username` | string | Yes | — | Component API key for the username/email field |
| Password Field | `password` | string | Yes | — | Component API key for the password field |
| Max Login Attempts | `allowedAttempts` | number | No | 5 | 0 = unlimited. Failed attempts before lockout |
| Attempt Time Window | `attemptWindow` | number | No | 30 | Seconds. Window for counting failed attempts |
| Locked Wait Time | `lockWait` | number | No | 1800 | Seconds (30 min). How long the account stays locked |

### Authentication Flow

1. User submits login form with username + password
2. Server queries each resource in `resources` for a submission matching the username field
3. Password is compared using bcrypt
4. On success: JWT token set in `x-jwt-token` response header
5. On failure: 401 response

### Brute-Force Protection

Failed attempts are tracked in `user.metadata.login`:

- After `allowedAttempts` failures within `attemptWindow` seconds, the account locks
- Locked accounts must wait `lockWait` seconds before retrying
- Setting `allowedAttempts: 0` disables lockout (not recommended)

---

## Role Assignment

**Name:** `role` | **Priority:** 1 | **Handler:** `after` | **Method:** `create`

Adds or removes a role from a user's submission. The target user is determined by the `association` setting.

### Settings

| Field | Key | Type | Options | Required | Description |
| --- | --- | --- | --- | --- | --- |
| Resource Association | `association` | string | `new`, `existing` | Yes | Which resource to modify |
| Action Type | `type` | string | `add`, `remove` | Yes | Whether to add or remove the role |
| Role | `role` | string | — | Yes | The role ID to assign/remove |

### Association Types

**`new`** — The submission being created IS the resource. Use this for registration forms where the new user should receive a role.

**`existing`** — The form references an existing resource submission. The form must contain a component whose value is the target resource's submission ID (typically a hidden field or select resource). Use this for admin panels where one user modifies another user's roles.

### How It Works

- Loads the target submission's `roles` array
- `add`: Appends the role ID (deduplicates)
- `remove`: Filters the role ID out
- Saves directly via MongoDB update (bypasses the normal submission pipeline)

### Roles cannot be written directly — this action is the only writer

The submissions API **strips the `roles` key from POST/PUT/PATCH bodies**, even for the project owner. "Create the user, then PATCH `roles`" does not work, and a PUT that includes a `roles` key can wipe the user's existing roles. Any workflow that sets or changes a user's role must go through a Role Assignment action.

### Multi-role user systems — one conditional action per role

This pattern applies when all personas share ONE user collection (a single user resource) — the common default. If the application's requirements instead call for a resource per role (e.g., a separate `admin` resource, with the Login action's `settings.resources` listing both), it is unnecessary: each user-type resource carries its own unconditional Role Assignment.

When one shared user resource serves several personas (e.g., `applicant` / `admissions` / `finance`), give the user form a `selectboxes` component (key `role`, one value per persona) and attach **one Role Assignment action per persona**, each gated by a condition on its box:

```json
{
  "title": "Role Assignment (Admissions)",
  "name": "role",
  "handler": ["after"],
  "method": ["create"],
  "priority": 1,
  "condition": {
    "conjunction": "all",
    "conditions": [{ "component": "role", "operator": "isEqual", "value": "admissions" }],
    "custom": ""
  },
  "settings": {
    "association": "new",
    "type": "add",
    "role": "<admissions-role-id>"
  }
}
```

Whoever creates or edits the user (portal admin, or an API caller setting `data.role.admissions = true`) checks the box; the matching action attaches the role server-side. The planner-side emission rules for this pattern live in `alpha-form-resource-planner`'s `../../alpha-form-resource-planner/references/template-json.md` → "Multi-role user systems".

---

## Email

**Name:** `email` | **Priority:** 0 | **Handler:** `after` | **Method:** `create`

Sends an email notification when a submission event occurs.

### Settings

| Field | Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- | --- |
| Transport | `transport` | string | Yes | — | Email transport name (e.g., `"default"`) |
| From | `from` | string | No | `no-reply@example.com` | Sender email address — see "From address" below |
| Reply-To | `replyTo` | string | No | — | Reply-to address |
| To Emails | `emails` | string[] | Yes | — | Recipient addresses |
| Send Each | `sendEach` | boolean | No | false | Send individual email per recipient |
| Cc | `cc` | string[] | No | — | Carbon copy |
| Bcc | `bcc` | string[] | No | — | Blind carbon copy |
| Subject | `subject` | string | No | `New submission for {{ form.title }}.` | Subject line |
| Template URL | `template` | string | No | The server's default wrapper | External HTML template — see "External Templates" below |
| Message | `message` | string | No | `{{ submission(data, form.components) }}` | Email body |
| Rendering Method | `renderingMethod` | string | No | `dynamic` | `dynamic` (formio.js) or `static` (legacy) |

### Template Variables

| Variable | Description |
| --- | --- |
| `{{ data.fieldKey }}` | Individual submission field value |
| `{{ id }}` | The current submission's `_id` |
| `{{ submission(data, form.components) }}` | Formatted table of all submission fields |
| `{{ form.title }}` | Form title |
| `{{ form._id }}` | Form ID |
| `{{ owner.data.email }}` | Submission owner's email (if available) |

Email addresses in `emails`, `cc`, `bcc` also support template variables, allowing dynamic recipients: `{{ data.managerEmail }}`.

### From address

When an Email action is needed, **ask the user which "from" address they want** before emitting the action. If they don't provide one, default to `no-reply@example.com`. The send-side default comes from the CE server's `config.defaultEmailSource`; `from` is not free-form — it must be an address the configured mail transport accepts.

### `submission._id` is not a token

`{{ submission._id }}` does NOT work — `submission` is not a template variable, so it renders empty. To inject the current submission's id, use **`{{ id }}`**.

### `{{ config.* }}` tokens do not resolve in this fork

Upstream documents `{{ config.<key> }}` tokens backed by a project public-config object. The alpha CE fork has **no such object** — `{{ config.* }}` renders empty and there is no endpoint to populate it. Do not emit templates that rely on it; the only supported token set is `{{ data.* }}`, `{{ id }}`, `{{ form.* }}`, and `{{ owner.* }}`.

### External Templates

If `template` is set to a URL, the server fetches that HTML and uses it as the email wrapper. The `message` content is injected into the template. If the fetch fails, the message is sent directly without a template wrapper.

Leave `template` unset to use Form.io's default wrapper. When you do set it, point it at a URL on a host you control and serve it over HTTPS: the server re-fetches it at send time, so whoever controls that URL controls the markup of every email the action sends, and a URL that later expires or changes hands becomes a phishing vector inside your own mail. Do not set it to a third-party or user-supplied URL.

---

## Webhook

**Name:** `webhook` | **Priority:** 0 | **Handler:** `after` | **Method:** `create`, `update`, `delete`

Makes an HTTP request to an external URL when a submission event occurs.

### Settings

| Field | Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- | --- |
| Webhook URL | `url` | string | Yes | — | Target URL (supports `{{ data.field }}` interpolation) |
| Block Request | `block` | boolean | No | false | Wait for webhook response before completing submission |
| Username | `username` | string | No | — | HTTP Basic Auth username |
| Password | `password` | string | No | — | HTTP Basic Auth password |

### Request Payload

The webhook sends a JSON POST/PUT/DELETE (matching the submission's HTTP method):

```json
{
  "request": {
    /* original request body */
  },
  "response": {
    /* response object */
  },
  "submission": {
    /* current submission as plain object */
  },
  "params": {
    /* URL route parameters */
  }
}
```

### Blocking vs Non-Blocking

**Non-blocking** (`block: false`, default): The webhook fires in the background. The form submission completes immediately regardless of webhook success/failure. Errors are logged but not surfaced to the user.

**Blocking** (`block: true`): The submission waits for the webhook response. If the webhook returns a non-2xx status, the submission fails with an error. The webhook response is stored in `submission.metadata[action.title]`.

### URL Interpolation

The URL supports template variables: `https://api.example.com/{{ data.type }}/{{ data._id }}`

Keep the scheme and host literal. A submitter controls every `{{ data.* }}` value, so interpolating one into the host — or into a path that a `..` segment can escape — lets a submission redirect the request, and with it the Basic Auth credentials in `username`/`password`, to a server of their choosing. Interpolate only into path or query positions whose value you constrain (a select with fixed options, a validated pattern), and send webhooks only to HTTPS endpoints you own.

---

## Reset Password

**Name:** `resetpass` | **Handler:** `before`+`after` | **Method:** `form`, `create`

Implements a two-phase password reset flow using temporary JWT tokens.

### Settings

| Field | Key | Type | Required | Default | Description |
| --- | --- | --- | --- | --- | --- |
| Resources | `resources` | string[] | Yes | — | Resource forms containing user submissions |
| Username Field | `username` | string | Yes | — | Component API key for username/email |
| Password Field | `password` | string | Yes | — | Component API key for password |
| Reset Link URL | `url` | string | Yes | — | Base URL for the reset page |
| Transport | `transport` | string | Yes | — | Email transport |
| From | `from` | string | No | Server default | Sender email |
| Subject | `subject` | string | No | `You requested a password reset` | Email subject |
| Message | `message` | string | No | Default template | Email body with `{{ resetlink }}` |
| Button Label | `label` | string | No | `Email Reset Password Link` | Submit button text shown on the form |

### Two-Phase Flow

**Phase 1 — Request reset (user submits email):**

1. The `before` + `form` handler modifies the form display: hides password field, shows only username, changes submit button label
2. User submits their email/username
3. Server looks up the user across configured resources
4. Generates a temporary JWT (5-minute expiry) with `type: "resetpass"`
5. Sends email with `{{ resetlink }}` expanded to `{url}?x-jwt-token={token}`

**Phase 2 — Set new password (user clicks link):**

1. The `before` + `form` handler modifies the form: hides username, shows password field
2. User enters new password and submits
3. Server validates the JWT token type is `"resetpass"`
4. Encrypts the new password with bcrypt and saves
5. Maximum password length: 200 characters (configurable)

### Template Variables

| Variable          | Description                                         |
| ----------------- | --------------------------------------------------- |
| `{{ resetlink }}` | Full URL with JWT token appended as query parameter |

---

# Enterprise Action Types

The following actions exist only on enterprise Form.io servers and are **not part of the alpha deployment** — the alpha CE fork's action registry (`formio/src/actions/actions.js`) registers exactly the 6 open-source types (`save`, `login`, `role`, `email`, `webhook`, `resetpass`) and nothing else. They are documented in the upstream library for reference only; never configure them against an alpha deployment.

OAuth (`oauth`), Group Assignment (`group`), LDAP Login (`ldap`), 2FA Login (`twofalogin`), and 2FA Recovery Login (`twofarecoverylogin`) are the enterprise action types upstream documents. None of their settings, priority values, or association mechanics apply here.

## Action types this reference does not cover

A server's catalog is dynamic, so `GET /form/:formId/actions` may return names documented nowhere here. Action types whose job is to copy submissions into an external system of record — a database, a spreadsheet, a third-party SaaS — are deliberately out of scope for this skill: configuring one is a server-administration task that needs credentials, a target schema, and grants belonging to whoever owns that system, not to a form-configuration flow. When a user asks for one, say it is not covered here and point them at their Form.io administrator or the Form.io documentation. Do not infer its settings from `GET /form/:formId/actions/:name` output and configure it anyway.
