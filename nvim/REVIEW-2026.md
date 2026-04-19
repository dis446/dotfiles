# Neovim Config Review (2026 Perspective)

## Scores

- **Overall quality:** 7.5/10
- **Modernity (2026):** 6.5/10
- **Practical usability:** 8/10

## Executive summary

This is a **good, clean, usable config**.

It is:
- modular
- sane
- not bloated
- readable
- fast enough for daily use

The LSP side has improved a lot, but the **UI / navigation / picker layer is still the oldest-feeling part of the setup**.

At this point, the clearest modernization path is **not** to keep patching compatibility around older UI plugins. It is to **consolidate around `folke/snacks.nvim`** for explorer, dashboard, picker, input/select UI, indent guides, and related utilities.

That direction would let you delete code and plugins instead of adding more glue.

I also did a quick headless boot with your config and it started **cleanly** and in about **46ms**, which is solid.

You’ve also removed the unused Svelte-specific config, which simplifies the LSP, formatter, linting, and Treesitter setup.

---

## What’s good

### 1. Clean structure

The layout is sensible and maintainable:

- `nvim/init.lua`
- `nvim/lua/dis446/core/*`
- `nvim/lua/dis446/plugins/*`

This is still a good architecture in 2026: small modules, obvious ownership, easy to maintain.

### 2. Strong foundations

You’re using solid core tools:

- `lazy.nvim`
- `treesitter`
- `gitsigns`
- `conform.nvim`
- `nvim-lint`
- `lazydev.nvim`

That stack is still very respectable.

### 3. Not over-engineered

A lot of configs become mini-frameworks. Yours doesn’t. It’s understandable and editable by its owner.

### 4. Lockfile present

`nvim/lazy-lock.json` is a good sign. It shows you care about reproducibility.

---

## Where it still feels dated

### 1. The UI / navigation layer is the oldest part now

Relevant files:

- `nvim/lua/dis446/plugins/alpha.lua`
- `nvim/lua/dis446/plugins/nvim-tree.lua`
- `nvim/lua/dis446/plugins/telescope.lua`
- `nvim/lua/dis446/plugins/dressing.lua`
- `nvim/lua/dis446/plugins/indent-blankline.lua`
- `nvim/lua/dis446/plugins/lazygit.lua`

These plugin choices are still usable, but they feel like a **2023/2024 modern Neovim stack**, not a **2026 consolidated stack**.

The direction many people have taken is:

- `snacks.dashboard` instead of `alpha-nvim`
- `snacks.explorer` instead of `nvim-tree`
- `snacks.picker` instead of `telescope`
- `snacks.input` / `snacks.picker.ui_select` instead of `dressing.nvim`
- `snacks.indent` instead of `indent-blankline.nvim`
- `snacks.lazygit` instead of `lazygit.nvim`

That is the migration I would plan here.

### 2. Completion is still classic rather than current

Relevant file:

- `nvim/lua/dis446/plugins/nvim-cmp.lua`

`nvim-cmp` is still valid, but in 2026 it reads as the older completion stack compared with `blink.cmp`-style setups.

This is a separate decision from the Snacks migration.

### 3. Misc utility overlap is starting to show

You now have a small amount of compatibility / transition logic that exists mainly to keep the older picker stack happy.

That’s not inherently bad, but it is a sign that the config is reaching the point where **consolidation is cleaner than patching**.

---

## Concrete issues still remaining

### 1. Likely bug in lualine theme

Relevant file:

- `nvim/lua/dis446/plugins/lualine.lua`

You define:

```lua
local colors = {
  blue = "#65D1FF",
  green = "#3EFFDC",
  violet = "#FF61EF",
  yellow = "#FFDA7B",
  red = "#FF4A4A",
  fg = "#c3ccdc",
  bg = "#112638",
  inactive_bg = "#2c3043",
}
```

But later use:

```lua
fg = colors.fg_dark
```

for inactive sections.

`fg_dark` is not defined in that table, so those values are effectively `nil`.

### 2. Redundant netrw leftovers

Relevant files:

- `nvim/lua/dis446/core/options.lua`
- `nvim/lua/dis446/plugins/nvim-tree.lua`

In `options.lua` you set:

- `g:netrw_liststyle = 3`

But in `nvim-tree.lua` you disable netrw:

- `vim.g.loaded_netrw = 1`
- `vim.g.loaded_netrwPlugin = 1`

That config is effectively dead, and it becomes even more obviously unnecessary once you move to `snacks.explorer`.

### 3. Java support still looks half-finished

Relevant files:

- `nvim/lua/dis446/plugins/lsp/mason.lua`
- `nvim/lua/dis446/plugins/java.backup`

You install `jdtls`, but Java usually needs more intentional setup than just the default handler. The presence of `java.backup` suggests earlier experimentation.

