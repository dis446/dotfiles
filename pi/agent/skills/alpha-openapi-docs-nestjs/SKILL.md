---
name: alpha-openapi-docs-nestjs
description: "Use when documenting or reviewing the HTTP API of any Alpha NestJS service: @ApiOperation summaries/descriptions, @ApiProperty and response schemas, query and path params, tags and operationId naming - so borrower-doc and openapi-doc render enterprise-quality API reference. Sister skill to alpha-openapi-docs-quarkus."
---

# Alpha OpenAPI Documentation for NestJS

Use for any Alpha NestJS service. The annotation lives in the service; the published docs are a
downstream artifact. Improving docs means improving service annotations - never the portal repo,
never the generated `openapi.yaml`.

Target quality (the bar, all four at once):

1. **Every operation** has a human `summary` + `description` - no `<Controller>_<method>` titles.
2. **Every query/path param** has a description (and an example where format matters).
3. **Every request/response DTO field** has an `@ApiProperty` description + realistic example.
4. **Response schemas are typed where the shape is fixed**, honestly generic where it is
   dynamic (see the Response Schema Ladder).

Without `summary`, Nest's generated `operationId` leaks into the docs:

```
remark
├── RemarksController_create
├── RemarksController_findAll
└── RemarksController_findOne
```

## Cross-stack parity contract

Alpha runs two stacks (NestJS, Quarkus). A reader of the published docs must not be able to tell
which stack produced a service. Both skills enforce the same contract; only the annotation
mechanism differs. Sister skill: `alpha-openapi-docs-quarkus`.

| contract                                          | NestJS                                                 | Quarkus                                                        |
| ------------------------------------------------- | ------------------------------------------------------ | -------------------------------------------------------------- |
| title = human imperative summary, <= 60 chars     | `@ApiOperation({ summary })`                           | `@Operation(summary = ...)`                                    |
| body = description, first line stands alone       | `@ApiOperation({ description })`                       | `@Operation(description = ...)`                                |
| sidebar group = business noun, Title Case, stable | `@ApiTags` + `.addTag(name, description)`              | `@Tag(name, description)`                                      |
| doc URL slug is human-readable                    | explicit `operationId` (never `<Controller>_<method>`) | derived from `summary`                                         |
| every param documented                            | `@ApiQuery` / `@ApiParam`                              | `@Parameter`                                                   |
| shared list params documented                     | `ListQueryDto` (`@and/nest-common` >= 1.3.6)           | `ListQuery` / `ListQueryWithFilter` (quarkus-common >= 1.4.12) |
| every DTO field documented                        | `@ApiProperty(description, example)`                   | `@Schema(description, example)`                                |
| response schema honesty                           | Response Schema Ladder                                 | Response Schema Ladder                                         |
| auth in the generated spec                        | none - the API gateway enforces auth, not the service  | same                                                           |
| exposure untouched by a docs MR                   | `@ExposeToGateways`                                    | `@ExposeToApiGateways`                                         |

Stack tells that must never appear in a published spec: `<Controller>_<method>` titles (Nest),
Title-Cased camelCase method names or JAX-RS class-name tags (Quarkus), undocumented shared
pagination params, an invented security requirement, and empty `JsonNode` / `ApiResponse*`
response schemas where a fixed shape exists.

## Consumer chain

Know this chain; it decides where the work goes.

```
@ApiOperation / @ApiProperty / ...
  |  nest-common setupApplication() -> transformOpenApiDocument()
  v
openapi.yaml        generated at IMAGE BUILD: `npm run build && npm run openapi:generate`
  |                 (prod Dockerfile, baked into the image; copied into the runtime stage)
  v
CI job extract-openapi   docker create + docker cp $OPENAPI_PATH ./openapi.yaml -> artifact
  |                      exists only in the `argocd-auto-devops-release.gitlab-ci.yaml` template
  v
openapi-convertor   auto-deploy-apisix-helm: x-expose-to-gateways -> APISIX routes (routing, not docs)
  v
portal collector    swagger-collector/ in borrower-doc | openapi-doc:
  |                 fetch artifact -> keep x-expose-to-gateways == target gateway
  |                 -> strip x-* -> rewrite `servers` to https://<gwHost><BASE_PATH>
  v
swaggers/<service>.yaml -> docusaurus-plugin-openapi-docs -> docs/open-api/<service>/*.api.mdx
```

