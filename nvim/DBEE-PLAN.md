# nvim-dbee plan — repo-owned DB configs

Goal: add `nvim-dbee` to Neovim with **explicit repo-owned DB config**, **multiple connections per repo**, **no IntelliJ parsing**, **no global connection pile**.

POC repo: `/home/ubby/Code/alpha/back-end/relation-store`

---

## Hard requirements

- DBEE must **never read IntelliJ configs**.
- Each repo must **own its own DB connection config**.
- Each repo must support **multiple named DB connections**.
- Secrets must stay out of committed config.
- SSH tunnels stay **outside dbee**, but repo config may describe tunneled connections.
- If repo has no DBEE config, DBEE should do nothing for that repo.

---

## What changed from earlier plan

Old direction used discovery from repo files and JetBrains datasource import.

New direction:

- **No IntelliJ import**
- **No magic autodiscovery as primary model**
- **Repo-local explicit config is source of truth**
- Optional env loading still OK for secrets/defaults

Reason: cleaner ownership model. Less hidden behavior. Easier multi-DB support.

---

## Recommended repo layout

Use this in repos that opt in:

```text
repo/
├── .nvim/
│   ├── dbee.lua         # committed, repo-owned, no secrets
│   └── dbee.local.lua   # optional, untracked, personal overrides
├── .env                 # optional, usually ignored already
├── .env.test            # optional, usually ignored already
└── scripts/
    └── db-tunnel-*.sh   # optional tunnel helpers
```

Why `.nvim/`:

- clear editor-specific ownership
- avoids mixing with app DB folders like `db/`, `drizzle/`, `migrations/`
- easy future expansion for repo-local Neovim behavior

---

## Config contract

Each `repo/.nvim/dbee.lua` should return **list of named connections**.

Example shape:

```lua
return {
  connections = {
    {
      name = "local",
      type = "postgres",
      url_env = "RELATION_STORE_DB_LOCAL_URL",
      host = "127.0.0.1",
      port = 5432,
      database = "postgres",
      user_env = "RELATION_STORE_DB_LOCAL_USER",
      password_env = "RELATION_STORE_DB_LOCAL_PASS",
      schema = "relation_store",
      sslmode = "disable",
      tags = { "local" },
    },
    {
      name = "test-tunnel",
      type = "postgres",
      host = "127.0.0.1",
      port_env = "RELATION_STORE_DB_TEST_TUNNEL_PORT",
      port = 6432,
      database = "relation_store",
      user_env = "RELATION_STORE_DB_TEST_USER",
      password_env = "RELATION_STORE_DB_TEST_PASS",
      schema = "relation_store",
      sslmode = "disable",
      tags = { "test", "tunnel" },
      via_tunnel = true,
    },
  },
}
```

Notes:

- `connections` is array, not single object
- each connection has stable `name`
- secrets come from env vars, not committed Lua
- URL form and host/port form both allowed
- schema should be first-class, not afterthought

---

## Normalized connection fields

Support these fields in loader:

- `name`
- `type` — `postgres`, `mysql`, later more if needed
- `url`
- `url_env`
- `host`
- `host_env`
- `port`
- `port_env`
- `database`
- `database_env`
- `user`
- `user_env`
- `password`
- `password_env`
- `schema`
- `schema_env`
- `sslmode`
- `tags`
- `via_tunnel`
- `description`

Resolution rule:

- explicit value wins if present
- otherwise read matching `*_env`
- otherwise use hardcoded non-secret default if present
- if required field still missing, skip connection and warn

---

## Secret model

Committed `repo/.nvim/dbee.lua` may contain:

- names
- engine type
- schema
- localhost hostnames
- local default ports
- env variable names
- non-secret descriptions/tags

Committed `repo/.nvim/dbee.lua` must **not** contain:

- passwords
- tokens
- raw remote connection strings with credentials

Secrets should come from one of:

- repo `.env`
- repo `.env.local`
- shell env
- `repo/.nvim/dbee.local.lua`

If `dbee.local.lua` is used, it must be ignored.

---

## `dbee.local.lua` role

Use `repo/.nvim/dbee.local.lua` for personal overrides only.

Examples:

- override tunnel port
- override username/password env names
- disable noisy connections
- add temporary one-off connection for branch work

Merge order:

1. `dbee.lua`
2. `dbee.local.lua`

Later file overrides earlier one by connection `name`.

---

## Tunnel model

Tunnels are external. DBEE only connects to local forwarded endpoint.

Meaning:

- DBEE config should point tunneled DBs to `127.0.0.1:<forwarded-port>`
- repo may include helper script like `scripts/db-tunnel-test.sh`
- DBEE loader does **not** open SSH session itself

Optional metadata is OK:

```lua
via_tunnel = true,
description = "Requires test SSH tunnel on localhost:6432"
```

But connection itself remains normal localhost DB connection.

---

## Neovim loader behavior

When opening file inside repo:

1. find git root / repo root
2. look for `repo/.nvim/dbee.lua`
3. if absent, no repo DB config loaded
4. if present, load `connections`
5. if `repo/.nvim/dbee.local.lua` exists, merge overrides
6. convert resolved connections to DBEE format
7. expose repo command to open/select connection

Important:

- no fallback to IntelliJ
- no scanning `application.properties` for live connection definitions
- repo DB config is single source of truth for DBEE

App config may still inspire values when author writes repo config, but loader should not depend on it.

