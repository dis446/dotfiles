# Blink Completion Migration Plan

> **Status: completed (2026-06-20).** `blink.cmp` is live in
> `nvim/lua/dis446/plugins/blink.lua`, LSP capabilities come from
> `blink.cmp.get_lsp_capabilities()`, and the `nvim-cmp` stack
> (`nvim-cmp`, `cmp-nvim-lsp`, `cmp-buffer`, `cmp-path`, `cmp_luasnip`,
> `lspkind`) has been removed. `LuaSnip` + `friendly-snippets` are kept.
> The sections below are retained as a record of the plan.

## Multi-machine considerations

`blink.cmp` ships a Rust fuzzy matcher. With `version = "1.*"` pinned, blink
downloads a **prebuilt** binary matching the release tag on first load — no local
Rust toolchain required. Verified on this machine: `target/release/libblink_cmp_fuzzy.so`
downloads automatically and `blink.cmp.fuzzy.rust` loads. On other machines
(nobara / macos / ubuntu) the same download happens on first `nvim` launch after
pulling; if a machine is offline or the prebuilt target is unavailable, blink
falls back to the Lua matcher (`prefer_rust_with_warning`) instead of erroring.

---

This document lays out a practical migration path from `nvim-cmp` to `blink.cmp` for this Neovim config.

## Goal

Replace the classic completion stack with a newer, simpler one while preserving:

- LSP completion
- snippet support
- current insert-mode ergonomics
- a clean docs/story in `README.md` and `CHEATSHEET.md`

---

## Current completion stack

Current files involved:

- `nvim/lua/dis446/plugins/nvim-cmp.lua`
- `nvim/lua/dis446/plugins/lsp/lspconfig.lua`
- `nvim/README.md`
- `nvim/CHEATSHEET.md`

Current completion-related dependencies:

- `hrsh7th/nvim-cmp`
- `hrsh7th/cmp-nvim-lsp` (declared in `lspconfig.lua`, provides LSP capabilities)
- `hrsh7th/cmp-buffer`
- `hrsh7th/cmp-path`
- `saadparwaiz1/cmp_luasnip`
- `onsails/lspkind.nvim`
- `L3MON4D3/LuaSnip`
- `rafamadriz/friendly-snippets`

Behaviors worth preserving on cutover:

- `completeopt = "menu,menuone,preview,noselect"` and `confirm({ select = false })` — i.e. nothing is preselected; `<CR>` only confirms an item you explicitly moved to. The blink equivalent is `completion.list.selection.preselect = false` (and `auto_insert` to taste).
- vs-code-style pictograms in the menu (currently via `lspkind`). `blink.cmp` renders kind icons itself, so `lspkind` is not needed.

Current completion ergonomics:

- `<C-Space>` — trigger completion
- `<C-j>` / `<C-k>` — navigate items
- `<C-b>` / `<C-f>` — scroll docs
- `<C-e>` — abort completion
- `<CR>` — confirm selection

---

## Why switch

Main expected benefits:

- less glue and fewer moving parts
- more modern completion UX
- likely snappier performance
- cleaner fit with the rest of the Snacks-first UI modernization
- fewer separate completion adapters to maintain

Tradeoff:

- `nvim-cmp` is extremely mature and well-documented, so `blink.cmp` is more of a modernization/cleanup move than a guaranteed dramatic usability jump.

---

## Migration phases

### Phase 1 — Add Blink side-by-side

Create a new plugin spec, likely:

- `nvim/lua/dis446/plugins/blink.lua`

Start with:

- LSP completion (built-in `lsp` source)
- buffer/path sources (both built in — no separate adapter plugins)
- snippet integration if desired (see snippet note below)
- the same general keymap ergonomics you already use

`blink.cmp` notes that change the shape of the spec vs. `nvim-cmp`:

