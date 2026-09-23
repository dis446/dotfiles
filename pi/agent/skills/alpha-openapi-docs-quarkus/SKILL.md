---
name: alpha-openapi-docs-quarkus
description: "Use when documenting or reviewing the HTTP API of any Alpha Quarkus service: @Operation summaries/descriptions, @Schema request/response fields, @Parameter, @Tag grouping - so borrower-doc and openapi-doc render enterprise-quality API reference. Sister skill to alpha-openapi-docs-nestjs."
---

# Alpha OpenAPI Documentation for Quarkus

Use for any Alpha Quarkus service. The annotation lives in the service's JAX-RS resources;
the published docs are a downstream artifact. Improving docs means improving service
annotations - never the portal repo, never the generated `target/generated/openapi.yaml`.

Target quality (the bar, all four at once):

1. **Every operation** has a human `summary` + `description` - no camelCase-derived titles.
2. **Every query/path param** has a description (and an example where format matters).
3. **Every request/response DTO field** has a `@Schema` description + realistic example.
4. **Response schemas are typed where the shape is fixed**, honestly generic where it is
   dynamic (see the Response Schema Ladder).

Without `@Operation`, Quarkus emits a Title-Cased split of the Java method name
(`canWrite` -> "Can Write") and tags default to the JAX-RS class name - both unusable.

## Cross-stack parity contract

Alpha runs two stacks (NestJS, Quarkus). A reader of the published docs must not be able to tell
which stack produced a service. Both skills enforce the same contract; only the annotation
mechanism differs. Sister skill: `alpha-openapi-docs-nestjs`.

| contract | NestJS | Quarkus |
|---|---|---|
| title = human imperative summary, <= 60 chars | `@ApiOperation({ summary })` | `@Operation(summary = ...)` |
| body = description, first line stands alone | `@ApiOperation({ description })` | `@Operation(description = ...)` |
| sidebar group = business noun, Title Case, stable | `@ApiTags` + `.addTag(name, description)` | `@Tag(name, description)` |
| doc URL slug is human-readable | explicit `operationId` (never `<Controller>_<method>`) | derived from `summary` |
| every param documented | `@ApiQuery` / `@ApiParam` | `@Parameter` |
| shared list params documented | `ListQueryDto` (`@and/nest-common` >= 1.3.6) | `ListQuery` / `ListQueryWithFilter` (quarkus-common >= 1.4.12) |
| every DTO field documented | `@ApiProperty(description, example)` | `@Schema(description, example)` |
| response schema honesty | Response Schema Ladder | Response Schema Ladder |
| auth in the generated spec | none - the API gateway enforces auth, not the service | same |
| exposure untouched by a docs MR | `@ExposeToGateways` | `@ExposeToApiGateways` |

Stack tells that must never appear in a published spec: `<Controller>_<method>` titles (Nest),
Title-Cased camelCase method names or JAX-RS class-name tags (Quarkus), undocumented shared
pagination params, an invented security requirement, and empty `JsonNode` / `ApiResponse*`
response schemas where a fixed shape exists.

## Consumer chain

Know this chain; it decides where the work goes.

```
@Operation / @Schema / @Tag / @ExposeToApiGateways / @RequiredPermissions
  |  quarkus-smallrye-openapi + quarkus-common CommonLibraryOpenApiFilter (BUILD stage)
  v
target/generated/openapi.yaml   written by `./mvnw package` (OpenAPI 3.1)
  v
docker/Dockerfile               COPY -> /deployments/generated/openapi.yaml
  |                             (.dockerignore must whitelist !target/generated/openapi.yaml)
  v
CI extract-openapi              docker cp $OPENAPI_PATH -> openapi.yaml artifact
  |                             quarkus-maven-auto-devops.gitlab-ci.yml template
  |                             (transitively includes argocd-auto-devops-release.gitlab-ci.yaml)
  v
openapi-convertor               auto-deploy-apisix-helm: x-expose-to-gateways -> APISIX routes
  |                             MISSING FILE = "skipping APISIX values generation"
  |                             = chart ships no routes = gateway 404
  v
portal collector                swagger-collector/ in borrower-doc | openapi-doc:
  |                             fetch artifact -> keep routes matching target gateway
  |                             -> strip x-* -> rewrite `servers` to https://<gwHost><BASE_PATH>
  v
swaggers/<service>.yaml -> docusaurus-plugin-openapi-docs -> docs/open-api/<service>/*.api.mdx
```

