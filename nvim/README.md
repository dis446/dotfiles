# @nvim configuration

This directory contains my Neovim config.

## Startup flow

### `init.lua`
This is the entrypoint:

```lua
require("dis446.core")
require("dis446.lazy")
```

So startup happens in two phases:

1. Load core editor settings and keymaps
2. Bootstrap and configure `lazy.nvim`, which loads plugins

### `lua/dis446/core/init.lua`
This loads:

- `dis446.core.options`
- `dis446.core.keymaps`

### `lua/dis446/lazy.lua`
This bootstraps `lazy.nvim` if it is missing, then loads plugin specs from:

- `dis446.plugins`
- `dis446/plugins/lsp`

It also enables:

- update checks
- no update notifications
- no change-detection notifications

---

## Core editor settings

### `lua/dis446/core/options.lua`

#### Line numbers
- `relativenumber = true` — show relative line numbers
- `number = true` — show the absolute line number on the current line

#### Tabs and indentation
- `tabstop = 2` — tabs display as 2 spaces
- `shiftwidth = 2` — indent operations use 2 spaces
- `expandtab = true` — insert spaces instead of tabs
- `autoindent = true` — copy indentation from the previous line

#### Wrapping
- `wrap = false` — long lines do not wrap

#### Search
- `ignorecase = true` — searches are case-insensitive by default
- `smartcase = true` — uppercase letters make the search case-sensitive

#### UI
- `cursorline = true` — highlight the current line
- `termguicolors = true` — enable true color support
- `background = "dark"` — tell Neovim to use a dark theme baseline
- `signcolumn = "yes"` — always reserve space for signs like diagnostics and git markers

#### Editing behavior
- `backspace = "indent,eol,start"` — allow backspacing across indentation, end-of-line, and insert start

#### Clipboard
- `clipboard:append("unnamedplus")` — sync yank/paste with the system clipboard

#### Split behavior
- `splitright = true` — vertical splits open on the right
- `splitbelow = true` — horizontal splits open below

#### Built-in netrw
- `let g:netrw_liststyle = 3` — set the built-in file browser to tree view

---

## Core keymaps

### `lua/dis446/core/keymaps.lua`

Leader key:
- `Space`

#### General
- `<leader>nh` — clear search highlights
- `<leader>+` — increment number under cursor
- `<leader>-` — decrement number under cursor

#### Window management
- `<leader>sv` — vertical split
- `<leader>sh` — horizontal split
- `<leader>se` — equalize split sizes
- `<leader>sx` — close current split

#### Tabs
- `<leader>tt` — open new tab
- `<leader>tw` — close current tab
- `<leader>tl` — next tab
- `<leader>th` — previous tab
- `<leader>ty` — open current buffer in a new tab

---

## Plugin manager

### `lua/dis446/lazy.lua`
This uses `lazy.nvim` as the plugin manager.

It installs `lazy.nvim` automatically if needed, then loads all plugin specs.

It also configures:

- `checker.enable = true` — check for plugin updates automatically
- `checker.notify = false` — do not show update notifications
- `change_detection.notify = false` — do not notify when config changes are detected

---

## Plugins

### Shared utility plugins
#### `lua/dis446/plugins/init.lua`
- `plenary.nvim` — utility Lua functions used by many plugins
- `vim-tmux-navigator` — move between Neovim splits and tmux panes

---

### Colorscheme
#### `tokyonight.nvim`
Loaded early with high priority so other plugins inherit the theme.

Configuration:
- `style = "night"`
- custom color overrides for backgrounds, highlights, gutters, borders, and foregrounds

This is the active colorscheme for the entire UI.

---

### Dashboard / explorer / picker consolidation
#### `snacks.nvim`
`snacks.nvim` now provides the dashboard and file explorer, and also owns the active file/search pickers.

Enabled modules right now:
- `dashboard`
- `explorer`
- `picker`
- `lazygit`
- `rename`
- `notifier`
- `quickfile`
- `bigfile`

Still intentionally disabled for later phases:
- `input`
- `indent`

Dashboard:
- custom ASCII art header
- buttons for:
  - new file
  - open explorer
  - find file
  - live grep
  - restore session
  - quit

Explorer:
- replaces `netrw`
- `<leader>ee` — open explorer
- `<leader>ef` — reveal current file in explorer

Picker:
- `<leader>ff` — find files
- `<leader>fr` — recent files
- `<leader>fs` — live grep
- `<leader>fc` — grep word under cursor
- `<leader>ft` — TODOs

Extra test / direct commands:
- `:SnacksExplorer`
- `:SnacksReveal`
- `:SnacksFiles`
- `:SnacksRecent`
- `:SnacksGrep`
- `:SnacksLazyGit`

---

### Buffer/tab line
#### `bufferline.nvim`
Configured to show `tabs` mode with `slant` separators.

