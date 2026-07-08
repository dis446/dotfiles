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

#### Clipboard
- `clipboard += unnamedplus`

---

## Global keymaps

### `lua/dis446/core/keymaps.lua`

Leader key: `Space`

#### General
- `<leader>nh` — clear search highlights
- `<leader>+` — increment number under cursor
- `<leader>-` — decrement number under cursor

#### Tabs
- `<leader>tt` — open new tab
- `<leader>tw` — close current tab
- `<C-Tab>` — next tab
- `<C-S-Tab>` — previous tab

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
- `terminal`
- `notifier`
- `quickfile`
- `bigfile`
- `zen`

Keymaps:
- `<leader>ee` — open file explorer
- `<leader>ef` — reveal current file in explorer
- `<leader>ff` — find files
- `<leader>fr` — recent files
- `<leader>fs` — live grep
- `<leader>fc` — grep word under cursor
- `<leader>ft` — TODOs
- `<leader>lg` — open LazyGit
- `<leader>ot` — toggle terminal (works in normal and terminal mode)
- `<leader>oT` — open floating terminal
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
- `:SnacksTerminal`
- `:SnacksTerminalFloat`

Dashboard buttons open new files, the explorer, file search, grep, session restore, and quit.

---

### Terminal
#### `Snacks.terminal()`
Provides an integrated terminal view without adding a separate terminal plugin.

Behavior:
- default shell opens as a bottom split
- floating terminal is available for temporary shell work
- terminal toggling works from normal mode and terminal mode with `<leader>ot`

Commands and keymaps:
- `<leader>ot` — toggle terminal
- `<leader>oT` — open floating terminal
- `:SnacksTerminal` — toggle terminal
- `:SnacksTerminalFloat` — open floating terminal


### Session management
#### `auto-session`
Manages session save and restore per directory. Automatically restores sessions when opening Neovim in a directory and saves on exit.

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

## Debug (DAP)

### `nvim-dap`
The Debug Adapter Protocol integration for Neovim. Provides breakpoints, stepping,
variable inspection, and evaluation.

Dependencies:
- `rcarriga/nvim-dap-ui` — UI panels (scopes, stacks, breakpoints, watches, REPL)
- `theHamsta/nvim-dap-virtual-text` — inline variable values at cursor
- `jay-babu/mason-nvim-dap.nvim` — install DAP adapters via Mason

Adapters installed via Mason:
- `python` — debugpy
- `js-debug-adapter` — vscode-js-debug (JS/TS)
- `java-debug-adapter` + `java-test` — loaded as jdtls bundles

Adapter configurations:
- **Python:** debugpy via Mason's bundled venv
- **JS/TS:** pwa-node protocol via `dapDebugServer.js`, supports `node` and `tsx`
- **Go:** Delve (`dlv dap`)
- **Java:** via `nvim-jdtls` (`jdtls.setup_dap()`) in `lsp/jdtls.lua`

DAP UI auto-opens on debug start, auto-closes on terminate/exit.

### Keymaps
- `<leader>rd` — start / continue debug
- `<F5>` — continue
- `<F10>` — step over
- `<F11>` — step into
- `<S-F11>` — step out
- `<leader>dt` — toggle breakpoint
- `<leader>du` — toggle DAP UI panels
- `<leader>de` — evaluate expression
- `<leader>dr` — run to cursor
- `<leader>dR` — restart debug session
- `<leader>dq` — terminate debug session

**F-key note:** F5/F10/F11 work outside zellij, or when zellij passes F-keys
through. Inside zellij, use the `<leader>d*` alternatives.

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
- `jsonls`
- `yamlls`
- `bashls`
- `dockerls`
- `sqls`
- `marksman`

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

### `blink.cmp`
Provides insert-mode completion. LSP, buffer, path, and snippet sources are
built in, so no per-source adapter plugins are needed. Kind icons are rendered
by blink itself (no `lspkind`). Nothing is preselected — `<CR>` only confirms an
item you explicitly moved to.

Dependencies:
- `LuaSnip` — snippet engine (blink uses it via `snippets.preset = "luasnip"`)
- `friendly-snippets`

Snippet expansion still flows through `LuaSnip` + `friendly-snippets`.

Keymaps:
- `<C-Space>` — trigger completion / toggle documentation
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

## Debug (DAP)

### `nvim-dap`
The Debug Adapter Protocol integration for Neovim. Provides breakpoints, stepping,
variable inspection, and evaluation.

**Adapter configurations:**
- **Python** — `debugpy` via Mason (minimal config, `justMyCode` toggle)
- **JS/TS** — `pwa-node` via `js-debug-adapter` (Mason), supports `node` and `tsx`
- **Go** — `delve` (`dlv dap`)
- **Java** — via `nvim-jdtls` bundle loading (`java-debug-adapter` + `java-test`)

#### Keymaps
- `<leader>rd` — start / continue debug
- `<F5>` — continue
- `<F10>` — step over
- `<F11>` — step into
- `<S-F11>` — step out
- `<leader>dt` — toggle breakpoint
- `<leader>du` — toggle DAP UI panels
- `<leader>de` — evaluate expression
- `<leader>dr` — run to cursor
- `<leader>dR` — restart debug session
- `<leader>dq` — terminate debug session

**F-key note:** F5/F10/F11 work outside zellij, or when zellij passes F-keys
through. Inside zellij, use the `<leader>d*` alternatives.

### `nvim-dap-ui`
UI widgets for DAP: scopes, stacks, breakpoints, watches, and REPL.
- Layout: scopes/stacks/breakpoints (right panel, 50 cols) + watches/REPL (bottom, 12 rows)
- Auto-opens when a debug session starts, auto-closes on terminate/exit

#### Debugging Quarkus apps (remote attach workflow)
Quarkus has no static main class — the Maven plugin generates the entry point at
build time. Debug via remote attach:

1. **Terminal (zellij pane):**
   ```bash
   cd /path/to/quarkus-project
   set -a; source .env.local; set +a
   ./mvnw quarkus:dev -DskipTests
   ```
   Quarkus dev mode starts a JVM debugger on port **5005** by default.

2. **Neovim:** open any Java file in the project, then press `<leader>rd`.
   Pick **"Attach (port 5005)"** from the configuration list.

3. Set breakpoints with `<leader>dt` and exercise your endpoint.

### `nvim-dap-virtual-text`
Shows variable values inline at end-of-line while debugging.

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
