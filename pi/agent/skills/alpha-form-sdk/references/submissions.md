## Overview

Submission CRUD, querying, patching, and action discovery via `new Formio(formUrl)` and `new Formio(submissionUrl)`. Sourced from `packages/core/src/sdk/Formio.ts` in the monorepo fork.

## Imports

```ts
import { Formio } from '@formio/js';
```

## URL Configuration

One base URL per environment — set once at bootstrap (see [setup.md](./setup.md)):

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1'); // middleware production surface
// or the bare CE origin for direct server-side access:
// Formio.setBaseUrl('https://form-dev.alpha.looms.cloud');
```

There is no `{projectUrl}` in this stack — no SaaS, no project routing. Use `Formio.getBaseUrl()` everywhere the upstream examples used `getProjectUrl()`.

A submission URL is `${formUrl}/submission/<submissionId>`. List endpoint is `${formUrl}/submission`.

## API

Instance methods (on a Formio whose URL is form-scoped or submission-scoped):

- `loadSubmission(query?, opts?): Promise<Submission>` — `GET ${submissionUrl}`.
- `saveSubmission(data?, opts?): Promise<Submission>` — `POST ${formUrl}/submission` to create, `PUT ${submissionUrl}` to update (depending on whether `submissionId` is in the URL).
- `deleteSubmission(opts?): Promise<void>` — `DELETE ${submissionUrl}`.
- `loadSubmissions(query?, opts?): Promise<Submission[]>` — `GET ${formUrl}/submission?<query>`. Mongo-style filters: `data.email=alice@example.com`, `created__gt=2024-01-01`, `sort=-created`, `limit`, `skip`.
- `availableActions(): Promise<ActionInfo[]>` — `GET ${formUrl}/actions`.
- `actionInfo(name): Promise<ActionInfo>` — `GET ${formUrl}/actions/<name>` — return the action type's settings schema.
- `userPermissions(user?, form?, submission?): Promise<{ create, read, edit, delete }>` — compute the current user's access flags for a submission. Loads the form / current user if not passed.
- `canSubmit(): Promise<boolean>` — convenience for "the current user can create a new submission on this form".
- `getDownloadUrl(form?): Promise<string>` — return a temp-token download URL for the current submission (no PDF server in this stack; the method wraps the CE temp-token mechanism).
- `getTempToken(expire, allowed, options?): Promise<string>` — mint a short-lived token scoped to specific endpoint patterns (used for downloads or unauthenticated reads).

Static helpers:

- `Formio.clearCache(): void` — drop the request cache before re-reading submissions.

## Examples

### Create a submission

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');

const created = await new Formio(`${Formio.getBaseUrl()}/intake/submission`).saveSubmission({
  data: { firstName: 'Alice', email: 'alice@example.com' },
});
console.log(created._id);
```

### Load and update a submission

```ts
import { Formio } from '@formio/js';

const formio = new Formio(`${Formio.getBaseUrl()}/intake/submission/000000000000000000000010`);
const submission = await formio.loadSubmission();
submission.data.firstName = 'Allison';
await formio.saveSubmission(submission);
```

### Query submissions with filters

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');

const recent = await new Formio(`${Formio.getBaseUrl()}/intake/submission`).loadSubmissions({
  params: {
    'data.email': 'alice@example.com',
    sort: '-created',
    limit: 25,
  },
});
```

### Delete a submission

```ts
import { Formio } from '@formio/js';

await new Formio(
  `${Formio.getBaseUrl()}/intake/submission/000000000000000000000010`
).deleteSubmission();
```

### Get a temp-token download URL

```ts
import { Formio } from '@formio/js';

const formio = new Formio(`${Formio.getBaseUrl()}/intake/submission/000000000000000000000010`);
const url = await formio.getDownloadUrl();
window.open(url);
```

### List available actions for a form

```ts
import { Formio } from '@formio/js';

const actions = await new Formio(`${Formio.getBaseUrl()}/intake`).availableActions();
actions.forEach((a) => console.log(a.name, a.title));
```

## REST-first

There are no MCP tools in this deployment — use the SDK directly for submission operations, or call the corresponding REST endpoints via the `alpha-form-api` skill's `../../alpha-form-api/references/runtime-submissions.md` reference.