Consequences: nothing in a portal repo can rename an endpoint; the spec is generated at build
time, so pod-runtime env vars never change the artifact the docs come from; a service that
publishes no artifact is invisible to the docs no matter how well it is annotated.

### How each spec field renders

| spec field                        | rendered as                                                  | source in Nest code                                                   |
| --------------------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------- |
| `operation.summary`               | page title + sidebar label                                   | `@ApiOperation({ summary })`                                          |
| `operation.description`           | page body (markdown); **first line** is the meta description | `@ApiOperation({ description })`                                      |
| `operation.tags`                  | sidebar grouping (`groupPathsBy: "tag"`)                     | `@ApiTags(...)`, class level                                          |
| `operation.operationId`           | doc `id` and URL slug = `kebabCase(operationId)`             | `@ApiOperation({ operationId })`, else Nest's `<Controller>_<method>` |
| `operation.parameters`            | parameter tables                                             | `@ApiParam`, `@ApiQuery`, `@ApiHeader`                                |
| `requestBody...schema`            | request body table + generated sample                        | DTO class + `@ApiProperty` per field                                  |
| `responses.<code>`                | status-code table and response section                       | `@ApiOkResponse`, `@ApiCreatedResponse`, ...                          |
| `x-codeSamples`                   | copy-paste samples                                           | `@ApiExtension('x-codeSamples', ...)`                                 |
| `tags[].description`              | group description                                            | `DocumentBuilder.addTag(name, description)`                           |
| `info.title` / `info.description` | service card / landing page                                  | `SWAGGER_TITLE`, `SWAGGER_DESCRIPTION`                                |
| `x-expose-to-gateways`            | which gateway serves the route - **not in docs** (stripped)  | `@ExposeToGateways(...)`                                              |

Plugin fallbacks (identical in v4.7.1 and v5.2.0):

```js
title = operation.summary ?? operation.operationId ?? "Missing summary";
description = operation.description ?? operation.summary ?? operation.operationId;
id = kebabCase(operation.operationId);
```

A missing `summary` is therefore not "no label" - it leaks the TypeScript class and method name,
and `kebabCase(operationId)` publishes that leak in the URL.

## Prerequisites: can this repo be documented at all?

The spec reaches the portals only if all five hold:

1. `package.json` has an `openapi:generate` script (convention: `GENERATE_OPENAPI_ONLY=true node dist/main.js`).
2. The prod Dockerfile runs it in the builder stage and copies the file into the runtime image.
3. `.gitlab-ci.yml` sets `OPENAPI_PATH` (path inside the image; CI renames it to `openapi.yaml`
   in the artifact, so the on-disk name may be `openapi.json`) and `BASE_PATH` (gateway prefix,
   e.g. `/remark-service` - it does not always match the repo name).
4. `.gitlab-ci.yml` includes `argocd-auto-devops-release.gitlab-ci.yaml`. The older
   `argocd-auto-devops.gitlab-ci.yml` has **no** `extract-openapi` job.
5. `package.json` pins **`@and/nest-common` >= 1.3.6** - the first version that documents the
   shared `ListQueryDto` params and accepts `bootstrapApplication(AppModule, { tags })`. On an
   older pin the service publishes bare list params and description-less tag groups; that is a
   dependency bump, never a local DTO fork or a hand-rolled `DocumentBuilder`.

Check per repo:

```bash
R=back-end/<repo>
grep -n 'openapi' "$R/package.json"
grep -n '"@and/nest-common"' "$R/package.json"          # must be >= 1.3.6
grep -rn 'openapi' "$R"/docker/*Dockerfile* "$R"/Dockerfile* 2>/dev/null
grep -n 'OPENAPI_PATH\|BASE_PATH\|argocd-auto-devops' "$R/.gitlab-ci.yml"
```

Discover the NestJS repos in the platform:

```bash
cd ~/Code/and/alpha
grep -rl '"@nestjs/core"' --include=package.json back-end front-end | grep -v node_modules
```

If a repo fails any check, its annotations are invisible or render bare. Wiring the CI/CD side is a
`alpha-ci-cd-expert` change, not a docs change - report the gap, never skip it silently.

### Shared pieces come from `@and/nest-common` - do not fork them