- **Sources are built in.** `lsp`, `buffer`, `path`, and `snippets` ship with `blink.cmp`, so `cmp-buffer`/`cmp-path`/`cmp_luasnip`/`cmp-nvim-lsp` have no equivalent dependency.
- **Fuzzy matcher.** `blink.cmp` uses a Rust matcher. The default `fuzzy.implementation = "prefer_rust_with_warning"` downloads a prebuilt binary from the tagged release; pinning to a release tag (not `main`) avoids needing a local Rust toolchain to build it. Worth noting since this repo's other plugins are pure Lua.
- **Keymap presets.** Blink ships presets (`default`, `super-tab`, etc.). To keep the current `<C-j>`/`<C-k>`/`<C-b>`/`<C-f>`/`<C-Space>`/`<C-e>`/`<CR>` ergonomics, set `keymap.preset` and override those keys explicitly.
- **Snippets.** Blink's `snippets` source works with `friendly-snippets` directly. To keep `LuaSnip`, set `snippets.preset = "luasnip"`; otherwise the built-in engine can replace it.

Goal:

- prove it works without removing the current stack
- compare feel and behavior before cutting over

### Phase 2 — Switch LSP capabilities

Update the LSP setup in:

- `nvim/lua/dis446/plugins/lsp/lspconfig.lua`

Replace:

- the `require("cmp_nvim_lsp")` call (line 9)
- `cmp_nvim_lsp.default_capabilities()` (line 113)

with the `blink.cmp` equivalent:

- `require("blink.cmp").get_lsp_capabilities()` — optionally pass an existing
  capabilities table to merge into.

Also drop `hrsh7th/cmp-nvim-lsp` from the `dependencies` of the lspconfig spec
(line 5). The capabilities table is fed to each server via the existing
`vim.tbl_deep_extend("force", { capabilities = capabilities }, server_opts)`
loop, so only the source of `capabilities` changes.

This is required so servers advertise completion support correctly.

### Phase 3 — Remove `nvim-cmp`

Once Blink is working well, remove:

- `nvim/lua/dis446/plugins/nvim-cmp.lua`
- `hrsh7th/nvim-cmp`
- `hrsh7th/cmp-nvim-lsp` (from `lspconfig.lua` dependencies — see Phase 2)
- `hrsh7th/cmp-buffer`
- `hrsh7th/cmp-path`
- `saadparwaiz1/cmp_luasnip`
- `onsails/lspkind.nvim`

Likely keep:

- `L3MON4D3/LuaSnip`
- `rafamadriz/friendly-snippets`

if you still want snippet expansion.

### Phase 4 — Update docs

Update:

- `nvim/README.md`
- `nvim/CHEATSHEET.md`

Specifically:

- remove the `nvim-cmp` section
- replace it with `blink.cmp`
- document any new completion behavior or keymap changes
- update any capability/snippet notes

### Phase 5 — Simplify further if desired

Optional follow-up:

- reduce snippet dependencies if you decide you do not use snippets heavily
- trim any leftover completion-formatting references

---

## Recommended order of implementation

1. Add `blink.cmp`
2. Keep `nvim-cmp` temporarily
3. Verify completion behavior
4. Switch LSP capabilities to Blink
5. Remove `nvim-cmp` and its helper plugins
6. Update docs

---

## Files to inspect during migration

- `nvim/lua/dis446/plugins/nvim-cmp.lua`
- `nvim/lua/dis446/plugins/lsp/lspconfig.lua`
- `nvim/README.md`
- `nvim/CHEATSHEET.md`
- any future `nvim/lua/dis446/plugins/blink.lua`

---

## Suggested acceptance criteria

The migration is done when:

- completion works in LSP buffers
- snippet expansion still works, if kept
- the familiar completion keymaps still feel correct
- `nvim-cmp` and its helper plugins are removed
- README and cheat sheet describe the new state accurately

---

## Notes

This migration is best done **after** the Snacks UI consolidation is stable.

The config is now modern enough that completion is the last major classic plugin stack still worth revisiting.