This reads as:
- Java support exists on paper
- but Java support is probably not production-ready

### 4. Temporary Treesitter compatibility glue exists because of the current picker stack

Relevant files:

- `nvim/lua/dis446/plugins/treesitter.lua`
- `nvim/lua/nvim-treesitter/configs.lua`

You now have temporary compatibility code to keep the current Telescope + Treesitter combination working with newer APIs.

That is a perfectly reasonable stopgap.

But it is also a strong signal that the **Telescope-era stack is now where the churn is happening**.

This is the clearest argument for moving to `snacks.picker` instead of writing more shims.

---

## What’s missing for a stronger 2026 config

These aren’t mandatory, but are common in more current setups.

### A more unified UI layer

Right now the config works, but the UI is spread across older single-purpose plugins.

A `snacks.nvim` migration would give you a more cohesive story for:

- dashboard
- file explorer
- fuzzy finding / grep / recent files
- LSP pickers
- diagnostics browsing
- `vim.ui.input`
- `vim.ui.select`
- indent guides
- lazygit integration

### Less compatibility maintenance

The practical win of moving to Snacks is not just aesthetics.

It is:
- fewer plugins
- fewer overlapping abstractions
- fewer plugin-specific commands to remember
- fewer breakpoints when upstream APIs shift

### More current language tooling choices

Examples:

- Python: many setups now prefer `ruff`-centric workflows over `pylint`
- JS/TS: some users have moved toward Biome or newer TS stacks

Your choices are standard and safe, but not especially current.

---

## What I’d keep as-is

I would **not** rewrite this from scratch.

These parts are good enough to keep:

- overall structure
- `lazy.nvim`
- `treesitter`
- `gitsigns`
- `conform.nvim`
- `nvim-lint`
- `which-key`
- `todo-comments.nvim`
- `auto-session`
- general keymap philosophy

This is a solid base.

---

## Detailed `snacks.nvim` migration plan

### Goal

Move from a collection of older UI plugins to a **single Snacks-first UI layer**, so the config becomes:

- simpler
- more cohesive
- easier to maintain
- less dependent on compatibility shims

The idea is **not** to replace everything.

The idea is to replace the parts where Snacks is strongest:

- dashboard
- explorer
- picker / grep / recent / LSP pickers
- input / select UI
- indent guides
- lazygit UI
- optional diagnostics browsing
- optional file rename integration

---

### Plugins to remove and replace

#### Direct replacements I would plan for

| Current plugin | Current file | Replace with | Recommendation |
|---|---|---|---|
| `goolord/alpha-nvim` | `nvim/lua/dis446/plugins/alpha.lua` | `snacks.dashboard` | **Remove** |
| `nvim-tree/nvim-tree.lua` | `nvim/lua/dis446/plugins/nvim-tree.lua` | `snacks.explorer` | **Remove** |
| `nvim-telescope/telescope.nvim` | `nvim/lua/dis446/plugins/telescope.lua` | `snacks.picker` | **Remove** |
| `nvim-telescope/telescope-fzf-native.nvim` | dependency inside `nvim/lua/dis446/plugins/telescope.lua` | built into `snacks.picker` flow | **Remove** |
| `stevearc/dressing.nvim` | `nvim/lua/dis446/plugins/dressing.lua` | `snacks.input` + `snacks.picker` with `ui_select = true` | **Remove** |
| `lukas-reineke/indent-blankline.nvim` | `nvim/lua/dis446/plugins/indent-blankline.lua` | `snacks.indent` | **Remove** |
| `kdheepak/lazygit.nvim` | `nvim/lua/dis446/plugins/lazygit.lua` | `snacks.lazygit` | **Remove** |

#### Remove after the Snacks flow is working

| Current thing | Current location | Replace with | Recommendation |
|---|---|---|---|
| `antosha417/nvim-lsp-file-operations` | dependency in `nvim/lua/dis446/plugins/lsp/lspconfig.lua` | `snacks.rename` + `snacks.explorer` rename / move flow | **Remove after migration is stable** |
| Treesitter compatibility shim | `nvim/lua/nvim-treesitter/configs.lua` | no longer needed once Telescope is gone | **Delete** |
| `ft_to_lang` compatibility backfill | `nvim/lua/dis446/plugins/treesitter.lua` | no longer needed once Telescope is gone | **Delete** |
| netrw leftovers | `nvim/lua/dis446/core/options.lua` | `snacks.explorer.replace_netrw = true` if desired | **Delete** |

#### Optional replacements / decision points

| Current plugin | Current file | Possible Snacks replacement | Recommendation |
|---|---|---|---|
| `folke/trouble.nvim` | `nvim/lua/dis446/plugins/trouble.lua` | `snacks.picker.diagnostics()`, `diagnostics_buffer()`, `qflist()`, `loclist()` | **Optional**; keep Trouble if you want a persistent diagnostics pane |
| `szw/vim-maximizer` | `nvim/lua/dis446/plugins/vim-maximizer.lua` | `snacks.zen.zoom()` | **Optional**; similar goal, not a strict 1:1 replacement |