A service must pin **`@and/nest-common` >= 1.3.6**. That version provides:

- `ListQueryDto` (`page` default 1, `limit` default 50, `sort`) with the swagger metadata that
  makes list endpoints render those params. Extend the class; never copy it. If a service renders
  bare `page`/`limit`/`sort` (only explicitly decorated props such as a subclass's `filter` reach
  the document), it is pinned below 1.3.6 - bump the dependency.
- `bootstrapApplication(AppModule, { tags: [...] })` with `SwaggerTag`, for document-level tag
  descriptions. On an older pin, a service that owns its Nest app must call
  `addTag(name, description)` on its own `DocumentBuilder` (as `notification-service` and
  `template-manager` do).
- `setupApplication()` declares the `bearer` scheme (so Swagger UI "Authorize" works) but **no**
  security requirement - auth is the gateway's job. It also sets `info.title/description/version`
  from `SWAGGER_*` and injects `transformOpenApiDocument()`.

## Reference implementations

Read these before writing new annotations and match their tone:

- `notification-service` `src/**/*.controller.ts`, DTOs and `src/main.ts` - the house style:
  `@ApiTags`, `@ApiOperation`, `@ApiCreatedResponse`/`@ApiOkResponse`/`@ApiBadRequestResponse`/
  `@ApiNotFoundResponse`, `@ApiProperty({ description, example })` on every field, and
  `.addTag(name, description)` for tag descriptions (its `@ApiBearerAuth()` is pre-existing - leave
  auth alone in a docs MR).
- `rule-engine` `src/common/query/list-query.dto.ts` - extending the shared `ListQueryDto` and
  documenting the derived `sort`/`filter` params from a single field map.
- `remark` `src/remarks/remarks.controller.ts` - every route of a small service annotated.
- Any Quarkus service's `@Operation(summary = ...)` output - the prose quality bar by convention.

## Decorator toolkit

```ts
import {
  ApiBadRequestResponse,
  ApiCreatedResponse,
  ApiNotFoundResponse,
  ApiOkResponse,
  ApiOperation,
  ApiParam,
  ApiProperty,
  ApiPropertyOptional,
  ApiQuery,
  ApiTags,
} from "@nestjs/swagger";
```

Class level - `@ApiTags` is the sidebar group (business noun, Title Case, stable). `@ApiTags` is
class level; `@ApiOperation` is **not** inherited - every handler needs its own.

Do **not** add `@ApiBearerAuth()` or any other security requirement: the API gateway enforces
auth, the service does not. Leave an existing one alone unless the MR is explicitly about it.

```ts
@ApiTags("Remarks")
@Controller("remarks")
export class RemarksController {}
```

Handler:

```ts
@Get(':id')
@ApiOperation({
  operationId: 'getRemark',            // -> /docs/open-api/remark/get-remark
  summary: 'Get a remark',
  description:
    'Returns a single remark by its numeric id. Returns 404 when the remark does not exist or belongs to another organization.',
})
@ApiParam({ name: 'id', description: 'Remark id', example: 4821, type: Number })
@ApiOkResponse({ description: 'Remark details' })
@ApiBadRequestResponse({ description: 'Invalid remark id' })
@ApiNotFoundResponse({ description: 'Remark not found' })
async findOne(@Param('id', ParseIntPipe) id: number): Promise<ApiResponse<Remark>> {}
```

Query parameters - one decorator each; prefer decorating a shared query DTO with
`@ApiPropertyOptional` when operations share filters:

```ts
@ApiQuery({ name: 'page', required: false, type: Number, description: 'Page number', example: 1, schema: { default: 1, minimum: 1 } })
@ApiQuery({ name: 'limit', required: false, type: Number, description: 'Page size', example: 50, schema: { default: 50, minimum: 1 } })
@ApiQuery({ name: 'requestType', required: false, type: String, description: 'Filter by the business object type a remark is attached to', example: 'loan' })
```

Request body - the DTO is the schema; `@ApiProperty` is what makes it readable:

```ts
@ApiProperty({
  description: 'Remark text as typed by the operator',
  example: 'Customer requested additional review for this application.',
  maxLength: 10_000,
})
@IsString() @IsNotEmpty() @MaxLength(10_000)
context: string;

@ApiPropertyOptional({ description: 'Branch the remark belongs to', example: 10, minimum: 1 })
branch?: number;
```

