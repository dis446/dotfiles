# @nvim configuration

This directory contains my Neovim configuration.

## Startup

`init.lua` loads the config in two steps:

1. `require("dis446.core")`
2. `require("dis446.lazy")`

### Core modules

- `lua/dis446/core/options.lua` sets editor options
- `lua/dis446/core/keymaps.lua` sets global keymaps

### Plugin loader

- `lua/dis446/lazy.lua` bootstraps and configures `lazy.nvim`

---

## Core editor settings

### `lua/dis446/core/options.lua`

#### Line numbers
- `relativenumber = true`
- `number = true`

#### Indentation
- `tabstop = 2`
- `shiftwidth = 2`
- `expandtab = true`
- `autoindent = true`

#### Search and editing
- `wrap = false`
- `ignorecase = true`
- `smartcase = true`
- `cursorline = true`
- `backspace = "indent,eol,start"`

#### UI
- `termguicolors = true`
- `background = "dark"`
- `signcolumn = "yes"`

#### Clipboard and splits
- `clipboard += unnamedplus`
- `splitright = true`
- `splitbelow = true`

---

## Global keymaps

### `lua/dis446/core/keymaps.lua`

Leader key: `Space`

#### General
- `<leader>nh` — clear search highlights
- `<leader>+` — increment number under cursor
- `<leader>-` — decrement number under cursor

#### Window management
- `<leader>sv` — vertical split
- `<leader>sh` — horizontal split
- `<leader>se` — equalize splits
- `<leader>sx` — close current split

#### Tabs
- `<leader>tt` — open new tab
- `<leader>tw` — close current tab
- `<leader>tl` — next tab
- `<leader>th` — previous tab
- `<leader>ty` — open current buffer in a new tab

---

## Plugin stack

### Plugin manager
#### `lazy.nvim`
Handles plugin installation, loading, and update checks.

---

### Theme
#### `tokyonight.nvim`
The active colorscheme.

Configuration uses:
- `style = "night"`
- custom color overrides for background, gutter, borders, and highlights

---

### Statusline and buffer line
#### `lualine.nvim`
Provides the statusline.

Theme colors include:
- blue
- green
- violet
- yellow
- red
- foreground and inactive foreground

#### `bufferline.nvim`
Shows buffers and tabs with devicons.

---

### Navigation and workspace UI
#### `snacks.nvim`
Provides dashboard, explorer, picker, input, indent guides, lazygit, rename, notifier, quickfile, bigfile handling, and zooming.

Enabled modules:
- `dashboard`
- `explorer`
- `picker`
- `input`
- `indent`
- `lazygit`
- `rename`
- `notifier`
- `quickfile`
- `bigfile`
- `zen`

Keymaps:
- `<leader>ee` — toggle file explorer
- `<leader>ef` — reveal current file in explorer
- `<leader>ff` — find files
- `<leader>fr` — recent files
- `<leader>fs` — live grep
- `<leader>fc` — grep word under cursor
- `<leader>ft` — TODOs
- `<leader>lg` — open LazyGit
- `<leader>sm` — maximize/minimize a split
- `<leader>xx` — diagnostics list
- `<leader>xw` — workspace diagnostics
- `<leader>xd` — document diagnostics
- `<leader>xq` — quickfix list
- `<leader>xl` — location list
- `<leader>xt` — TODO list

User commands:
- `:SnacksExplorer`
- `:SnacksReveal`
- `:SnacksFiles`
- `:SnacksRecent`
- `:SnacksGrep`
- `:SnacksLazyGit`

Dashboard buttons open new files, the explorer, file search, grep, session restore, and quit.

---

### Session management
#### `auto-session`
Manages session save and restore per directory.

Keymaps:
- `<leader>wr` — restore session for current directory
- `<leader>ws` — save session for current directory

---

### Git and code context
#### `gitsigns.nvim`
Shows git signs and hunk actions.