---

### Plugins I would keep

These do **not** need to be replaced just because you adopt Snacks:

- `nvim-cmp` (unless you separately decide to move to `blink.cmp`)
- `LuaSnip`
- `gitsigns.nvim`
- `conform.nvim`
- `nvim-lint`
- `nvim-treesitter`
- `todo-comments.nvim`
- `which-key.nvim`
- `auto-session`
- `bufferline.nvim`
- `lualine.nvim`
- `Comment.nvim`
- `nvim-autopairs`
- `nvim-surround`
- `substitute.nvim`
- your custom `pi.lua`
- `plenary.nvim` (still needed by your Pi integration)

Important note:

- **keep `todo-comments.nvim`** even if you remove Telescope, because Snacks can use `Snacks.picker.todo_comments()` while `todo-comments.nvim` still provides the highlighting / keyword behavior.

---

### Recommended Snacks modules to enable

If I were migrating this config, I would start with one `snacks.lua` plugin spec and enable:

#### Core modules

- `dashboard`
- `explorer`
- `picker`
- `input`
- `indent`
- `lazygit`
- `rename`

#### Nice additions that fit your config well

- `notifier`
- `words`
- `scope`
- `zen`
- `bufdelete`
- `quickfile`

Not all of those have to be used on day one.

The important ones for your migration are:

- `dashboard`
- `explorer`
- `picker`
- `input`
- `indent`
- `lazygit`
- `rename`

---

### Keymap migration plan

#### File explorer

Current:

- `<leader>ee` — toggle file explorer
- `<leader>ef` — toggle explorer on current file
- `<leader>ec` — collapse tree
- `<leader>er` — refresh tree

Snacks target:

- `<leader>ee` → `Snacks.explorer()`
- `<leader>ef` → `Snacks.explorer.reveal()`

My recommendation:

- keep `<leader>ee`
- keep `<leader>ef`
- **retire** `<leader>ec` and `<leader>er` unless you find you really miss them

Snacks explorer has its own built-in operations for add / rename / delete / refresh-like behavior.

#### Picker / search

Current:

- `<leader>ff` — find files
- `<leader>fr` — recent files
- `<leader>fs` — live grep
- `<leader>fc` — grep word under cursor
- `<leader>ft` — TODOs

Snacks target:

- `<leader>ff` → `Snacks.picker.files()`
- `<leader>fr` → `Snacks.picker.recent()`
- `<leader>fs` → `Snacks.picker.grep()`
- `<leader>fc` → `Snacks.picker.grep_word()`
- `<leader>ft` → `Snacks.picker.todo_comments()`

This should be a very clean one-for-one migration.

#### LSP navigation pickers

Current:

- `gd`
- `gD`
- `gi`
- `gt`
- `gR`

Right now those call Telescope-backed pickers.

Snacks target:

- `gd` → `Snacks.picker.lsp_definitions()`
- `gD` → `Snacks.picker.lsp_declarations()`
- `gi` → `Snacks.picker.lsp_implementations()`
- `gt` → `Snacks.picker.lsp_type_definitions()`
- `gR` → `Snacks.picker.lsp_references()`

This is important because it removes one of the biggest reasons to keep Telescope around.

#### Diagnostics / lists

If you decide to replace Trouble:

- `<leader>xx` → `Snacks.picker.diagnostics()`
- `<leader>xw` → `Snacks.picker.diagnostics()`
- `<leader>xd` → `Snacks.picker.diagnostics_buffer()`
- `<leader>xq` → `Snacks.picker.qflist()`
- `<leader>xl` → `Snacks.picker.loclist()`

My recommendation:

- **do not remove Trouble immediately**
- first migrate dashboard / explorer / picker
- then decide whether you actually still want a persistent Trouble pane

#### Git UI

Current:

- `<leader>lg` — LazyGit

Snacks target:

- `<leader>lg` → `Snacks.lazygit()`

That is a straightforward swap.

#### Dashboard buttons

Your current Alpha dashboard buttons call:

- `NvimTreeToggle`
- `Telescope find_files`
- `Telescope live_grep`
- `SessionRestore`

The Snacks dashboard version should instead call:

- `Snacks.explorer()`
- `Snacks.picker.files()`
- `Snacks.picker.grep()`
- `SessionRestore`

So the session story can stay the same while the dashboard UX modernizes.

---

### Migration phases I’d actually follow

#### Phase 1 — Add Snacks without deleting anything yet

Create:

- `nvim/lua/dis446/plugins/snacks.lua`

Enable at least:

