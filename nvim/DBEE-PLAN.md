# nvim-dbee plan — revised for alpha back-end repos

Goal: add `nvim-dbee` to this Neovim config in way that matches how `/home/ubby/Code/alpha/back-end` actually works.

Main change from original plan: do **not** make every repo maintain a brand-new `.db/dbee.lua` file first. Your repos already expose DB info in several existing places, and many already have JetBrains datasource files. Best plan is **discovery + optional override**, not **manual duplication everywhere**.

---

## What repo survey showed

Your back-end repos are mixed, not one uniform stack:

- **Quarkus / Maven** repos with `application.properties`
  - mostly PostgreSQL: `task-mgmt`, `mdm`, `dealer-mgmt`, `state-mgt`, `logMgmt`, `relation-store`, `call-service`
  - MySQL in `auth`
- **Node / Nest / Drizzle** repos
  - PostgreSQL via `DATABASE_URL` or `POSTGRES_*`: `state-machine`, `rule-engine`, `structure_v2`, `namager`
- **Symfony / PHP** repos
  - MySQL via `DATABASE_URL`: `contract`, `collateral`
- **Multi-DB repos exist**
  - `mdm` has local main Postgres + downstream Postgres + downstream MySQL
- **Local ports are not consistent**
  - common local Postgres ports include `5433`, `7711`, `7712`
  - local MySQL includes `3306`, `7713`
- **Schema matters in several repos**
  - examples: `task-mgmt`, `dealer-mgmt`, `mdm`, `state-machine`, `rule-engine`
- **Env conventions differ by repo**
  - `DB_HOST/DB_PORT/DB_NAME/DB_SCHEMA/DB_USER/DB_PASS`
  - `DB_URL`
  - `DATABASE_URL`
  - `POSTGRES_*`
- **`.envrc` is not current norm**
  - `.env`, `.env.local`, `.env.dist`, `docker-compose*.yml`, and app config files are much more common
- **You already have JetBrains datasource metadata in many repos**
  - several repos contain local `.idea/dataSources.xml`
  - this is valuable because it already reflects how you work today in IntelliJ

Conclusion: one global connection pile is wrong, but one brand-new per-repo config file is also too much manual work.

---

## Revised recommendation

Use this model:

1. **Detect repo root**
2. **Load repo DB connections from existing repo files first**
3. **Allow optional repo-local Neovim overrides**
4. **Fallback to global personal defaults**
5. **Treat SSH tunnels as external, but make tunnel-first connections easy**

This gives:

- low maintenance
- better fit for mixed stacks
- reuse of your existing IntelliJ/repo metadata
- no need to hand-write config for every repo before it works

---

## Recommended discovery order

When Neovim enters a repo, load connections in this order:

1. `repo/.nvim/dbee.local.lua`
   - personal overrides
   - untracked
   - can point remote DBs at localhost tunnel ports
2. `repo/.nvim/dbee.lua`
   - optional shared repo config
   - no secrets
   - use only when auto-discovery is not enough or when repo needs curated labels/groups
3. `repo/.idea/dataSources.xml`
   - import existing JetBrains datasource names + JDBC URLs when present
   - best migration path from IntelliJ workflow
4. framework-specific discovery
   - Quarkus: `application.properties` + `.env` / `.env.local` / `.env.dist`
   - Drizzle/Node: `drizzle.config.ts` + `.env` / `.env.local`
   - Symfony: `.env` + `.env.local` + `DATABASE_URL`
   - Docker Compose: `compose.yml` / `docker-compose*.yml` for local containers
5. global fallback config
   - only for truly shared personal connections

Rule: earlier entries override later ones.

---

## File layout recommendation

Prefer this over `.db/dbee.lua`:

```text
repo/
├── .nvim/
│   ├── dbee.lua         # optional shared repo metadata, no secrets
│   └── dbee.local.lua   # personal overrides, untracked
├── .idea/               # optional JetBrains datasource source
├── .env / .env.local / .env.dist
└── docker-compose*.yml
```

Why `.nvim/` instead of `.db/`:

- clearer that file is editor-specific
- avoids confusion with real DB folders like `db/`, `drizzle/`, `migrations/`
- scales better if you later want other repo-local Neovim settings

