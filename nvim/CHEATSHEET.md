# Neovim Cheat Sheet

**Leader:** `<Space>`

## Core
- `<leader>nh` — clear search highlights
- `<leader>+` / `<leader>-` — increment / decrement number

## Windows / Tabs
- `<leader>sv` — vertical split
- `<leader>sh` — horizontal split
- `<leader>se` — equalize splits
- `<leader>sx` — close split
- `<leader>sm` — maximize/minimize split
- `<leader>tt` — new tab
- `<leader>tw` — close tab
- `<leader>tl` / `<leader>th` — next / previous tab
- `<leader>ty` — move current buffer to new tab

## Files
_Current stack (Phase 3)_
- `<leader>ee` — open Snacks explorer
- `<leader>ef` — reveal current file in Snacks explorer
- `<leader>ff` — find files (`Snacks.picker`)
- `<leader>fr` — recent files (`Snacks.picker`)
- `<leader>fs` — live grep (`Snacks.picker`)
- `<leader>fc` — grep word under cursor (`Snacks.picker`)
- `<leader>ft` — TODOs (`Snacks.picker`)

_Snacks explorer buffer actions_
- `<CR>` / `l` — open file or toggle directory
- `h` — close directory
- `<BS>` — go up one directory
- `a` — add file or directory
- `r` — rename current file or directory
- `d` — delete current file or directory
- `u` — refresh / update explorer
- `H` — toggle hidden files
- `I` — toggle ignored files

_Alternate Snacks commands_
- `:SnacksExplorer` — open Snacks explorer
- `:SnacksReveal` — reveal current file in Snacks explorer
- `:SnacksFiles` — open Snacks file picker
- `:SnacksRecent` — open Snacks recent files picker
- `:SnacksGrep` — open Snacks grep picker

## LSP
_Current stack_
- `gd` — definitions (`Snacks.picker`)
- `gD` — declaration
- `gi` — implementations (`Snacks.picker`)
- `gt` — type definitions (`Snacks.picker`)
- `gR` — references (`Snacks.picker`)
- `K` — hover docs
- `<leader>ca` — code action
- `<leader>rn` — rename
- `<leader>d` — line diagnostics
- `<leader>D` — buffer diagnostics (`Snacks.picker`)
- `[d` / `]d` — prev / next diagnostic
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

## Formatting / Linting
- `<leader>mp` — format file / selection
- `<leader>l` — lint current file

## Sessions / Git tools
- `<leader>wr` — restore session
- `<leader>ws` — save session
- `<leader>lg` — open LazyGit (`Snacks.lazygit`)
- `:SnacksLazyGit` — open Snacks lazygit

## Pi AI
- `<leader>pi` — toggle Pi float
- `<leader>pI` — start a new Pi session for the current repo
- `:Pi` — open Pi
- `:PiToggle` — toggle Pi
- `:PiNew` — new Pi session

## Text editing
- `s` — substitute with motion
- `ss` — substitute line
- `S` — substitute to end of line
- visual `s` — substitute selection
- `ih` — select git hunk

## Trouble
- `<leader>xx` — diagnostics list
- `<leader>xw` — workspace diagnostics
- `<leader>xd` — document diagnostics
- `<leader>xq` — quickfix list
- `<leader>xl` — location list
- `<leader>xt` — TODOs in Trouble

## Completion
- `<C-Space>` — trigger completion
- `<CR>` — confirm completion
- `<C-j>` / `<C-k>` — next / previous item
- `<C-b>` / `<C-f>` — scroll docs
- `<C-e>` — abort completion

## Treesitter selection
- `<C-Space>` — expand selection
- `<bs>` — shrink selection
