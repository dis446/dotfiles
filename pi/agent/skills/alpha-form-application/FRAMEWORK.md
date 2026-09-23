# FRAMEWORK — Registry and routing

This document is loaded by the parent `alpha-form-application` skill during Step 4. It is **not** a standalone skill — no frontmatter.

## The registry

Routing is driven by this table. Rows are data; adding a framework is a table edit, not a code change.

| Framework | Entry skill | Extend path | Detection signal |
| --- | --- | --- | --- |
| React | deferred — `formio-react` scaffold skill is a future feature; until it exists, embed/render via [`alpha-form-form`](../alpha-form-form/SKILL.md) (`@formio/react` fork, monorepo `packages/react`) | same as Entry (deferred) | `react` (or `@formio/react`) in `package.json` dependencies |

The alpha stack is **React-only** for user-facing portals (admin-portal, borrower-portal, sales-portal; `@formio/react` fork in `front-end/formio/monorepo`). There is no Angular anywhere. When the future `formio-react` skill lands, this row gains its real Entry/Extend names; no edit to the routing logic below is required.

## Step 4 logic

### Build-new branch

1. Count the active rows in the registry.
2. **If exactly one row:** route silently to that row's path. Pass the handoff context (workspace path, `baseUrl`, tenant org UUID when applicable, `template.md` path, `template.json` path, import-succeeded flag). The user is NOT asked which framework — when only one is installed, the choice is obvious.
3. **If multiple rows:** ask the user to pick, in ONE question round. Offer one option per active registry row, each described in terms of what it generates.

### Modify-existing branch

Detection path — inspect the workspace to find out which framework is already installed:

1. For each row in the registry, check whether the Detection signal matches the workspace (dependency present, etc.).
2. **Exactly one match:** route to that row's extend path. Pass the handoff context (workspace path, the user's plain-language request, delta `template.md` path, delta `template.json` path, list of newly-imported resource names). The delta template pair IS in the handoff — the extend path needs `template.md` for intent and `template.json` for structured field shapes when scaffolding the new resources.
3. **Multiple matches** (unusual): ask the user to pick in one question round, same shape as the build-new multi-framework case.
4. **Zero matches:** the workspace does not have a recognized framework installed. Two sub-cases:
   - Workspace is empty — the user probably meant build-new. Bounce back to Step 1: "I don't see an existing app in this directory — did you mean to build a new one?"
   - Workspace has non-framework code — tell the user we couldn't detect a supported framework, list the ones in the registry, and ask them to pick.

## How to add a new framework

When a future change adds a framework skill (e.g., the deferred `formio-react`):

1. The new framework skill authors its own `skills/formio-react/SKILL.md` + sub-skills + sibling docs, independent of this registry.
2. In the same PR, update the React row above (or add a row for the new framework) with the Entry skill, Extend sub-skill, and detection signal.
3. Verify that the new row's Entry skill and Extend sub-skill accept the same handoff context shape described below. If they don't, update the new framework skill — the orchestrator does not adapt.

That is the entire integration point. No edit to `SKILL.md`, no edit to `INTENT.md` / `IMPORT.md`, no new routing logic. Adding a framework is a row.

## Handoff context reference

What each row's target path receives when called by Step 4:

### Build-new → Entry path

```
{
  workspacePath: string,               // absolute
  formioBaseUrl: string,               // no trailing slash (CE base URL from the Preflight)
  tenantOrgUuid: string | undefined,   // when the app is tenant-scoped through the middleware
  templateMdPath: string,              // absolute, planner's template.md (architectural-intent seed)
  templateJsonPath: string,            // absolute, planner's template.json (structured companion)
  importStatus: 'succeeded' | 'skipped' | 'failed-user-chose-continue'
}
```

The Entry path uses this to load the template pair (both files on disk — `template.md` for intent, `template.json` for shape). The generated configuration maps the middleware surface `{baseUrl}/v1` and the tenant headers `x-api-gw-organization-uuid` / `x-api-gw-user-uuid` (see [`_shared/stack.md`](_shared/stack.md) → Auth).

### Modify-existing → Extend path

```
{
  workspacePath: string,               // absolute
  userRequest: string,                 // verbatim plain-language request
  templateMdPath: string,              // absolute, planner's delta template.md
  templateJsonPath: string,            // absolute, planner's delta template.json
  newResourceNames: string[],          // machine names of the resources added by this delta
  tenantOrgUuid: string | undefined    // as above
}
```

The Extend path reads the existing app's configuration from the workspace and interprets the user's request in framework-native terms, using the delta template pair to scaffold exactly the newly-added resources. Until `formio-react` exists, this means embedding the new forms with [`alpha-form-form`](../alpha-form-form/SKILL.md) inside the existing React portal.
