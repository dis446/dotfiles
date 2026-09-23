## Overview

Role CRUD on a Form.io project. A `new Formio(roleUrl)` instance exposes `loadRole`, `saveRole`, `deleteRole`, and `loadRoles`. Sourced from `packages/core/src/sdk/Formio.ts` in the Form.io source code.

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

Roles live at `{baseUrl}/role` (list) and `{baseUrl}/role/<roleId>` (single).

## API

Instance methods on a role-scoped Formio:

- `loadRole(opts?): Promise<Role>` — `GET ${roleUrl}`.
- `saveRole(data?, opts?): Promise<Role>` — `POST ${rolesUrl}` if `roleId` is absent, `PUT ${roleUrl}` to update.
- `deleteRole(opts?): Promise<void>` — `DELETE ${roleUrl}`.
- `loadRoles(opts?): Promise<Role[]>` — `GET {baseUrl}/role` — list.

Role shape (from the API): `{ _id, title, machineName, description, admin: boolean, default: boolean }`. A role with `default: true` is assigned to anonymous traffic; a role with `admin: true` bypasses access checks within the project.

## Examples

### List roles

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');

const roles = await new Formio(`${Formio.getBaseUrl()}/role`).loadRoles();
roles.forEach((r) => console.log(r.machineName, r.admin, r.default));
```

### Create a role

```ts
import { Formio } from '@formio/js';

Formio.setBaseUrl('https://form-dev.alpha.looms.cloud/v1');

await new Formio(`${Formio.getBaseUrl()}/role`).saveRole({
  title: 'Reviewer',
  description: 'Can review and edit but not delete submissions.',
  admin: false,
  default: false,
});
```

### Update a role

```ts
import { Formio } from '@formio/js';

const formio = new Formio(`${Formio.getBaseUrl()}/role/000000000000000000000020`);
const role = await formio.loadRole();
role.description = 'Reviewer (revised).';
await formio.saveRole(role);
```

### Delete a role

```ts
import { Formio } from '@formio/js';

await new Formio(`${Formio.getBaseUrl()}/role/000000000000000000000020`).deleteRole();
```

## REST-first

There are no MCP tools in this deployment — the SDK methods above are the interface. The underlying endpoints are `GET/POST/PUT/DELETE {baseUrl}/role[/:roleId]` (see `../../alpha-form-api/references/project-roles.md`). Note: the middleware `/v1/role` is **read-only** — role writes go to CE directly.
