# Page Setup — HTML Requirements and Library Inclusion

## Overview

What a page needs before `Formio.createForm` can render anything: the renderer bundle, its CSS, a bootstrap-compatible stylesheet, and a target element.

## ESM inclusion (bundled applications) — preferred

```js
import { Formio } from '@formio/js';
import '@formio/js/dist/formio.form.min.css';

const form = await Formio.createForm(
  document.getElementById('formio'),
  'https://forms.example.com/v1/form/myform'
);
```

Prefer this everywhere you have a build step: the renderer is pinned by your lockfile, audited by your dependency scanner, and served from your own origin.

## Bundle inclusion (plain HTML pages, no build step)

The alpha renderer is the **`@formio/js` fork, `1.0.x`**, published to the private Nexus registry (see [`../_shared/stack.md`](../_shared/stack.md) — the monorepo reference line is **1.0.115**; the middleware pins **1.0.47**, so the bundle you serve must match the deployment's renderer line). There is **no third-party content host** in the alpha stack: serve the fork's built pair from your own origin or a Nexus-hosted artifact — a floating third-party URL silently changes what executes and cannot be audited.

```html
<link rel="stylesheet" href="/vendor/formio.form.min.css" />
<script src="/vendor/formio.form.min.js"></script>

<div id="formio"></div>

<script>
  Formio.createForm(document.getElementById('formio'), 'https://forms.example.com/v1/form/myform');
</script>
```

The build exposes the global `Formio`. `formio.form.min.js` and `formio.form.min.css` are the renderer pair — everything `Formio.createForm` needs and nothing else. The fork also ships CommonJS (`require('@formio/js')`) for Node/SSR contexts — module-format details live in `alpha-form-sdk`.

## Target element

`Formio.createForm` renders into any block element you hand it — conventionally an empty `<div>`. The renderer owns that element's contents; do not manage its children from your own code.

## URL configuration

**One base URL per environment — there is no project URL.** Set `Formio.setBaseUrl` to the middleware origin (production surface, global prefix `/v1`), or to the CE root (`FORMIO_BASE_URL`, e.g. `https://form-dev.alpha.looms.cloud`) only for direct admin/server access with `x-token`/`API_KEYS`.

```js
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://forms.example.com'); // middleware origin; forms live under /v1/form/...
```

Form URLs passed to `Formio.createForm` are `{baseUrl}/v1/form/{formPath}` through the middleware, or `{baseUrl}/{formPath}` against CE directly. Do not hardcode an example host in real code — take the base URL from the environment's configuration (same source as `FORMIO_BASE_URL`); a wrong base ships an application pointed at the wrong deployment.

## See also

- [rendering.md](./rendering.md) — the three input shapes `createForm` accepts.
- [options.md](./options.md) — the options object.