Consequences: nothing in a portal repo can rename an endpoint; the spec is written at Maven
build time, so pod-runtime env vars never change the artifact; a service whose Dockerfile
does not ship the file loses APISIX routes **and** docs visibility.

### How each spec field renders

| spec field                     | rendered as                                                  | source in Quarkus code                                    |
| ------------------------------ | ------------------------------------------------------------ | --------------------------------------------------------- |
| `operation.summary`            | page title + sidebar label                                   | `@Operation(summary = ...)`                                |
| `operation.description`        | page body (markdown); **first line** is the meta description | `@Operation(description = ...)`                            |
| `operation.tags`               | sidebar grouping (`groupPathsBy: "tag"`)                     | `@Tag(name = ...)` class level                             |
| doc id / URL slug              | `kebabCase(operationId)` else `kebabCase(summary)`           | Quarkus emits **no operationId** -> summary is the slug    |
| `operation.parameters`         | parameter tables                                             | `@Parameter` on path/query params **and on BeanParam fields** |
| `requestBody...schema`         | request body table + generated sample                        | DTO fields + `@Schema` per field                           |
| `responses.<code>`             | status-code table                                            | `@APIResponse` / `@APIResponses`                           |
| `x-expose-to-gateways`         | APISIX routes - **stripped from docs**                       | `@ExposeToApiGateways` (quarkus-common)                    |
| `x-zudoku-badges`, permissions | badges / `### Permissions required` body section             | `@RequiredPermissions`, `@PublicAccess`, `@AttachBranchHeaders` |
| `info.title`                   | service card                                                 | `quarkus.application.name`                                 |
| `info.description`             | landing page body (markdown)                                 | `quarkus.smallrye-openapi.info-description`                |

## Prerequisites: can this repo be documented at all?

The spec reaches the portals and APISIX only if all hold:

1. `pom.xml` depends on `mn.and:quarkus-common` (brings `quarkus-smallrye-openapi` +
   `CommonLibraryOpenApiFilter`; never add quarkus-smallrye-openapi directly).
2. The Dockerfile named by `AUTO_DEVOPS_BUILD_IMAGE_DOCKERFILE` (repo `.gitlab-ci.yml`)
   copies `target/generated/openapi.yaml` into the runtime image, and `.dockerignore`
   whitelists `!target/generated/openapi.yaml`.
3. `.gitlab-ci.yml` includes `quarkus-maven-auto-devops.gitlab-ci.yml` (provides
   `extract-openapi` and the default `OPENAPI_PATH: /deployments/generated/openapi.yaml`)
   and sets `BASE_PATH`.
4. A local build emits the schema: `./mvnw package -DskipTests && test -f target/generated/openapi.yaml`.
5. **Shared pagination params render documented.** quarkus-common >= 1.4.12 annotates the
   shared `ListQuery`/`ListQueryWithFilter` BeanParams (`page`, `limit`, `sort`, `filter`).
   If the service pins an older version and those params render bare, the fix is a
   quarkus-common bump MR - bump **all** modules together (quarkus-parent, quarkus-build-config
   including the spotless formatter-provider reference and the `quarkus-common`
   dependencyManagement pin, and common-lib) and have the service pin the new version.

Check per repo:

```bash
R=back-end/<repo>
grep -n "quarkus-common" "$R/pom.xml"
grep -n "AUTO_DEVOPS_BUILD_IMAGE_DOCKERFILE\|BASE_PATH\|quarkus-maven-auto-devops" "$R/.gitlab-ci.yml"
grep -n "generated/openapi" "$R"/docker/*Dockerfile* "$R"/Dockerfile* 2>/dev/null
grep -n "generated" "$R/.dockerignore"
cd "$R" && ./mvnw package -DskipTests && test -f target/generated/openapi.yaml
# then verify param rendering in the spec (see Verification script)
```

Discover Quarkus services: `find back-end -maxdepth 2 -name pom.xml` (under `~/Code/and/alpha`).

If a check fails, that is a CI/CD or dependency gap (see `alpha-ci-cd-expert`) with
production impact, not just a docs gap - report it, never skip silently. After merge,
confirm what the portals consume:

```bash
glab api "projects/alpha%2Fback-end%2F<repo>/jobs/artifacts/dev/raw/openapi.yaml?job=extract-openapi" | head -40
```

## Reference implementations