`dbee.local.lua` should be ignored via one of:

- global gitignore
- repo `.git/info/exclude`
- repo `.gitignore` if you want team-wide ignore rule

---

## Connection model

Normalized connection object should support:

- `name`
- `type` / engine (`postgres`, `mysql`)
- `url` or `host` + `port` + `database`
- `user`
- `password_env` or env-derived password
- `schema` / `currentSchema` when relevant
- `ssl` / `sslmode`
- `source` (`nvim-local`, `nvim-shared`, `jetbrains`, `quarkus`, `drizzle`, `symfony`, `compose`, `global`)
- `tags` like `local`, `dev`, `test`, `downstream`, `tunnel`

Important: schema support is not optional for your repos.

---

## Discovery rules by repo type

### 1) JetBrains datasource import

Since you currently use IntelliJ database tooling, this should be first-class.

Read `.idea/dataSources.xml` when present and import:

- datasource name
- engine from driver ref / JDBC URL
- JDBC URL
- working dir

Do **not** depend on JetBrains for secrets. Use:

- env vars
- `dbee.local.lua`
- prompt on connect if needed

This lets Neovim start with connections you already maintain in IntelliJ instead of forcing duplicate config.

### 2) Quarkus adapter

Target repos like `task-mgmt`, `mdm`, `dealer-mgmt`, `state-mgt`, `logMgmt`, `relation-store`, `auth`.

Read:

- `src/main/resources/application.properties`
- `.env`
- `.env.local`
- `.env.dist`
- `compose.yml` / `docker-compose*.yml`

Detect patterns like:

- `quarkus.datasource.db-kind=postgresql`
- `quarkus.datasource.db-kind=mysql`
- `quarkus.datasource.jdbc.url=${DB_URL}`
- `jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}?currentSchema=${DB_SCHEMA}`
- `jdbc:mysql://...`

Expected outputs:

- `task-mgmt` → local Postgres connection on repo-defined port, schema-aware
- `auth` → MySQL connection via `DB_URL`
- `mdm` → Postgres connection with schema + optional local stack extras

### 3) Drizzle / Node adapter

Target repos like `state-machine`, `rule-engine`, `structure_v2`, `namager`.

Read:

- `drizzle.config.ts`
- `.env`
- `.env.local`
- `docker-compose*.yml`

Detect patterns like:

- `DATABASE_URL`
- `POSTGRES_HOST`
- `POSTGRES_PORT`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB`
- drizzle `schemaFilter`

Expected outputs:

- `state-machine` → Postgres via `DATABASE_URL`, schema `state_machine`
- `rule-engine` → Postgres via `POSTGRES_*`, schema `rule_engine`, default local port often `6432`/repo-defined

### 4) Symfony adapter

Target repos like `contract`, `collateral`.

Read:

- `.env`
- `.env.local`
- `.env.dev`
- `config/packages/doctrine.yaml`

Detect:

- `DATABASE_URL=mysql://...`
- engine from URL scheme

Expected output:

- one MySQL connection per repo, plus optional local overrides

### 5) Docker Compose local-stack adapter

Use when repo runs database containers locally and app config alone is not enough.

Very useful for:

- `mdm` local stack
- `task-mgmt` local Postgres
- `rule-engine` local Postgres
- any repo with explicit DB service port mapping

Examples from your repos:

- `task-mgmt` local Postgres on host port `5433`
- `mdm` local main Postgres on `7711`
- `mdm` downstream Postgres on `7712`
- `mdm` downstream MySQL on `7713`
- `rule-engine` local Postgres on `5433`

This matters because many of your local DBs are not on default ports.

---

## Naming convention

Use stable names like:

- `task-mgmt/local`
- `task-mgmt/dev`
- `auth/local`
- `mdm/local-main`
- `mdm/local-downstream-pg`
- `mdm/local-downstream-mysql`
- `state-machine/dev-tunnel`
- `rule-engine/local`

Reason: several repos have more than one useful DB connection.

---

## SSH tunnel stance

Keep tunnels outside dbee, but plan for them explicitly.

Recommended practice:

