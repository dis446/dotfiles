## Overview

Form CRUD via the SDK. A `new Formio(formUrl)` instance is the access point: it parses the URL into `projectId`, `formId`, etc., and exposes `loadForm`, `saveForm`, `deleteForm`, plus `loadForms` for lists. Sourced from `packages/core/src/sdk/Formio.ts` in the Form.io source code.

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

A form URL is either `{baseUrl}/<formAlias>` or `{baseUrl}/form/<formId>`. The SDK accepts both and resolves `formId` lazily.

## API

Constructor:

```ts
const formio = new Formio(`${Formio.getBaseUrl()}/myform`);
// or
const formio = new Formio(`${Formio.getBaseUrl()}/form/000000000000000000000001`);
```

Resolved instance properties (read-only; the names are the SDK's URL-parsing vocabulary — in this single-project stack they all resolve against `{baseUrl}`):

- `formio.projectUrl` — the deployment root (`{baseUrl}`).
- `formio.formUrl` — `{baseUrl}/form/<id>`.
- `formio.formId` — the resolved Mongo ObjectId.
- `formio.formsUrl` — `{baseUrl}/form` (list).

Instance methods:

- `loadForm(query?, opts?): Promise<Form>` — `GET ${formUrl}`. Honors form revisions when the URL contains `?formRevision=<rev>`.
- `saveForm(data?, opts?): Promise<Form>` — `POST` if `formId` is absent, otherwise `PUT`. Used for both create and update.
- `deleteForm(opts?): Promise<void>` — `DELETE ${formUrl}`.
- `loadForms(query?, opts?): Promise<Form[]>` — `GET ${formsUrl}?<query>`. Use Mongo-style filters (`type=form`, `tags__in=published`, `limit=50`, `skip=0`).
- `getFormId(): Promise<string>` — resolve the alias to a real ObjectId.

Static helpers:

- `Formio.clearCache(): void` — drop the request cache (useful after `saveForm` if you observe stale reads).

## Examples

### Load a form by alias

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');

const form = await new Formio(`${Formio.getBaseUrl()}/intake`).loadForm();
console.log(form.components.length, 'components');
```

### Create a form

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');

const created = await new Formio(`${Formio.getBaseUrl()}/form`).saveForm({
  title: 'Intake',
  name: 'intake',
  path: 'intake',
  type: 'form',
  components: [
    { type: 'textfield', key: 'firstName', label: 'First Name', input: true },
    { type: 'email', key: 'email', label: 'Email', input: true },
    { type: 'button', key: 'submit', label: 'Submit', action: 'submit', input: true },
  ],
});
```

### Update an existing form

```ts
import { Formio } from '@formio/js';

const formio = new Formio(`${Formio.getBaseUrl()}/intake`);
const form = await formio.loadForm();
form.title = 'Patient Intake';
await formio.saveForm(form);
```

### List forms with a query filter

```ts
import { Formio } from '@formio/js';

const forms = await new Formio(`${Formio.getBaseUrl()}/form`).loadForms({
  params: { type: 'form', tags__in: 'published', limit: 50, skip: 0 },
});
```

### Delete a form

```ts
import { Formio } from '@formio/js';

await new Formio(`${Formio.getBaseUrl()}/form/000000000000000000000001`).deleteForm();
```

## REST-first

There are no MCP tools in this deployment — the SDK methods above are the interface. The underlying endpoints are `GET/POST/PUT/DELETE {baseUrl}/form[/:formId]` and `GET {baseUrl}/form` (see `../../alpha-form-api/references/project-forms.md`).