- `task-management` `src/main/java/mn/and/taskmanagement/api/*.java` + `api/dto/**` - the
  house style: class-level `@Tag` (plus its pre-existing `@SecuritySchemes`, which is not a docs
  requirement - auth is the gateway's), per-handler `@Operation`,
  `@APIResponses`, `@Parameter`, DTO fields with `@Schema(description, example)`.
- Any service whose docs already render at the bar (spec has zero missing
  summaries/descriptions/param docs) - copy its tone over the abstract rules below.

## Annotation toolkit

```java
import org.eclipse.microprofile.openapi.annotations.Operation;
import org.eclipse.microprofile.openapi.annotations.enums.ParameterIn;
import org.eclipse.microprofile.openapi.annotations.media.Content;
import org.eclipse.microprofile.openapi.annotations.media.Schema;
import org.eclipse.microprofile.openapi.annotations.parameters.Parameter;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponse;
import org.eclipse.microprofile.openapi.annotations.responses.APIResponses;
import org.eclipse.microprofile.openapi.annotations.tags.Tag;
```

Class level - `@Tag` is the sidebar group: business noun, Title Case, stable
("Loan Applications", "Structure Catalog"). Rules:

- `@Tag` is **not** inherited; `@Operation` is **not** inherited - every handler needs its
  own.
- If several classes share a tag name, their tag **description strings must be identical**
  (the spec merges tags by name; first wins silently).
- Assign tag names up front for the whole surface before annotating; do not invent one per
  class on the fly.

```java
@Path("/loan-applications")
@Tag(name = "Loan Applications", description = "Loan-application views, decisions, and related records")
public class LoanApplicationResource {

  @GET
  @Path("/{requestId}")
  @Operation(summary = "Get a loan application", description = ""
      + "Returns the application summary for the given `requestId`, scoped to the caller's "
      + "organization and branch access. Returns 404 when the application does not exist "
      + "or the caller cannot see it.")
  @APIResponses({
      @APIResponse(responseCode = "200", description = "Loan application retrieved"),
      @APIResponse(responseCode = "404", description = "Loan application not found"),
  })
  public ApiResponse<JsonNode> getLoanApplication(
      @Parameter(in = ParameterIn.PATH, description = "Loan application request id",
          required = true, example = "9b7d1e5c-0f2a-4c3d-8e1b-2a6f9c4d7e10")
      @PathParam("requestId") UUID requestId,
      @Parameter(description = "Fields to return; all projection fields when omitted",
          example = "[\"request_id\", \"main_status\"]")
      @QueryParam("projection") List<String> projection) {}
```

Params:

- Every `@PathParam` and explicit `@QueryParam` gets `@Parameter(description, example)`;
  path params get `in = ParameterIn.PATH` and a format example (uuid).
- **BeanParam classes owned by the service repo**: annotate the fields directly
  (`@Parameter`/`@Schema` on `@QueryParam` fields) - they render like plain params.
- BeanParam classes from quarkus-common (`ListQuery`, `ListQueryWithFilter`: `page`,
  `limit`, `sort`, `filter`): already annotated since 1.4.12 - verify, do not re-annotate.
- Never annotate a param the handler ignores as if it worked; if it is accepted but
  ignored, say so in the description.

Request body - the DTO is the schema; `@Schema` is what makes it readable. Quarkus picks up
`@NotNull`/`@Size`/`@NotBlank` constraints automatically; you supply description + example:

```java
@Schema(description = "User uuid of the assignee", required = true,
    example = "3f6c2e1a-9b4d-4e8f-a2c1-5d7e9b0a1c2d")
@NotBlank
private String assignee;

@Schema(description = "Informational source label; defaults to `manual` when omitted",
    example = "task")
private String source;
```

## The Response Schema Ladder

Work down until a rung holds. Never skip to rung 4 out of laziness, never go above rung 3
out of ambition:

1. **Typed DTO exists** (handler returns a real response class): annotate every field with
   `@Schema(description, example)`. Done.
2. **Fixed row shape defined by a field catalog or SQL projection** (report `*ReportFields`
   classes, `SELECT` column lists): create a row DTO mirroring the catalog exactly - field
   names = wire output names (respect snake_case via `@JsonProperty`), honest types
   (counts -> `Long`, money/rates -> `BigDecimal`), wire row + page-envelope schemas via
   `@APIResponse(responseCode = "200", content = @Content(schema = @Schema(implementation = Row.class)))`.
   Document extra envelope fields (`filterOptions`) in a page DTO. Keep a note that these
   classes mirror SQL and can drift.
3. **Dynamic payload with stable documented keys** (catalog-driven projections): keep the
   generic schema and put the shape in the `@Operation` description - list the stable
   system columns explicitly and state that remaining fields are catalog-driven, plus
   where the caller can discover them (catalog/fields endpoints). Projection semantics
   (all fields when omitted, 400 on unknown names) belong here too.
4. **Free-form** (structure instance ingest, form submissions): generic schema + one
   realistic example + description pointing at the structure's field catalog.

For all rungs: responses are **description-only status tables** for the codes the handler
really returns (`400` from `BadRequestException`, `404` from `NotFoundException`, ...).
Never fake schemas for generic wrappers (`ApiResponse<T>` / `ApiPageResponse<JsonNode>`
render as empty `JsonNode` schemas - that is the signal to climb the ladder, not to invent
an `allOf`).

## Quality bar

**Summaries** - imperative verb phrase, sentence case, no trailing period ("Assign users to
an application", "List my loan applications"). <= 60 chars: it is a sidebar label **and**,
in Quarkus, the doc URL slug (see Traps). Name the business action, not the transport.

**Descriptions** - 1-3 sentences; the first line must stand alone (it becomes the meta
description). Cover what a caller cannot infer from the path: tenancy/branch/ownership
scoping, soft vs hard semantics, idempotency, audit side effects, pagination defaults and
caps, and the error contract in words ("Returns 404 when ... belongs to another borrower";
"`can_write` is `false` rather than 404 when the application is missing"). Read the service
method before writing - descriptions must match verified behavior, never guess. Markdown is
supported; keep it short. The `### Permissions required` section is appended automatically
by the shared filter - do not duplicate it.

**Tags** - business noun, Title Case, stable across releases. Replace class-name tags
("Loan Application Sales Resource", "T 24 Loan Lookup Resource"). Never tag by
implementation layer (`Internal`, `V2`).

**Operation ids** - SmallRye OpenAPI emits no `operationId` by default, so the doc id and
URL slug derive from the **summary**. Renaming a summary changes published doc URLs - flag
it as breaking for doc consumers in the MR.

**Request bodies** - every field gets `description` + a realistic `example` (real-format
uuid, `APP-12345`, `10` - never `string`); enums list their values; nested lists get their
own decorated class. Do not document a field the handler ignores; do not present
server-derived fields (organization, actor stamps, audit timestamps) as request input.

**Language** - English, third person, present tense, active voice; concise and factual.
Business domain terms, not table/column names. No PII, tokens, internal hostnames, or
ticket links in examples.

**Do not annotate** Quarkus health endpoints (`/q/health*` - not in the spec), or
aspirational behavior - document what the handler does.

## Traps

- **Build time, not runtime.** The spec is written by `./mvnw package`. Runtime env vars in
  `.gitlab-ci.yml` reach the pod, never the artifact. Regenerate with
  `./mvnw package -DskipTests`; the file is build output - never hand-edit.
- **Summary renames break doc URLs.** No operationId -> kebabCase(summary) is the slug.
  Renames are legit when replacing junk titles, but call the URL change out in the MR.
- **Multi-line descriptions.** Java string literals cannot contain newlines: write
  `description = ""` then continuation `+ "..."` lines. `description = "` + newline is a
  compile error.
- **MP OpenAPI 4.1 API.** `@Schema(required = true)` - `requiredMode` does not exist in
  `microprofile-openapi-api` 4.x and fails the build.
- **`@Schema.example` is a String.** `example = 1` fails the build; quote it: `example = "1"`.
- **`@JsonNaming(SnakeCaseStrategy)` / `@JsonProperty`.** Wire property names may differ
  from Java field names; examples must match the wire format, and row-DTO property names
  must be the SQL output names. The schema renders renamed properties automatically.
- **Shared tag names.** Identical description string in every class that uses the tag.
- **BeanParam location decides the fix.** Service-owned BeanParam -> annotate fields in
  this repo. quarkus-common BeanParam -> verify >= 1.4.12; if older, quarkus-common bump
  MR (all modules), then pin the version in the service.
- **`@ExposeToApiGateways` unchanged.** A bare `@ExposeToApiGateways()` falls through to
  `mn.and.openapi.default-expose-to-gateways` - usually all three gateways. Exposure is a
  routing concern, never a side effect of a docs MR.
- **Lombok DTOs render via Jandex** - `@Data` fields appear as properties; only the
  descriptions/examples are missing without `@Schema`. Adding `@Schema` is enough; no
  runtime DTO rework needed.

## Procedure

One repo per MR. For a small service one MR; for a large one group by surface
(borrower surface, admin surface, reporting, catalog) - highest-traffic / junk-title
endpoints first.

1. Prerequisite check above, then build the spec and inventory it:
   which operations lack summary/description, which titles are camelCase junk, which tags
   are class names, which query params render bare, which 200 schemas are empty
   `JsonNode`/`ApiResponse*` wrappers.
2. Assign `@Tag` names + identical description strings for every touched class up front.
3. Read each handler, its DTOs and the service methods before writing prose. Verify
   scoping, fencing, 404-vs-false semantics, idempotency, audit calls, accepted-but-ignored
   params. Never guess.
4. Annotate: `@Tag` on the class, then per handler `@Operation` (+ `@Parameter` +
   `@APIResponse(s)`), then `@Schema` on DTO fields, applying the Response Schema Ladder.
5. `./mvnw spotless:apply` (Eclipse formatter; import order java/javax/jakarta/org/com).
6. Regenerate and verify - this is the point of the work (below).
7. `./mvnw test` - full suite, 0 failures.
8. MR: conventional commit `docs(<scope>): ...`; describe what renders differently, flag
   summary-driven URL changes, list any dependency (quarkus-common) merge-order needs, and
   report behavior discovered that contradicts the old docs. No endpoint/auth changes -> no
   Bruno/seed updates needed.

## Verification

```bash
# 1. Regenerate
./mvnw package -DskipTests

# 2. Full-coverage check: operations AND query params AND DTO schemas
python3 - <<'PY'
import yaml
d = yaml.safe_load(open('target/generated/openapi.yaml'))
miss_ops, miss_q, q_total = [], 0, 0
for p, item in d['paths'].items():
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
s = d.get('components', {}).get('schemas', {})
bare = [k for k, v in s.items()
        if isinstance(v, dict) and v.get('properties')
        and not any(isinstance(pv, dict) and pv.get('description') for pv in v['properties'].values())]
print(f"ops incomplete: {len(miss_ops)}"); print('\n'.join(miss_ops) or 'ALL COMPLETE')
print(f"query params undocumented: {miss_q}/{q_total}")
print(f"schemas with zero field descriptions: {len(bare)}", bare or '')
PY

# 3. Spot-check one endpoint end to end: summary, params, 200 schema
python3 -c "
import yaml, json
d = yaml.safe_load(open('target/generated/openapi.yaml'))
op = d['paths'][list(d['paths'])[0]]
print(json.dumps(list(op.values())[0], indent=1)[:800])
"

# 4. Full suite
./mvnw test

# 5. After merge: confirm what the portals actually consume
glab api "projects/alpha%2Fback-end%2F<repo>/jobs/artifacts/dev/raw/openapi.yaml?job=extract-openapi" | head -40
```

## Review checklist

- [ ] Repo ships the spec artifact (Dockerfile COPY + `.dockerignore` whitelist), or the gap is reported.
- [ ] Shared `page`/`limit`/`sort`/`filter` params render documented (quarkus-common >= 1.4.12 pinned).
- [ ] Every operation has a <= 60 char imperative `summary` - no camelCase-derived titles left.
- [ ] Every operation has a `description` whose first line stands alone, matching verified service behavior.
- [ ] Tags are business-oriented Title Case groups with identical description strings; no JAX-RS class-name tags left.
- [ ] Summary renames flagged as breaking doc URLs (no operationId emitted by Quarkus).
- [ ] All path and explicit query params documented; service-owned BeanParam fields annotated; accepted-but-ignored params stated as such.
- [ ] Every request/response DTO field has `description` + realistic wire-format example; enums list values.
- [ ] Response Schema Ladder applied: typed where fixed, catalog-mirrored rows where a catalog exists, honest-generic + prose for per-tenant dynamic payloads; no invented schemas.
- [ ] Server-derived fields are not documented as request input.
- [ ] No security requirement added or changed - the API gateway enforces auth, not the service.
- [ ] No duplicated `### Permissions required` section (auto-appended by quarkus-common).
- [ ] `@ExposeToApiGateways` unchanged unless the MR is explicitly about exposure.
- [ ] `./mvnw spotless:check`, full `./mvnw test` pass; spec regenerated, never hand-edited.