Responses - use the status codes the handler actually returns (a handler returning `200` with a
message body is `@ApiOkResponse`, not `@ApiNoContentResponse`) with `@ApiCreatedResponse`,
`@ApiOkResponse`, `@ApiBadRequestResponse`, `@ApiNotFoundResponse`, `@ApiForbiddenResponse`,
`@ApiConflictResponse`. For the success schema, climb the Response Schema Ladder below.

## The Response Schema Ladder

Work down until a rung holds. Never skip to rung 4 out of laziness, never go above rung 3 out of
ambition. Same ladder as Quarkus - the goal is that a reader cannot tell the stacks apart.

1. **Typed response DTO exists**: annotate every field with `@ApiProperty(description, example)`
   and declare it - `@ApiOkResponse({ type: RemarkDto })`. Nest does not infer return types here,
   so the `type:` is what makes the schema appear.
2. **Fixed row shape defined by a field catalog or SQL projection** (report `*Fields` maps,
   `SELECT` column lists): create a row DTO mirroring the catalog exactly - property names are the
   wire names (`@ApiProperty({ name: 'request_id' })` where the wire is snake_case), honest types
   (counts -> `number`, money/rates -> string/BigDecimal-equivalent), and document the page
   envelope fields separately.
3. **Dynamic payload with stable documented keys** (catalog-driven projections): keep the generic
   schema and put the shape in the `@ApiOperation.description` - list the stable system columns
   explicitly, state that remaining fields are catalog-driven, and name the endpoint where the
   caller can discover them. Projection semantics (all fields when omitted, `400` on unknown
   names) belong here too.
4. **Free-form** (structure instance ingest, form submissions): generic schema + one realistic
   example + description pointing at the structure's field catalog.

For all rungs, responses are **description-only status tables** for the codes the handler really returns.
Never fake a success schema. `ApiResponse<T>` / `ApiPageResponse<T>` from
`@and/nest-common` carry no `@ApiProperty` metadata and use private fields, and drizzle row types
(`typeof remarks.$inferSelect`) exist only at compile time - throwing either at `type:` renders an
empty schema, which is worse than a description. If the envelope must be typed, mirror it with a
runtime DTO plus `@ApiExtraModels` + `allOf`/`getSchemaPath`; otherwise declare the inner DTO and
describe the envelope in prose.

### Typing success schemas is the default, not an extra

Description-only success responses are the **exception** for genuinely dynamic payloads (see rung 4),
not the norm. For every operation whose success body has a fixed shape, attach a schema. Do this in
the same pass as the summary/description/param annotations - do not wait for someone to ask:

```ts
// Reuse the request DTO as the response schema when the wire shape matches
// (Formio form doc ~= FormDto, Formio submission ~= SubmissionDto):
@ApiOkResponse({ description: 'Form definition', type: FormDto })

// Arrays (list endpoints):
@ApiOkResponse({ description: 'Array of submissions', schema: { type: 'array', items: { $ref: '#/components/schemas/SubmissionDto' } } })

// Keyed maps (response object keyed by caller input):
@ApiOkResponse({
  description: 'Object keyed by each input value; `null` when no revision exists for the request',
  schema: { type: 'object', additionalProperties: { $ref: '#/components/schemas/SubmissionDto' } },
})
// Nullability that additionalProperties cannot express goes in the description.

// Envelope wrapper around an existing DTO: inline schema with a raw $ref
// (safe when the DTO already appears in components via a request body):
@ApiOkResponse({
  description: 'Array of visible form definitions with unscoped keys',
  schema: {
    type: 'object',
    properties: {
      message: { type: 'string', example: 'Successfully fetched form paths' },
      response: { type: 'array', items: { $ref: '#/components/schemas/FormDto' } },
    },
  },
})

// Tiny fixed bodies (service-info root, plain string returns): inline schema, no DTO class:
@ApiOkResponse({ description: 'Caller has the required permission', schema: { type: 'string', example: 'HELLO' } })
```

Rules:

- **Raw `$ref: '#/components/schemas/X'` strings** are fine when X already appears in `components`
  (any request-body use registers it). Otherwise use `@ApiExtraModels(X)` + `getSchemaPath(X)`.