---

## Naming convention

Use stable repo-scoped names:

- `local`
- `test-tunnel`
- `dev-tunnel`
- `downstream-pg-local`
- `downstream-mysql-local`

In UI, show them as:

- `relation-store/local`
- `relation-store/test-tunnel`

Reason: avoids name collisions across repos.

---

## POC target: `relation-store`

Repo facts relevant to POC:

- Quarkus app expects Postgres via `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS`
- schema is `relation_store`
- repo already has ignored `.env*` files
- your required POC connections are:
  - local Postgres
  - test env Postgres through SSH tunnel

### POC desired connections

#### 1) `relation-store/local`

Purpose:

- connect to your local Postgres for daily dev work

Defaults:

- type: `postgres`
- host: `127.0.0.1`
- port: `5432`
- database: `postgres`
- schema: `relation_store`
- sslmode: `disable`

Credentials:

- from env vars, not committed in Lua

#### 2) `relation-store/test-tunnel`

Purpose:

- connect to test env Postgres through local SSH tunnel

Defaults:

- type: `postgres`
- host: `127.0.0.1`
- port: `6432` by default if that is your chosen forward
- database: `relation_store`
- schema: `relation_store`
- sslmode: `disable` at DBEE side if tunnel terminates to localhost
- mark `via_tunnel = true`

Credentials:

- from env vars, not committed in Lua

Important:

- DBEE config should **not** point at Azure hostname directly for this connection
- it should point at tunnel endpoint on localhost

---

## POC file examples

### `relation-store/.nvim/dbee.lua`

```lua
return {
  connections = {
    {
      name = "local",
      type = "postgres",
      host = "127.0.0.1",
      port = 5432,
      database = "postgres",
      schema = "relation_store",
      user_env = "RELATION_STORE_DB_LOCAL_USER",
      password_env = "RELATION_STORE_DB_LOCAL_PASS",
      sslmode = "disable",
      tags = { "local" },
    },
    {
      name = "test-tunnel",
      type = "postgres",
      host = "127.0.0.1",
      port_env = "RELATION_STORE_DB_TEST_TUNNEL_PORT",
      port = 6432,
      database = "relation_store",
      schema = "relation_store",
      user_env = "RELATION_STORE_DB_TEST_USER",
      password_env = "RELATION_STORE_DB_TEST_PASS",
      sslmode = "disable",
      via_tunnel = true,
      tags = { "test", "tunnel" },
      description = "Test env over SSH tunnel",
    },
  },
}
```

### optional `relation-store/.nvim/dbee.local.lua`

```lua
return {
  connections = {
    {
      name = "test-tunnel",
      port = 6543,
    },
  },
}
```

### env examples

Could live in ignored `.env` or shell env:

```bash
RELATION_STORE_DB_LOCAL_USER=ubby
RELATION_STORE_DB_LOCAL_PASS=...
RELATION_STORE_DB_TEST_USER=app_relation_store
RELATION_STORE_DB_TEST_PASS=...
RELATION_STORE_DB_TEST_TUNNEL_PORT=6432
```

If you prefer full URLs later, contract can also support:

```bash
RELATION_STORE_DB_LOCAL_URL=postgresql://user:pass@127.0.0.1:5432/postgres?sslmode=disable
RELATION_STORE_DB_TEST_TUNNEL_URL=postgresql://user:pass@127.0.0.1:6432/relation_store?sslmode=disable
```

Then `url_env` can replace split fields.

---

## Generalized pattern for all repos

Every repo that wants DBEE support adds committed `repo/.nvim/dbee.lua`.

That file declares zero or more named connections.

Examples:

- Quarkus repo with one local and one test tunnel → 2 entries
- Node repo with local, dev tunnel, test tunnel → 3 entries
- multi-DB repo like `mdm` → 4+ entries
- MySQL repo like `auth` → same shape, different `type`

This is simple, explicit, and stack-agnostic.

---

## Validation rules

Loader should validate each connection:

- `name` required
- `type` required
- either `url`/`url_env` or enough host-form fields to build DSN
- if `via_tunnel = true`, missing localhost host should warn
- if credential env vars missing, either prompt or skip based on config

Recommendation for POC:

- skip invalid connections with warning
- do not prompt yet
- keep first implementation deterministic

---

## Non-goals for first version

Do not add yet:

- IntelliJ import
- framework autodiscovery
- JSON/YAML config formats
- tunnel lifecycle management
- secret manager integration
- automatic prod connection support

Keep POC small.

---

## Recommended implementation order

1. Add `nvim-dbee`
2. Add repo-root detection
3. Add loader for `repo/.nvim/dbee.lua`
4. Add merge support for `repo/.nvim/dbee.local.lua`
5. Add normalized connection resolver
6. Add repo-scoped connection names in UI
7. POC in `relation-store` with:
   - `local`
   - `test-tunnel`
8. After POC works, roll same contract to other repos

---

## Final recommendation

Use **explicit repo-owned Lua config** as only DBEE source of truth.

Best shape:

- committed `repo/.nvim/dbee.lua`
- optional ignored `repo/.nvim/dbee.local.lua`
- multiple named connections per repo
- env-backed secrets
- localhost endpoints for tunneled DBs
- no IntelliJ coupling
- no hidden autodiscovery

This matches your requirement exactly: each repo owns DB config, each repo can define many DB connections, DBEE stays separate from IntelliJ.
