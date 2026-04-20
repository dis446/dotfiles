# nvim-dbee plan

Goal: add `nvim-dbee` to this Neovim config, with DB connections managed per repo instead of one global pile.

## Desired behavior

- Repo can define its own DB connection config.
- Secrets stay out of git.
- Neovim auto-loads repo-local config when present.
- Falls back to global/default config when no repo config exists.
- SSH tunnels are handled outside dbee, with dbee connecting to localhost.

## Proposed repo layout

```text
repo/
├── .envrc
├── .gitignore
└── .db/
    └── dbee.lua
```

### `repo/.db/dbee.lua`

Store connection metadata here:
- name
- engine/type
- host
- port
- database
- user
- ssl mode
- optional local tunnel port

Do **not** store raw passwords or tokens here.

### Secrets

Use one of:
- `direnv`
- `.env.local` + `.gitignore`
- a secret manager
- env vars injected by shell/login scripts

Config should read secrets from `os.getenv(...)`.

## SSH tunneling stance

Treat SSH tunneling as external setup, not dbee’s job.

Use:
- `ssh -L ...`
- `autossh`
- a small repo helper script

Then point dbee at `127.0.0.1:<port>`.

## Neovim integration plan

1. Add `nvim-dbee` plugin.
2. Add a loader that checks for repo-local DB config from current cwd.
3. Load config on startup and on directory changes.
4. Add a command/mapping to open dbee quickly.
5. Keep config simple so each repo can opt in independently.

## Open questions

- Exact file name: `.db/dbee.lua` vs `.nvim/dbee.lua` vs `db.lua`
- Whether to support JSON/YAML in addition to Lua
- Whether to add a helper command to open/start SSH tunnels
- Whether to store per-repo defaults in `.envrc`

## Recommendation

Use:
- repo-local Lua config
- env-based secrets
- external SSH tunnels
- dbee as the UI over localhost connections

This keeps the setup flexible, secure, and easy to share across repos.