- **Augmented responses** (submission + `returnedFields`/`returnedReason`): subclass the base DTO and
  decorate only the added fields - inherited `@ApiProperty` metadata carries over.
- **New response DTOs** (revision docs, deref envelopes, catalog rows) live in one shared file, e.g.
  `src/middleware/dto/response/response.dtos.ts`, and mirror the wire shape field-by-field with
  honest types and examples - same quality bar as request DTOs.
- **Keep the description even when a schema is present** - the status table still needs it.
- **Leave description-only** only when the body is a dynamic multi-step proxy payload with no fixed
  shape (e.g. a tenant-registration call that returns whatever the downstream created). Say why in
  the description so a reviewer does not "fix" it.

## Quality bar

**Summaries** - imperative verb phrase, sentence case, no trailing period ("Create a remark",
"List remarks"). <= 60 chars: it is a sidebar label. Name the business action, not the transport
("Submit a loan application", not "Post loan application"). Never repeat the method, path,
controller name, or the words "endpoint"/"API". Never leave `<Controller>_<method>` in place.

**Descriptions** - 1-3 sentences on what the caller gets plus behaviour they cannot infer from the
path. The first line is the meta description, so it must stand alone. Cover when true and
non-obvious: tenancy/scoping, side effects (audit, notifications, downstream calls), idempotency,
ordering, pagination and filter semantics, soft vs hard delete, server-derived vs accepted fields.
State the error contract in words ("Returns 404 when ... belongs to another organization").
Markdown is supported (**bold**, `code`, lists); keep it short. No design docs, ticket links,
stack traces, or prose restating the parameter table.

**Tags** - one concern per controller, plural noun, Title Case (`Remarks`,
`Provider Configurations`). Stable across releases; they are the sidebar groups. Give each tag the
same description string everywhere it is used (the spec merges by name - first wins silently), via
`DocumentBuilder.addTag(name, description)`. Never tag by implementation layer (`V2`, `Internal`,
controller class name).

**Operation ids** - `operationId` is the doc id and URL slug, so leave the generated
`<Controller>_<method>` and the URL publishes the leak (`remarks-controller-create`) - a visible
stack tell. Set `operationId` explicitly, camelCase verb+noun (`createRemark`, `listRemarks`), so
the slug matches the human summary the way Quarkus's summary-derived slug does. Changing an
existing `operationId` changes published doc URLs: do it deliberately, once, and call it out as
breaking for doc consumers in the MR.

**Request bodies** - every field decorated with `description` and a realistic `example`
(`APP-12345`, not `string`); mirror the validators (`maxLength`, `minimum`, `maximum`, `default`,
`enum`, `format`); enums via `@ApiProperty({ enum: Scope, enumName: 'Scope' })`; nested/array types
get their own decorated class, never `object`/`any`; never document a field the handler ignores,
never omit a required one; do not present server-derived fields (`organization`, `createdBy`, audit
timestamps) as request input.

**Query and path params** - every parameter gets a `description`, plus `example` where format
matters. For list endpoints use the shared `ListQueryDto` (`page` default 1, `limit` default 50,
`sort`) rather than a local copy, and document the params the handler really reads, including its
defaults and any cap - do not state a default the code does not apply. Filters state what the value
matches and whether it is exact or partial. Path params describe the identifier and match the pipe
(`ParseIntPipe`, `ParseUUIDPipe`) so the documented type is the real type. Never document a
parameter the handler does not read, and never leave a live `@Query` param undocumented.

**Language** - English, third person, present tense, active voice; concise and factual, no
marketing. Use business domain terms (`loan application`, `branch`), not table or column names
(`request_composite_idx`), and never leak TypeScript class names into prose. No PII, tokens, or
internal hostnames in examples.

**Do not document** health/liveness/readiness routes (infrastructure, filtered out by the gateway
filter anyway - leave them bare), internal-only endpoints (annotating them onto a consumer gateway
does not make them public; exposure governs that), or aspirational/fake responses - if the handler
returns an empty `201`, document that and fix the handler separately.

Before/after:

