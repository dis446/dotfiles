# Neovim Cheat Sheet

**Leader:** `<Space>`

## General
- `<leader>nh` — clear search highlights
- `<leader>+` / `<leader>-` — increment / decrement number under cursor

## Windows and tabs
- `<leader>sv` — vertical split
- `<leader>sh` — horizontal split
- `<leader>se` — equalize splits
- `<leader>sx` — close split
- `<leader>sm` — maximize/minimize split (`Snacks.zen.zoom()`)
- `<leader>tt` — new tab
- `<leader>tw` — close tab
- `<leader>tl` / `<leader>th` — next / previous tab
- `<leader>ty` — move current buffer to new tab

## Terminal
- `<leader>ot` — toggle bottom terminal
- `<leader>oT` — open floating terminal
- `:SnacksTerminal` — toggle terminal
- `:SnacksTerminalFloat` — open floating terminal
- in terminal mode, `<leader>ot` also toggles the terminal

## Files and search
- `<leader>ee` — toggle file explorer
- `<leader>ef` — reveal current file in explorer
- `<leader>ff` — find files
- `<leader>fr` — recent files
- `<leader>fs` — live grep
- `<leader>fc` — grep word under cursor
- `<leader>ft` — TODOs
- `:SnacksExplorer` — open explorer
- `:SnacksReveal` — reveal current file in explorer
- `:SnacksFiles` — open file picker
- `:SnacksRecent` — open recent files picker
- `:SnacksGrep` — open grep picker

## LSP
- `gd` — definitions
- `gD` — declaration
- `gi` — implementations
- `gt` — type definitions
- `gR` — references
- `K` — hover docs
- `<leader>ca` — code action
- `<leader>rn` — rename
- `<leader>d` — line diagnostics
- `<leader>D` — buffer diagnostics
- `[d` / `]d` — previous / next diagnostic
- `<leader>rs` — restart LSP
- `<leader>th` — toggle inlay hints

## Git
- `]h` / `[h` — next / previous hunk
- `<leader>hs` / `<leader>hr` — stage / reset hunk
- `<leader>hS` / `<leader>hR` — stage / reset buffer
- `<leader>hu` — undo stage hunk
- `<leader>hp` — preview hunk
- `<leader>hb` — blame line
- `<leader>hB` — toggle line blame
- `<leader>hd` / `<leader>hD` — diff buffer / diff against `~`

## Formatting and linting
- `<leader>mp` — format file or selection
- `<leader>l` — lint current file

## Sessions and git tools
- `<leader>wr` — restore session for current directory
- `<leader>ws` — save session for current directory
- `<leader>lg` — open LazyGit
- `:SnacksLazyGit` — open LazyGit

## Pi AI
- `<leader>pi` — open/focus Pi in a right-side pane; if already focused, close it
- `<leader>pI` — start a new Pi session in the right-side pane for the current repo
- `:Pi` — open/focus Pi pane
- `:PiToggle` — open/focus Pi pane; if already focused, close it
- `:PiNew` — start a new Pi session in the Pi pane
- in the Pi pane, `<C-x>` — close the pane

## Editing
- `s` — substitute with motion
- `ss` — substitute line
- `S` — substitute to end of line
- visual `s` — substitute selection
- `ih` — select git hunk

## Diagnostics and lists
- `<leader>xx` — diagnostics list
- `<leader>xw` — workspace diagnostics
- `<leader>xd` — document diagnostics
- `<leader>xq` — quickfix list
- `<leader>xl` — location list
- `<leader>xt` — TODO list

## Completion
- `<C-Space>` — trigger completion
- `<CR>` — confirm completion
- `<C-j>` / `<C-k>` — next / previous item
- `<C-b>` / `<C-f>` — scroll docs
- `<C-e>` — abort completion

## Treesitter selection
- `<C-Space>` — expand selection
- `<bs>` — shrink selection
