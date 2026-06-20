# Neovim Config Review (Mid 2026)

## Scores

- **Overall quality:** 8.5/10
- **Modernity (mid-2026):** 8.5/10
- **Practical usability:** 9/10
- **Migration completeness:** 9/10

## Executive summary

This config went through a **major modernization pass** since the last review. The old review's primary recommendation — consolidate around `folke/snacks.nvim` — has been fully executed. The Telescope-era UI stack (Alpha, NvimTree, Telescope, Dressing, Indent-Blankline, Lazygit.nvim, Trouble, Vim-Maximizer) and the nvim-cmp completion layer have been **removed entirely** and replaced with Snacks modules and blink.cmp.

The result is a noticeably **leaner, more cohesive, and more modern** config with fewer plugins, no compatibility shims, and a unified UI experience.

I also did a quick headless boot: **~42ms**. This is a very fast config for its feature set.

---

## What's great

### 1. Snacks consolidation is complete

The migration plan from the last review has been **fully executed**:

| ~~Old plugin~~ | ✅ Replaced with |
|---|---|
| `alpha-nvim` | `snacks.dashboard` |
| `nvim-tree` | `snacks.explorer` |
| `telescope.nvim` | `snacks.picker` |
| `dressing.nvim` | `snacks.input` + `ui_select = true` |
| `indent-blankline.nvim` | `snacks.indent` |
| `lazygit.nvim` | `snacks.lazygit` |
| `trouble.nvim` | `snacks.picker.diagnostics()` |
| `vim-maximizer` | `snacks.zen.zoom()` |

Keymaps are consistent, the picker/grep/explorer behavior is snappy, and the dashboard looks good.

### 2. Completion migrated to blink.cmp

`nvim-cmp` was replaced with `saghen/blink.cmp` — the current Rust-native completion engine. `LuaSnip` + `friendly-snippets` are retained as the snippet backend, which is exactly the right approach.

Keymap ergonomics mirror the old nvim-cmp setup (no preselection, `<C-j>`/`<C-k>` navigation, `<CR>` confirms explicit selection), so muscle memory is preserved.

### 3. LSP pickers use Snacks

LSP navigation (`gd`, `gi`, `gt`, `gR`, buffer diagnostics) now calls `Snacks.picker.*` directly rather than Telescope-backed handlers. This removes one of the biggest reasons to keep Telescope around.

### 4. No compatibility shims

The temporary Treesitter compatibility layer (`nvim/lua/nvim-treesitter/configs.lua`, `ft_to_lang` backfill) has been **deleted**. No netrw leftovers remain. No dead code from the old UI stack.

### 5. Lualine `fg_dark` bug fixed

The old review noted `colors.fg_dark` was used but undefined in the colors table. This has been fixed: `fg_inactive` is now properly defined and used for inactive sections.

### 6. Java support is solid

~~The old review described Java as "half-finished." The current `jdtls.lua` is a proper setup:~~
- Java 21 runtime discovery with multiple candidate paths
- Lombok agent injection
- Project root detection (`pom.xml`, `gradlew`, `build.gradle`, `micronaut-cli.yml`, `.git`)
- Per-project workspace directories
- Organize imports on save
- Inlay hints, decompiled source references, code lens

This is **production-ready** for Java work.

---

## Minor observations

### 1. `java.backup` file still present

`nvim/lua/dis446/plugins/java.backup` is a remnant of an earlier `nvim-java` experiment. It is not loaded by lazy.nvim (no `.lua` extension) and does no harm, but it's dead weight. Consider deleting it.

### 2. Session management is automatic

`auto-session` is now configured with `auto_restore_enabled = true` and `auto_save_enabled = true`. Manual `<leader>wr`/`<leader>ws` controls have been removed. This makes the editor feel more like a modern IDE that just picks up where you left off.

### 3. Picker `explorer` layout width

The `explorer` source sets `layout = { preset = "sidebar", preview = false, width = 0.66 }` — noticeably wider than the default sidebar. This is a deliberate choice for readability, but worth noting if you ever feel the explorer is crowding the buffer.

### 4. No `nvim-dap` integration

There is no debug adapter protocol setup. If you debug code (especially Java, Python, or JS/TS), this would be the next meaningful addition. Snacks has no DAP module, so this would be `nvim-dap` + `nvim-dap-ui` or similar.

### 5. No test runner integration

No `neotest` or similar test runner framework. This pairs with the DAP gap for a more complete development experience.

### 6. `blink.cmp` is pinned to `1.*`

The blink.cmp spec uses `version = "1.*"` which is sensible for stability. Just remember to bump this when v2 ships (if it ever does).

---

## What I'd keep as-is

- Structure: `init.lua` → `dis446.core` → `dis446.lazy` → `dis446.plugins/*`
- `lazy.nvim` plugin manager
- `nvim-treesitter` (highlighting, indentation, autotagging, incremental selection)
- `gitsigns.nvim`
- `conform.nvim` + `nvim-lint` for formatting/linting
- `todo-comments.nvim` (with Snacks picker integration)
- `which-key.nvim`
- `Comment.nvim`
- `nvim-surround` + `substitute.nvim`
- `lualine.nvim` (custom theme, repo-relative filename)
- `auto-session` (now fully automatic)
- `tokyonight.nvim` colorscheme (custom overrides)
- The `Snacks` config and keymap set
- The `blink.cmp` config
- The `mise.toml` Treesitter query predicate
- Java config

---

## Final verdict

This is a **strong, modern, well-maintained** personal config.

The Snacks migration was the right call and was executed cleanly. The blink.cmp migration removes the last "old completion" feel. LSP handling, formatting, linting, and git integration are all well covered.

The config no longer feels like a 2023/2024 starter template with new parts bolted on. It now has a **consistent identity** as a Snacks-first + blink.cmp config with good LSP foundations and a fast startup.

### One-line summary

> The Snacks migration is complete and the config is now cohesive, modern, and fast — remaining gaps are DAP/test-runner integration and general polish.
