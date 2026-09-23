## Overview

Render a Form.io form inside a VanillaJS (or any framework — React, Vue, Svelte) consumer with `Formio.createForm(element, formSrc, options)`. Covers prefill, event subscription (`change`, `submit`, `error`, `nextPage`, `prevPage`, `render`, `attach`), wizards, read-only mode, and offline / local-JSON form sources. Sourced from `packages/js/src/Formio.js` (renderer extensions), `packages/js/src/Embed.js`, `packages/js/src/Form.js`, and `packages/js/src/Webform.js` in the monorepo fork.

## Imports

```ts
import { Formio } from '@formio/js';
```

> The CSS that styles the rendered form ships with `@formio/js`. In a bundler-driven app, import the stylesheet once at bootstrap (e.g. `import '@formio/js/dist/formio.form.min.css';`). Note the package is a **CJS build** — `import` statements resolve to the `lib/cjs` files; there is no ESM bundle.

## URL Configuration

One base URL per environment — set once at bootstrap (see [setup.md](./setup.md)):

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1'); // middleware production surface
// or the bare CE origin for direct server-side access:
// Formio.setBaseUrl('https://form-dev.alpha.looms.cloud');
```

There is no `{projectUrl}` in this stack — no SaaS, no project routing. Use `Formio.getBaseUrl()` everywhere the upstream examples used `getProjectUrl()`.

The `formSrc` argument to `Formio.createForm` is one of:

- A full form URL: `{baseUrl}/<formAlias>` or `{baseUrl}/form/<formId>` — the renderer loads the form definition over HTTP using the configured `baseUrl`.
- A form JSON object: `{ display: 'form', components: [...] }` — the renderer skips the network round-trip (use for offline / local JSON).

## API

Static methods on `Formio` (renderer extensions in `packages/formio.js/src/Formio.js`):

- `Formio.createForm(element: HTMLElement, form: string | object, options?: FormOptions): Promise<Form>` — render a form and resolve when it's attached to the DOM.
- `Formio.use(module)` — register a renderer module (custom component, template, addon).
- `Formio.icons` / `Formio.Templates.framework` — global icon-pack / template selection.
- `Formio.formioReady` — `Promise<void>` that resolves when the renderer's runtime is initialized.

Common `options` (`packages/formio.js/src/Webform.js`):

- `readOnly: boolean` — disable input; useful for review screens.
- `noAlerts: boolean` — suppress validation toasts.
- `language: string` — switch language at render time (see `i18n`).
- `template: string` — switch template framework (`bootstrap`, `bootstrap3`, etc.).
- `evalContext: object` — extra variables exposed to custom JavaScript / formula components.
- `submission: { data: {} }` — pre-fill values (can also be set after render via `form.submission = {...}`).
- `viewAsHtml: boolean` — render the submission as static HTML (read-only review).

The resolved `form` instance is an `EventEmitter`. Common events:

- `submit` — fired after a successful submit; payload is the `submission` object.
- `submitDone` — fired after the submission lifecycle completes (after `submit` actions).
- `submitError` — fired when validation or persistence fails.
- `change` — fired on every component value change; payload includes `{ changed, isValid }`.
- `error` — fired on validation errors; payload is the array of errors.
- `nextPage` / `prevPage` — fired when a wizard advances or retreats; payload includes `{ page, submission }`.
- `render` — fired after every re-render.
- `attach` — fired once after initial attach.
- `componentChange` — fired with `{ component, value, flags }` per component edit.

Programmatic access on the resolved instance:

- `form.submission = { data: {...} }` — prefill values; the renderer diffs and updates components.
- `form.setSubmission(submission, flags?)` — explicit setter that returns a Promise.
- `form.submit()` — programmatically submit.
- `form.validate(): Promise<boolean>` — run validation without submitting.
- `form.setForm(newDefinition)` — swap the form definition at runtime.
- `form.destroy()` — tear down the form and detach from the DOM.
- `form.checkValidity(): boolean` — synchronous validity check.

## Examples

### Render a hosted form by URL

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');

const form = await Formio.createForm(
  document.getElementById('formio')!,
  `${Formio.getBaseUrl()}/intake`
);

form.on('submit', (submission) => {
  console.log('submitted:', submission._id);
});
```

### Render a form by URL

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');

const form = await Formio.createForm(
  document.getElementById('formio')!,
  `${Formio.getBaseUrl()}/intake`
);
```

### Prefill submission values

```ts
import { Formio } from '@formio/js';

const form = await Formio.createForm(
  document.getElementById('formio')!,
  `${Formio.getBaseUrl()}/intake`
);

form.submission = {
  data: {
    firstName: 'Alice',
    email: 'alice@example.com',
  },
};
```

### Subscribe to every change

```ts
import { Formio } from '@formio/js';

const form = await Formio.createForm(
  document.getElementById('formio')!,
  `${Formio.getBaseUrl()}/intake`
);

form.on('change', ({ changed, isValid }) => {
  if (changed) {
    console.log('field changed:', changed.component.key, '→', changed.value, 'valid:', isValid);
  }
});

form.on('error', (errors) => {
  console.warn('validation errors:', errors);
});
```

### Wizard pagination

```ts
import { Formio } from '@formio/js';

const wizard = await Formio.createForm(
  document.getElementById('formio')!,
  `${Formio.getBaseUrl()}/onboarding`
);

wizard.on('nextPage', ({ page, submission }) => {
  console.log('moved to page', page, 'so far:', submission.data);
});
wizard.on('prevPage', ({ page }) => {
  console.log('back to page', page);
});
```

### Read-only review screen

```ts
import { Formio } from '@formio/js';

await Formio.createForm(
  document.getElementById('review')!,
  `${Formio.getBaseUrl()}/intake/submission/000000000000000000000010`,
  { readOnly: true, viewAsHtml: true }
);
```

### Render a local JSON form definition (offline / no HTTP)

```ts
import { Formio } from '@formio/js';

const formDefinition = {
  display: 'form',
  components: [
    { type: 'textfield', key: 'firstName', label: 'First Name', input: true },
    { type: 'email', key: 'email', label: 'Email', input: true },
    { type: 'button', key: 'submit', label: 'Submit', action: 'submit', input: true },
  ],
};

const form = await Formio.createForm(document.getElementById('formio')!, formDefinition);

form.on('submit', (submission) => {
  console.log('local submission (not persisted):', submission.data);
});
```

### Programmatic submit + validation

```ts
import { Formio } from '@formio/js';

const form = await Formio.createForm(
  document.getElementById('formio')!,
  `${Formio.getBaseUrl()}/intake`
);

document.getElementById('submitBtn')!.addEventListener('click', async () => {
  const valid = await form.validate();
  if (!valid) {
    console.warn('not valid yet');
    return;
  }
  await form.submit();
});
```

### Destroy a form when navigating away

```ts
import { Formio } from '@formio/js';

const form = await Formio.createForm(
  document.getElementById('formio')!,
  `${Formio.getBaseUrl()}/intake`
);

window.addEventListener('beforeunload', () => {
  form.destroy();
});
```

## REST-first

Rendering is a runtime concern with no tool equivalent — use the SDK directly. There is no PDF-backed form rendering in this stack (no PDF server); forms render from their component definitions.