Uses `nvim-web-devicons` for file icons.

---

### Split maximizer
#### `vim-maximizer`
Provides a simple toggle to maximize/minimize the current split.

Keymap:
- `<leader>sm`

---

### Session management
#### `auto-session`
Manages workspace sessions.

Settings:
- `auto_restore_enabled = false` — do not restore automatically on startup
- `auto_session_suppress_dirs` — skip session handling in common top-level directories

Keymaps:
- `<leader>wr` — restore session for current directory
- `<leader>ws` — save session for current directory

---

### Git integration
#### `gitsigns.nvim`
Shows git changes in the gutter and provides hunk actions.

Keymaps:
- `]h` / `[h` — next/previous hunk
- `<leader>hs` — stage hunk
- `<leader>hr` — reset hunk
- visual `<leader>hs` / `<leader>hr` — stage/reset selected hunks
- `<leader>hS` — stage buffer
- `<leader>hR` — reset buffer
- `<leader>hu` — undo stage hunk
- `<leader>hp` — preview hunk
- `<leader>hb` — blame current line
- `<leader>hB` — toggle line blame
- `<leader>hd` — diff current buffer
- `<leader>hD` — diff current buffer against `~`
- `ih` — select hunk text object

---

### LazyGit
#### `lazygit.nvim` + `snacks.lazygit`
Your normal keymap still points at `lazygit.nvim`:

- `<leader>lg` — open LazyGit

You also have a Snacks-backed command available during the migration:

- `:SnacksLazyGit` — open Snacks lazygit

---

### Pi AI
#### `pi.nvim`
Opens Pi in a floating terminal window with repo-aware session persistence.

Behavior:
- detects the current git root
- stores sessions under Neovim state in a per-repo directory
- resumes the most recent session for that repo when one exists
- keeps the float as a UI wrapper; the session is the durable state

Commands:
- `:Pi` — open Pi in a float
- `:PiToggle` — toggle the Pi float
- `:PiNew` — start a fresh Pi session for the current repo

Keymaps:
- `<leader>pi` — toggle Pi
- `<leader>pI` — start a new Pi session

---

### Commenting
#### `Comment.nvim`
Smart commenting support.

It uses `nvim-ts-context-commentstring` so comments are correct in embedded languages such as:

- TSX / JSX
- HTML

---

### Autopairs
#### `nvim-autopairs`
Automatically inserts matching pairs for brackets, quotes, and similar delimiters.

Settings:
- `check_ts = true` — use Treesitter awareness
- language-specific Treesitter exclusions for Lua strings, JavaScript template strings, and Java

It also integrates with `nvim-cmp` so confirming completion can insert matching pairs automatically.

---

### Surround editing
#### `nvim-surround`
Adds motions for adding, changing, and deleting surrounds such as quotes, brackets, tags, and other delimiters.

---

### Substitute motions
#### `substitute.nvim`
Enhanced substitution commands.

Keymaps:
- `s` — substitute with motion
- `ss` — substitute current line
- `S` — substitute to end of line
- visual `s` — substitute selected text

---

### Picker
#### `snacks.picker`
The active picker stack is now `Snacks.picker`.

It powers:
- file search
- recent files
- grep
- grep word under cursor
- TODO pickers
- LSP location pickers
- buffer diagnostics picker

Active keymaps:
- `<leader>ff` — find files
- `<leader>fr` — recent files
- `<leader>fs` — live grep
- `<leader>fc` — grep string under cursor
- `<leader>ft` — find todos
- `gd` / `gi` / `gt` / `gR` — LSP pickers
- `<leader>D` — buffer diagnostics picker

---

### TODO comments
#### `todo-comments.nvim`
Highlights TODO-style comments and lets you jump between them.

Keymaps:
- `]t` — next TODO comment
- `[t` — previous TODO comment

Also powers Snacks picker and Trouble integrations for TODO search.

---

### Trouble
#### `trouble.nvim`
A nicer UI for diagnostics, quickfix, and location lists.

Keymaps:
- `<leader>xx` — toggle Trouble
- `<leader>xw` — workspace diagnostics
- `<leader>xd` — document diagnostics
- `<leader>xq` — quickfix list
- `<leader>xl` — location list
- `<leader>xt` — TODOs in Trouble

---

### Indent guides
#### `indent-blankline.nvim`
Shows indentation guides using the `ibl` module.

Settings:
- indent character = `┊`

---

### UI prompts
#### `dressing.nvim`
Improves `vim.ui.select` and `vim.ui.input` with nicer popups.

Loaded lazily to avoid startup cost.

---

### Keybinding helper
#### `which-key.nvim`
Shows available key combinations as you type them.

Settings:
- `timeout = true`
- `timeoutlen = 300`

This makes leader-key discovery easier.

---

## LSP, completion, formatting, and linting