- `dashboard`
- `explorer`
- `picker`
- `input`
- `indent`
- `lazygit`
- `rename`

Goal:

- get Snacks loaded cleanly
- prove the main modules work
- avoid deleting old plugins until keymap parity exists

#### Phase 2 — Replace dashboard and explorer first

Remove:

- `nvim/lua/dis446/plugins/alpha.lua`
- `nvim/lua/dis446/plugins/nvim-tree.lua`

Then remap:

- `<leader>ee`
- `<leader>ef`

Update dashboard buttons accordingly.

Why first?

Because these are the clearest direct replacements and remove a lot of the “old starter config” feel immediately.

#### Phase 3 — Replace Telescope with Snacks picker

Remove:

- `nvim/lua/dis446/plugins/telescope.lua`
- `nvim-telescope/telescope-fzf-native.nvim` dependency inside that file

Then migrate:

- file / grep / recent / TODO keymaps
- all LSP Telescope pickers in `nvim/lua/dis446/plugins/lsp/lspconfig.lua`

This is the most important phase.

Once this phase is done, you can also delete the temporary Treesitter compatibility code.

#### Phase 4 — Remove the compatibility glue

Delete:

- `nvim/lua/nvim-treesitter/configs.lua`
- the `ft_to_lang` compatibility block in `nvim/lua/dis446/plugins/treesitter.lua`

This is the payoff phase.

It converts “we patched the old stack” into “we no longer need the old stack.”

#### Phase 5 — Converge the smaller utilities

Remove and replace:

- `nvim/lua/dis446/plugins/dressing.lua` → Snacks input / ui_select
- `nvim/lua/dis446/plugins/indent-blankline.lua` → Snacks indent
- `nvim/lua/dis446/plugins/lazygit.lua` → Snacks lazygit

Then optionally decide on:

- `trouble.nvim`
- `vim-maximizer`

#### Phase 6 — Clean up file-operation overlap

After Snacks explorer / rename are working well:

- remove `nvim-lsp-file-operations` from `nvim/lua/dis446/plugins/lsp/lspconfig.lua`
- remove dead netrw config from `nvim/lua/dis446/core/options.lua`

---

### File-level checklist

#### Add

- `nvim/lua/dis446/plugins/snacks.lua`

#### Delete

- `nvim/lua/dis446/plugins/alpha.lua`
- `nvim/lua/dis446/plugins/nvim-tree.lua`
- `nvim/lua/dis446/plugins/telescope.lua`
- `nvim/lua/dis446/plugins/dressing.lua`
- `nvim/lua/dis446/plugins/indent-blankline.lua`
- `nvim/lua/dis446/plugins/lazygit.lua`

#### Maybe delete later

- `nvim/lua/dis446/plugins/trouble.lua`
- `nvim/lua/dis446/plugins/vim-maximizer.lua`

#### Edit

- `nvim/lua/dis446/plugins/lsp/lspconfig.lua`
- `nvim/lua/dis446/plugins/treesitter.lua`
- `nvim/lua/dis446/core/options.lua`
- `nvim/CHEATSHEET.md`
- `nvim/README.md` if it references Alpha / Telescope / NvimTree

#### Delete after Telescope is gone

- `nvim/lua/nvim-treesitter/configs.lua`

---

## What I’d change first

### High priority

1. Add `snacks.nvim` and configure `dashboard`, `explorer`, `picker`, `input`, `indent`, `lazygit`, and `rename`
2. Replace `alpha-nvim` with `snacks.dashboard`
3. Replace `nvim-tree` with `snacks.explorer`
4. Replace Telescope + `telescope-fzf-native` with `snacks.picker`
5. Delete the temporary Treesitter compatibility shims once Telescope is gone
6. Replace `dressing.nvim`, `indent-blankline.nvim`, and `lazygit.nvim` with Snacks modules

### Medium priority

7. Decide whether `trouble.nvim` stays or becomes Snacks diagnostics pickers
8. Remove `nvim-lsp-file-operations` once Snacks rename / explorer file operations are working well
9. Clean up netrw leftovers
10. Fix `lualine.lua` inactive color bug
11. Either finish Java support properly or remove it

### Optional / taste-based

12. Decide later whether you also want:
- `blink.cmp` instead of `nvim-cmp`
- `Snacks.zen.zoom()` instead of `vim-maximizer`
- more Snacks extras like `words`, `scope`, or `notifier`

---

## Final verdict

This is still a **good personal config**.

It is:
- readable
- sane
- not bloated
- reasonably fast
- clearly usable every day

But the next meaningful modernization pass should be a **Snacks consolidation**, not more incremental patching around older UI plugins.

### One-line summary

> A solid Neovim config with improved LSP foundations; the best next step is to replace the older dashboard/explorer/picker utility stack with a `snacks.nvim`-first setup and then delete the compatibility glue.