- tunnel with `ssh -L ...`, `autossh`, or small helper scripts
- dbee connects to `127.0.0.1:<forwarded-port>`
- remote/tunneled entries belong in `dbee.local.lua` or global personal config

Why this fits your repos:

- several remote DBs are private/cloud-hosted
- local forwarded ports are safer and more consistent than direct remote access from editor config
- same tunnel pattern works for both Postgres and MySQL

Optional later improvement:

- add helper commands/scripts like `db-tunnel-task-mgmt-dev`, `db-tunnel-state-machine-test`
- but keep that out of initial dbee integration

---

## Security stance

Do not store raw passwords in:

- `repo/.nvim/dbee.lua`
- imported repo metadata
- any committed repo file added for Neovim

Use:

- existing `.env.local`
- ignored `.env`
- shell env vars
- `dbee.local.lua`
- secret manager if you already have one

Also:

- prefer local/test/dev over prod
- if remote prod-like connections are supported at all, keep them opt-in
- consider filtering out names like `prod` unless explicit flag enables them

---

## Concrete examples from current repos

### `task-mgmt`

Repo already exposes enough info for auto-discovery:

- Quarkus Postgres
- env vars: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_SCHEMA`, `DB_USER`, `DB_PASS`
- local compose exposes Postgres on host port `5433`

Result: this repo should work with zero extra dbee config.

### `auth`

Repo differs from most others:

- Quarkus
- MySQL, not Postgres
- main DB setting comes from `DB_URL`

Result: plan must support mixed engines, not only Postgres.

### `mdm`

Repo proves one-repo-one-connection is wrong:

- main app Postgres
- downstream Postgres
- downstream MySQL
- local docker stack already documents ports
- repo also has JetBrains datasource definitions

Result: repo-level config must support multiple named connections.

### `state-machine`

Repo shows Node/Drizzle pattern:

- uses `DATABASE_URL`
- schema filter matters
- repo also has JetBrains datasource definitions

Result: dbee should understand URL-driven Postgres repos, not only Java property templates.

### `rule-engine`

Repo shows another Node/Postgres shape:

- uses `POSTGRES_*` vars instead of single `DATABASE_URL`
- `drizzle.config.ts` is strong discovery source

Result: adapter must support both URL and split-env formats.

### `contract` / `collateral`

Repos show Symfony/Doctrine pattern:

- DB config centered on `DATABASE_URL`
- MySQL common

Result: plan should include a Symfony adapter or at least URL-based fallback.

---

## Open questions — updated

1. **Primary repo-local file name**
   - recommendation: `.nvim/dbee.lua`
   - not `.db/dbee.lua`

2. **Should JetBrains datasource import be supported?**
   - recommendation: **yes**
   - this is biggest quality-of-life win for your current workflow

3. **Should config formats beyond Lua be supported?**
   - recommendation: not initially
   - prefer adapters for existing repo files over new JSON/YAML format

4. **Should SSH tunnel helpers be added?**
   - maybe later
   - not part of first implementation

5. **Should prod connections appear automatically?**
   - recommendation: no, or only behind explicit opt-in flag

---

## Final recommendation

Build `nvim-dbee` integration around **repo discovery** with **optional repo-local override files**.

Best final shape:

- `.nvim/dbee.local.lua` for personal overrides and tunnels
- `.nvim/dbee.lua` for optional shared repo metadata
- import `.idea/dataSources.xml` when present
- auto-discover from app config / env / compose files
- fallback to global personal defaults
- keep secrets out of committed files
- keep SSH tunnels external

This matches your real repo fleet much better than a single global config or a mandatory new `.db/dbee.lua` file in every repo.

---

## Implementation order

1. Add `nvim-dbee` plugin
2. Add repo-root detection
3. Add connection loader with discovery order above
4. Implement JetBrains datasource import
5. Implement Quarkus adapter
6. Implement Drizzle/Node adapter
7. Implement Symfony URL adapter
8. Implement compose-based local DB fallback
9. Add commands:
   - `:DbeeOpen`
   - `:DbeeReloadConnections`
   - `:DbeeRepoConnections`
10. Later, add tunnel helper scripts only if still needed

That is most realistic plan for your actual repos and current IntelliJ-heavy workflow.
