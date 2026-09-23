## Overview

CE revisions are **fetch-by-id query params only** — there is no draft/publish workflow, no `/form/:id/v` list endpoint, no `/draft`/`/publish` routes in the CE fork. Historical reads work by passing a revision id to the standard GET endpoints:

- `?formRevision=<id>` — load a form as of a historical form-revision (`formRevisionLoader`).
- `?submissionRevision=<id>` — load a submission as of a historical submission-revision (`submissionRevisionLoader`).

Revisions are recorded by the server (the `machineName`/`timestamps` plugin world) — there is no client-side "enable revisions" flag like SaaS Form.io's `revisions: 'original'|'current'` mode. The models are `mongoose.models.formrevision` and `mongoose.models.submissionrevision`.

For **submission history in production**, the middleware is the real mechanism: each write carries an `x-request-id` and creates a `submission_revisions` entry; `GET /v1/submission/bulk` resolves latest-by-request across forms (see `middleware-v1.md`).

## Endpoints

### GET {baseUrl}/form/:formId?formRevision=:revisionId

Fetch a form as of a historical revision.

| Query parameter | Type | Description |
| --- | --- | --- |
| `formRevision` | string | The form-revision document `_id`. |

Response: the form document as it existed at that revision.

Errors: `404` if the revision does not exist; `401`/`403` for insufficient access.

Example:

```bash
curl -H "x-token: $API_KEY" \
  "{baseUrl}/form/69d69ce1040fa2cea2572c71?formRevision=69d69df5040fa2cea2572ce4"
```

### GET {baseUrl}/:formPath/submission/:submissionId?submissionRevision=:revisionId

Fetch a submission as of a historical revision.

| Query parameter | Type | Description |
| --- | --- | --- |
| `submissionRevision` | string | The submission-revision document `_id`. |

Response: the submission document as it existed at that revision, including the `metadata` captured at the time.

Errors: `404` if the revision does not exist; `401`/`403` for insufficient access.

Example:

```bash
curl -H "x-jwt-token: $USER_JWT" \
  "{baseUrl}/onboarding-872/submission/69dd37ba040fa2cea2579ee2?submissionRevision=69dd3800040fa2cea2579e00"
```

## Related Skills

- [project-forms](./project-forms.md) — base form CRUD
- [middleware-v1](./middleware-v1.md) — `x-request-id` submission versioning and `GET /v1/submission/bulk`
- [runtime-submissions](./runtime-submissions.md) — submission CRUD including `?submissionRevision=`
