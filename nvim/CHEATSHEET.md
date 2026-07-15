# Neovim Cheat Sheet

**Leader:** `<Space>`

## General
- `<leader>nh` — clear search highlights
- `<leader>+` / `<leader>-` — increment / decrement number under cursor

## Markdown
- `<leader>tm` — toggle rendered markdown view (`:RenderMarkdown toggle`)

## Buffer tabs (bufferline.nvim)
- `<leader>tt` — new empty buffer
- `<leader>tw` — close current buffer
- `<leader>to` — close all other buffers
- `<M-l>` — next buffer
- `<M-h>` — previous buffer
- `<leader>tl` — move buffer right
- `<leader>th` — move buffer left
- `<leader>t1`-`t9` — go to buffer 1-9

## Terminal
- `<leader>ot` — toggle bottom terminal
- `<leader>oT` — open floating terminal
- `:SnacksTerminal` — toggle terminal
- `:SnacksTerminalFloat` — open floating terminal
- in terminal mode, `<leader>ot` also toggles the terminal


## Files and search
- `<leader>ee` — open file explorer
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

## Comments
- `gcc` — toggle line comment
- `gc` — toggle comment for motion or visual selection
- `gbc` — toggle block comment on current line
- `gb` — toggle block comment for motion or visual selection

## Sessions and git tools
- Sessions are automatically restored on open and saved on exit.
- `<leader>lg` — open LazyGit
- `:SnacksLazyGit` — open LazyGit

## Pi AI (Snacks)
- `<leader>ai` — toggle Pi in a floating window
- `<M-k>` — same as `<leader>ai`
- `<leader>pI` — open a fresh Pi session

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

## Build & Run (overseer.nvim)
- `<leader>mm` — run task
- `<leader>mr` — rerun last task
- `<leader>mk` — task actions (stop/restart)
- `<leader>m,` — toggle task list panel
- `<leader>mb` — build task
- `<leader>mc` — cancel running task

### Panel layout

When a task runs, the bottom splits into two panes:

```
┌──────────────────────┬───────────────────────┐
│   Task list          │   Task output pane    │
│   (OverseerList)     │   (live terminal)     │
│                      │                       │
│  ● npm: stack:prod   │   > nx run-many -t    │
│  ○ npm: build        │   serve -c prod       │
│  ○ npm: test         │   — parallel=4        │
└──────────────────────┴───────────────────────┘
```

### Task list controls (when focused)

| Keys         | Action                           |
| ------------ | -------------------------------- |
| `j` / `k`    | Navigate tasks                   |
| `<CR>`       | Action menu (stop/restart/etc.)  |
| `o`          | Open task output                 |
| `dd`         | Dispose (remove) task            |
| `q`          | Close task list panel            |
| `p`          | Toggle preview                   |
| `{` / `}`    | Previous / next task             |
| `<C-e>`      | Edit task                        |
| `<C-v>`      | Open output in vsplit            |
| `<C-s>`      | Open output in split             |
| `<C-t>`      | Open output in tab               |
| `<C-f>`      | Open output in float             |

### Pro tip

- From your code, `<C-w>j` moves down to the task list, `<C-w>l` to output, `<C-w>k` back up.
- `<leader>m,` toggles the whole panel on/off.
- Resize by default: task list grows up to 15 rows, then scrolls.

## Window Management

| Keys         | Action                           |
| ------------ | -------------------------------- |
| `<C-w>s`     | Split horizontally               |
| `<C-w>v`     | Split vertically                 |
| `<C-w>c`     | Close current pane               |
| `<C-w>o`     | Close all other panes            |
| `<C-w>h`     | Move left one pane               |
| `<C-w>l`     | Move right one pane              |
| `<C-w>j`     | Move down one pane               |
| `<C-w>k`     | Move up one pane                 |
| `<C-w>w`     | Cycle to next pane               |
| `<C-w>-`     | Decrease pane height             |
| `<C-w>+`     | Increase pane height             |
| `<C-w><`     | Decrease pane width              |
| `<C-w>>`     | Increase pane width              |
| `<C-w>=`     | Equalise all pane sizes          |
| `<C-w>_`     | Maximise current pane height     |
| `<C-w>|`     | Maximise current pane width      |

## Debug
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

## Completion
- `<C-Space>` — trigger completion
- `<CR>` — confirm completion
- `<C-j>` / `<C-k>` — next / previous item
- `<C-b>` / `<C-f>` — scroll docs
- `<C-e>` — abort completion

## Treesitter selection
- `<C-Space>` — expand selection
- `<bs>` — shrink selection