```ts
// BEFORE - renders as "RemarksController_create" in both portals
@Post()
async create(@Body() createRemarkDto: CreateRemarkDto): Promise<ApiResponse<Remark>> {}

// AFTER
@Post()
@ApiOperation({
  operationId: 'createRemark',
  summary: 'Create a remark',
  description:
    'Creates a remark attached to a business record identified by `requestType` and `requestId`. ' +
    'The author and organization are taken from the authenticated caller.',
})
@ApiCreatedResponse({ description: 'Remark created' })
@ApiBadRequestResponse({ description: 'Invalid input data' })
async create(@Body() createRemarkDto: CreateRemarkDto): Promise<ApiResponse<Remark>> {}
```

## Traps

- **Build time, not runtime.** Env vars in `.gitlab/*.yaml` (`SWAGGER_TITLE`,
  `OPENAPI_DEFAULT_EXPOSE_TO_GATEWAYS`, ...) reach the pod, never the artifact. Anything that must
  appear in the docs belongs in code, in the Dockerfile builder stage, or in `main.ts`.
- **`info.title` is usually the npm package name** (`remark`, not `Remark Service`) because
  `SWAGGER_TITLE` is unset at build - that is what the service card shows.
- **Doc gaps from an old `@and/nest-common`.** Below 1.3.6 the shared `ListQueryDto` params render
  bare and there is no `tags` option. Bump the dependency (`>= 1.3.6`), do not fork the DTO into a
  local copy and do not hand-roll a `DocumentBuilder` just to add tag descriptions.
- **Auth is the gateway's concern, not the service's.** No security requirement belongs in the
  spec; do not add `@ApiBearerAuth()` and do not "fix" an absent one in a docs MR.
- **Tag grouping is not wired in the portals today** (autogenerated sidebar, not the plugin's
  generated `sidebar.ts`). Tags remain the right place for grouping; do not promise a visual group
  in the MR.
- **`openapi.yaml` is a snapshot.** Regenerate it with
  `npm run build && npm run openapi:generate`; never hand-edit it.
- **Missing swagger imports fail at spec generation, not at build.** SWC happily compiles a file
  referencing an unimported `@nestjs/swagger` decorator; `openapi:generate` then dies with
  `ReferenceError: ApiXxxResponse is not defined`. When `openapi.json`'s mtime does not move after a
  generate run, check the generate output before trusting the verification script.
- **`@ExposeToGateways` is a separate concern** - it drives `openapi-convertor` ->
  `apisix.routes` -> `ApisixRoute`, i.e. whether the service appears in borrower-doc / openapi-doc
  at all. Do not change exposure as a side effect of a docs change, and do not use it to hide an
  endpoint from docs.

## Procedure

One repo per MR. Work one controller at a time.

1. Prerequisite check above. No artifact -> report and stop.
2. Build the spec and inventory it: which operations lack summary/description, which titles are
   `<Controller>_<method>` junk, which query params render bare, which 200 schemas are empty.
   (`grep -n '@Get\|@Post\|@Put\|@Patch\|@Delete\|@ApiOperation\|@ApiTags' src/**/*.controller.ts`; skip `HealthController`.)
3. Assign `@ApiTags` names + one description string per tag for every touched class up front.
4. Read each handler, its DTOs and the service before writing prose. Descriptions must match real
   behaviour: status codes returned, filters applied, tenancy enforced, params accepted-but-ignored.
   Never guess.
5. Annotate: class `@ApiTags`, then per handler `@ApiOperation` (with `operationId`), params, DTO fields, response decorators with success schemas for every fixed-shape body (see "Typing success schemas" above), and the Response Schema Ladder.
6. `npm run build && npm run openapi:generate`.
7. Verify (below) - this is the point of the work.
8. `npm run lint`, `npm run format:check`, unit tests (verify the script names in `package.json`).
9. MR: one repo, conventional commit `docs(<scope>): ...`; describe what renders differently, flag
   any `operationId`/summary URL changes, and report behaviour discovered that contradicts the old
   docs.

## Verification

