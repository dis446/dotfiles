# Neovim Config Review (2026 Perspective)

## Scores

- **Overall quality:** 7.5/10
- **Modernity (2026):** 6/10
- **Practical usability:** 8/10

## Executive summary

This is a **good, clean, usable config**.

It is:
- modular
- sane
- not bloated
- readable
- fast enough for daily use

From a **2026 perspective**, though, it feels more like a **well-kept 2023/2024 Lua starter-style config** than a truly current Neovim setup.

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
- `telescope`
- `gitsigns`
- `conform.nvim`
- `nvim-lint`

That stack is still very respectable.

### 3. Not over-engineered

A lot of configs become mini-frameworks. Yours doesn’t. It’s understandable and editable by its owner.

### 4. Lockfile present

`nvim/lazy-lock.json` is a good sign. It shows you care about reproducibility.

---

## Where it feels dated

### 1. LSP setup is the most dated part

Relevant files:

- `nvim/lua/dis446/plugins/lsp/lspconfig.lua`
- `nvim/lua/dis446/plugins/lsp/mason.lua`

This is the biggest “2024 energy” section.

#### Specific issues

- `folke/neodev.nvim` is old now.
  - In 2026, this should generally be replaced with **`folke/lazydev.nvim`** or a newer LuaLS setup.
- `tsserver` in Mason is a red flag.
  - Newer ecosystems moved toward **`ts_ls`** naming / newer TS setup patterns.
  - This is one of the first places likely to break when updating.

So the LSP setup is functional, but not future-forward.

### 2. Some plugin choices feel classic rather than current

These are not bad, just no longer the default “modern 2026” picks:

- `nvim-tree`
- `alpha-nvim`
- `nvim-cmp`

A lot of 2026 users lean more toward:

- `oil.nvim`, `mini.files`, or `snacks` explorer flows
- `snacks.dashboard`-style startup screens
- `blink.cmp`-style completion stacks

Your choices are still valid; they just feel like an earlier era of modern Neovim.

### 3. Trouble config looks old-style

Relevant file:

- `nvim/lua/dis446/plugins/trouble.lua`

You’re using older commands like:

- `TroubleToggle`
- `TroubleToggle workspace_diagnostics`

These may work depending on plugin version compatibility, but they are exactly the kind of thing that tends to break during upgrades.

---

## Concrete issues found

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

### 2. Redundant / conflicting netrw handling

Relevant files:

- `nvim/lua/dis446/core/options.lua`
- `nvim/lua/dis446/plugins/nvim-tree.lua`

In `options.lua` you set:

- `g:netrw_liststyle = 3`

But in `nvim-tree.lua` you disable netrw:

- `vim.g.loaded_netrw = 1`
- `vim.g.loaded_netrwPlugin = 1`

So the netrw customization is effectively dead config.

### 3. Java support looks half-finished

Relevant files:

- `nvim/lua/dis446/plugins/lsp/mason.lua`
- `nvim/lua/dis446/plugins/java.backup`

You install `jdtls`, but Java usually needs more intentional setup than just the default handler. The presence of `java.backup` suggests earlier experimentation.

This reads as:
- Java support exists on paper
- but Java support is probably not production-ready

### 4. `vim.loop` is old-style now

Relevant file:

- `nvim/lua/dis446/lazy.lua`

You use:

```lua
vim.loop.fs_stat(...)
```

By 2026, `vim.uv` is the more current style.

### 5. Import path style is inconsistent

Relevant file:

- `nvim/lua/dis446/lazy.lua`

You have:

```lua
{ import = "dis446.plugins" },
{ import = "dis446/plugins/lsp" }
```

Stylistically, I’d expect:

```lua
{ import = "dis446.plugins" },
{ import = "dis446.plugins.lsp" }
```

Not a bug, just not polished.

---

## What’s missing for a stronger 2026 config

These aren’t mandatory, but are common in more current setups.

### LSP UX polish

I’d expect more 2026 ergonomics such as:

- inlay hints toggle/default enable
- document highlights
- better diagnostics config
- bordered hover/signature windows
- code lens where relevant

Right now the LSP is functional but basic.

### Better use of Neovim core evolution

The config still leans on older plugin-era defaults rather than taking more advantage of newer core APIs.

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
- Telescope
- Treesitter
- Gitsigns
- Conform
- which-key
- general keymap philosophy

This is a solid base.

---

## What I’d change first

### High priority

1. Replace `neodev.nvim`
2. Fix TypeScript server naming/setup (`tsserver` → current Mason/LSP equivalent)
3. Update Trouble mappings to current API
4. Fix `lualine.lua` inactive color bug
5. Either finish Java support properly or remove it

### Medium priority

6. Clean up netrw leftovers
7. Switch `vim.loop` → `vim.uv`
8. Improve diagnostics / inlay hint setup

### Optional / taste-based

11. Re-evaluate whether you still want:
- `nvim-tree` vs `oil.nvim` / `mini.files` / `snacks`
- `alpha-nvim` vs newer dashboard UX
- `nvim-cmp` vs newer completion stacks

---

## Final verdict

This is a **good personal config**.

It is:
- readable
- sane
- not bloated
- reasonably fast
- clearly usable every day

But from a **modern 2026 perspective**, it is **not cutting-edge**. It feels like a polished, stable, older-style Lua config rather than a currently-evolving Neovim setup.

### One-line summary

> A solid, practical Neovim config with good fundamentals, but it needs an LSP/UI modernization pass to feel truly 2026-native.
