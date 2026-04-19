# Blink Completion Migration Plan

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
- `hrsh7th/cmp-buffer`
- `hrsh7th/cmp-path`
- `saadparwaiz1/cmp_luasnip`
- `onsails/lspkind.nvim`
- `L3MON4D3/LuaSnip`
- `rafamadriz/friendly-snippets`

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

- LSP completion
- buffer/path sources
- snippet integration if desired
- the same general keymap ergonomics you already use

Goal:

- prove it works without removing the current stack
- compare feel and behavior before cutting over

### Phase 2 — Switch LSP capabilities

Update the LSP setup in:

- `nvim/lua/dis446/plugins/lsp/lspconfig.lua`

Replace:

- `cmp_nvim_lsp.default_capabilities()`

with the `blink.cmp` equivalent capability setup.

This is required so servers advertise completion support correctly.

### Phase 3 — Remove `nvim-cmp`

Once Blink is working well, remove:

- `nvim/lua/dis446/plugins/nvim-cmp.lua`
- `hrsh7th/nvim-cmp`
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