Common keymaps:
- `]h` / `[h` — next / previous hunk
- `<leader>hs` / `<leader>hr` — stage / reset hunk
- `<leader>hS` / `<leader>hR` — stage / reset buffer
- `<leader>hu` — undo stage hunk
- `<leader>hp` — preview hunk
- `<leader>hb` — blame line
- `<leader>hB` — toggle line blame
- `<leader>hd` / `<leader>hD` — diff buffer / diff against `~`

#### `todo-comments.nvim`
Highlights TODO-style comments and supports navigation.

Keymaps:
- `]t` — next TODO comment
- `[t` — previous TODO comment

#### `Comment.nvim`
Comment toggling with Treesitter-aware comment strings for TSX/JSX/HTML.

#### `nvim-surround`
Surround editing helpers.

#### `substitute.nvim`
Substitution helpers for motions, lines, and selections.

#### `which-key.nvim`
Shows available key combinations as you type them.

---

## LSP, completion, formatting, and linting

### `mason.nvim`
Installs language servers and tools.

#### LSP servers
- `ts_ls`
- `html`
- `cssls`
- `tailwindcss`
- `lua_ls`
- `graphql`
- `emmet_ls`
- `prismals`
- `pyright`
- `jdtls`

#### Tools
- `prettier`
- `stylua`
- `isort`
- `black`
- `pylint`
- `eslint_d`

### `nvim-lspconfig`
Configures language servers and shared LSP behavior.

#### LSP UI
- rounded borders for hover and signature help
- diagnostics configured with severity sorting, floating borders, and virtual text
- document highlights on cursor hold where supported
- inlay-hints toggle on `<leader>th` where supported

#### LSP keymaps
- `gR` — references
- `gD` — declaration
- `gd` — definitions
- `gi` — implementations
- `gt` — type definitions
- `<leader>ca` — code action
- `<leader>rn` — rename
- `<leader>D` — buffer diagnostics
- `<leader>d` — line diagnostics
- `[d` / `]d` — previous / next diagnostic
- `K` — hover docs
- `<leader>rs` — restart LSP

#### Server-specific settings
- `lua_ls` uses LuaJIT, recognizes `vim`, disables third-party prompts, and disables telemetry
- `graphql` supports GraphQL, `gql`, `typescriptreact`, and `javascriptreact`
- `emmet_ls` supports HTML, React, and common style languages

### `nvim-cmp`
Provides insert-mode completion.

Dependencies:
- `cmp-buffer`
- `cmp-path`
- `LuaSnip`
- `cmp_luasnip`
- `friendly-snippets`
- `lspkind.nvim`

Keymaps:
- `<C-Space>` — trigger completion
- `<C-j>` / `<C-k>` — next / previous item
- `<C-b>` / `<C-f>` — scroll documentation
- `<C-e>` — abort completion
- `<CR>` — confirm selection

### `conform.nvim`
Formats files on save and provides `<leader>mp` for manual formatting.

Formatters:
- JavaScript / TypeScript / React / HTML / CSS / JSON / YAML / Markdown / GraphQL / Liquid: `prettier`
- Lua: `stylua`
- Python: `isort`, `black`

### `nvim-lint`
Runs linting automatically on enter, write, and insert leave.

Linters:
- JavaScript / TypeScript / React: `eslint_d`
- Python: `pylint`

Keymap:
- `<leader>l` — lint current file

---

## Treesitter

### `nvim-treesitter`
Provides highlighting, indentation, autotagging, and incremental selection.

Enabled features:
- syntax highlighting
- Treesitter indentation
- autotagging
- incremental selection

Selection keys:
- `<C-space>` — expand selection
- `<bs>` — shrink selection

Installed parsers:
- `json`
- `java`
- `go`
- `javascript`
- `typescript`
- `tsx`
- `yaml`
- `html`
- `css`
- `prisma`
- `markdown`
- `markdown_inline`
- `graphql`
- `bash`
- `lua`
- `vim`
- `dockerfile`
- `gitignore`
- `query`
- `vimdoc`
- `c`

---

## Notes

The config is modular and lazy-loaded for fast startup.