### Mason
#### `mason.nvim`
Manages installation of language servers and other developer tools.

UI icons:
- installed: `✓`
- pending: `➜`
- uninstalled: `✗`

#### `mason-lspconfig.nvim`
Automatically installs configured LSP servers.

Configured servers:
- `html`
- `cssls`
- `tailwindcss`
- `lua_ls`
- `graphql`
- `emmet_ls`
- `prismals`
- `pyright`
- `jdtls`

#### `mason-tool-installer.nvim`
Automatically installs external tools:
- `prettier`
- `stylua`
- `isort`
- `black`
- `pylint`
- `eslint_d`

---

### LSP configuration
#### `nvim-lspconfig`
Sets up language servers and shared LSP keymaps.

#### On attach keymaps
When an LSP attaches to a buffer, these mappings are added:

- `gR` — references (`Snacks.picker`)
- `gD` — declaration
- `gd` — definitions (`Snacks.picker`)
- `gi` — implementations (`Snacks.picker`)
- `gt` — type definitions (`Snacks.picker`)
- `<leader>ca` — code action
- `<leader>rn` — rename
- `<leader>D` — diagnostics for the file (`Snacks.picker`)
- `<leader>d` — floating diagnostic for the current line
- `[d` / `]d` — previous/next diagnostic
- `K` — hover documentation
- `<leader>rs` — restart the LSP
- `<leader>th` — toggle inlay hints

#### Completion capabilities
`cmp-nvim-lsp` extends LSP capabilities so completion works better with `nvim-cmp`.

#### Diagnostic signs
Custom gutter signs are defined for errors, warnings, hints, and info.

#### Special server setup
- `graphql` — supports GraphQL and React filetypes
- `emmet_ls` — supports HTML, JSX/TSX, and CSS-like languages
- `lua_ls` — knows `vim` is a global, uses `callSnippet = "Replace"`, disables telemetry, and sets `checkThirdParty = false`

---

### Completion
#### `nvim-cmp`
Primary completion engine.

Dependencies:
- `cmp-buffer`
- `cmp-path`
- `LuaSnip`
- `cmp_luasnip`
- `friendly-snippets`
- `lspkind`

Settings:
- `completeopt = "menu,menuone,preview,noselect"`
- snippet expansion via `LuaSnip`

Keymaps:
- `<C-k>` / `<C-j>` — move through suggestions
- `<C-b>` / `<C-f>` — scroll documentation
- `<C-Space>` — trigger completion
- `<C-e>` — abort completion
- `<CR>` — confirm selected completion item

Sources:
- LSP
- snippets
- buffer text
- file paths

Formatting:
- `lspkind` adds pictogram icons to completion entries


---

### Formatting
#### `conform.nvim`
Runs formatters on save and manually via keymap.

Configured formatters by filetype:
- JavaScript / TypeScript / React / CSS / HTML / JSON / YAML / Markdown / GraphQL / Liquid — `prettier`
- Lua — `stylua`
- Python — `isort` then `black`

Format-on-save:
- uses LSP fallback
- synchronous
- 1000ms timeout

Keymap:
- `<leader>mp` — format current file or visual selection

---

### Linting
#### `nvim-lint`
Runs linters automatically on several events.

Configured linters:
- JavaScript / TypeScript / React — `eslint_d`
- Python — `pylint`

Autocmds trigger linting on:
- `BufEnter`
- `BufWritePost`
- `InsertLeave`

Keymap:
- `<leader>l` — run linting for the current file

---

## Treesitter

### `nvim-treesitter`
Provides syntax-aware parsing, highlighting, indentation, and more.

Also depends on `nvim-ts-autotag`.

Configured features:
- `highlight.enable = true` — syntax highlighting
- `indent.enable = true` — Treesitter-based indentation
- `autotag.enable = true` — auto-close and rename tags
- `incremental_selection` — expand/shrink syntax nodes

Incremental selection keys:
- `<C-space>` — initialize / expand selection
- `<bs>` — shrink selection

Parsers are ensured for many languages, including:
- JSON, Java, Go, JavaScript, TypeScript, TSX
- YAML, HTML, CSS, Prisma
- Markdown, GraphQL, Bash, Lua, Vim, Dockerfile
- Gitignore, query, vimdoc, C

---

## Notes

The config is intentionally modular and plugin-driven, with most functionality loaded lazily for faster startup.

---

## Summary

This config is a modular Neovim setup centered around:

- `lazy.nvim` for plugin management
- `tokyonight` for the UI theme
- `snacks.nvim` and `bufferline` for navigation
- `mason` + `lspconfig` + `nvim-cmp` for language support
- `conform` and `nvim-lint` for code quality tooling
- `treesitter` for syntax awareness
- `gitsigns`, `trouble`, and `todo-comments` for project feedback
- `which-key` and a collection of keymaps for discoverability
