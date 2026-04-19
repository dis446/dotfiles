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
- `<leader>ee` — toggle file explorer
- `<leader>ef` — toggle explorer on current file
- `<leader>ec` — collapse tree
- `<leader>er` — refresh tree
- `a` — create new file in `nvim-tree` buffer
- `r` — rename file/directory in `nvim-tree` buffer
- `d` — delete file/directory in `nvim-tree` buffer
- `<leader>ff` — find files
- `<leader>fr` — recent files
- `<leader>fs` — live grep
- `<leader>fc` — grep word under cursor
- `<leader>ft` — TODOs

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
- `<leader>lg` — LazyGit

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
- `<leader>xx` — toggle Trouble
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