```bash
# 1. Regenerate
npm run build && npm run openapi:generate

# 2. Full-coverage check: operations AND query params AND DTO schemas AND response schemas
python3 - <<'PY'
import yaml
d = yaml.safe_load(open('openapi.yaml'))
miss_ops, miss_q, q_total, miss_schema, schema_total = [], 0, 0, 0, 0
for p, item in d['paths'].items():
    if 'health' in p:
        continue
    for m, op in item.items():
        if not isinstance(op, dict) or 'responses' not in op:
            continue
        bad = ([] if op.get('summary') else ['summary']) + ([] if op.get('description') else ['description'])
        if bad:
            miss_ops.append(f"{m.upper()} {p} {bad}")
        for q in op.get('parameters', []):
            if q.get('in') == 'query':
                q_total += 1
                if not q.get('description'):
                    miss_q += 1
                    miss_ops.append(f"param {q.get('name')} on {m.upper()} {p}")
        code = op.get('responses', {}).get('200') or op.get('responses', {}).get('201') or {}
        if code.get('description') and not code.get('content'):
            miss_schema += 1
            miss_ops.append(f"no success schema on {m.upper()} {p} (description-only - justify or type it)")
        if code.get('content'):
            schema_total += 1
s = d.get('components', {}).get('schemas', {})
bare = [k for k, v in s.items()
        if isinstance(v, dict) and v.get('properties')
        and not any(isinstance(pv, dict) and pv.get('description') for pv in v['properties'].values())]
print(f"ops incomplete: {len(miss_ops)}"); print('\n'.join(miss_ops) or 'ALL COMPLETE')
print(f"query params undocumented: {miss_q}/{q_total}")
print(f"success responses without schema: {miss_schema} (typed: {schema_total})")
print(f"schemas with zero field descriptions: {len(bare)}", bare or '')
PY

# 2b. Spot-check a success schema via `content`, not the response object itself:
# responses.<code>.content['application/json'].schema is where type:/schema: render.
# A top-level `schema` key on the response means the annotation did not take effect.

# 3. Spot-check one endpoint end to end: summary, operationId, params, 200 schema
python3 -c "
import json, yaml
d = yaml.safe_load(open('openapi.yaml'))
p, item = next(iter(d['paths'].items()))
print(p, json.dumps(list(item.values())[0], indent=1)[:800])
"

# 4. After merge: confirm what the portals actually consume
glab api "projects/alpha%2Fback-end%2F<repo>/jobs/artifacts/dev/raw/openapi.yaml?job=extract-openapi" | head -40

# 5. Optional: render locally in a portal (collector needs OPENAPI_GITLAB_TOKEN)
LOOMS_ENV=dev npm run swagger-collector && npx docusaurus gen-api-docs <service-id>
```

Spot-check `docs/open-api/<service>/<operation-id>.api.mdx`: `title:` and `sidebar_label:` must be
the summary, not the operationId.

## Review checklist

- [ ] Repo publishes the spec artifact, or the gap is reported.
- [ ] Every non-health operation has a <= 60 char imperative `summary`.
- [ ] Every operation has a `description` whose first line stands alone, matching verified behaviour.
- [ ] `@ApiTags` present: business-oriented, Title Case, stable; no `<Controller>_<method>` visible as title or sidebar label.
- [ ] Tag descriptions present and identical for a shared tag name.
- [ ] `operationId` explicit and human-readable; any slug change flagged as breaking doc URLs.
- [ ] No security requirement added or changed - the gateway enforces auth, not the service.
- [ ] All query and path params documented, with `example` where format matters.
- [ ] `@and/nest-common` pinned at >= 1.3.6, so shared list params and tag descriptions render.
- [ ] List endpoints use the shared `ListQueryDto`, with real defaults/caps documented (no forked copy, no invented default).
- [ ] Every request DTO field has `description` + realistic `example`; enums list their values; nested types are decorated classes.
- [ ] Server-derived fields are not documented as request input.
- [ ] Response decorators use the status codes the handler really returns.
- [ ] Every fixed-shape success response has a `type:`/`schema:` on its `@ApiOkResponse`/`@ApiCreatedResponse`; description-only ones are justified in the description.
- [ ] Response `$ref`s resolve (DTO appears in `components`; otherwise `@ApiExtraModels` + `getSchemaPath`).
- [ ] Response Schema Ladder applied: typed where fixed, catalog-mirrored rows where a catalog exists, honest-generic + prose for dynamic payloads.
- [ ] No `type:` pointing at a non-runtime class (`ApiResponse<T>`, drizzle `$inferSelect`, interfaces, `object`/`any`).
- [ ] No PII, secrets, internal hostnames, table/column names, or ticket links in docs.
- [ ] `openapi.yaml` regenerated; lint, format and tests pass.
- [ ] `@ExposeToGateways` unchanged unless the MR is explicitly about exposure.
