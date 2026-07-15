# Unified Keybindings

> **One keybinding set, two environments.**

---

## Leader: `Space`

In IntelliJ, set `let mapleader = " "` in `.ideavimrc`.
In Neovim, set `vim.g.mapleader = " "` in `keymaps.lua`.

## General

| Key        | Action              | IntelliJ backend            | Neovim backend                        |
| ---------- | ------------------- | --------------------------- | ------------------------------------- |
| `Space+si` | Reload config        | `:source ~/.ideavimrc`      | `:source $MYVIMRC`                    |
| `Space+nh` | Clear search hilite | `:noh`                      | `:nohl`                               |

## File & project navigation

| Key          | Action                              | IntelliJ backend            | Neovim backend                  |
| ------------ | ----------------------------------- | --------------------------- | ------------------------------- |
| `Space+ee`   | Toggle file explorer / project tree | `ActivateProjectToolWindow` | `Snacks.explorer()`             |
| `Space+ef`   | Reveal current file in tree         | `SelectInProjectView`       | `Snacks.explorer.reveal()`      |
| `Space+ff`   | Find file by name                   | `GotoFile`                  | `Snacks.picker.files()`         |
| `Ctrl+N`     | Find file by name (alt)             | `GotoFile`                  | `Snacks.picker.files()`         |
| `Space+fr`   | Recent files                        | `RecentFiles`               | `Snacks.picker.recent()`        |
| `Ctrl+E`     | Recent files (alt)                  | `RecentFiles`               | `Snacks.picker.recent()`        |
| `Space+fs`   | Search text in project (grep)       | `FindInPath`                | `Snacks.picker.grep()`          |
| `Space+fc`   | Search word under cursor            | `FindInPath` (pre-filled)   | `Snacks.picker.grep_word()`     |
| `Space+ft`   | Find TODOs                          | `ActivateTODOToolWindow`    | `Snacks.picker.todo_comments()` |

**Note:** `Ctrl+N` and `Ctrl+E` are alternate bindings for `Space+ff` and `Space+fr`
respectively. They work the same in both environments.

## Buffer tabs

Buffer tabs show open buffers as a tabline at the top of the editor. In IntelliJ
tabs are built-in (open editor files). In Neovim, `akinsho/bufferline.nvim` adds
the same experience.

| Key        | Action              | IntelliJ backend    | Neovim backend                        |
| ---------- | ------------------- | ------------------- | ------------------------------------- |
| `Space+tw` | Close current tab   | `CloseContent`      | `:bdelete!`                           |
| `Alt+L`    | Next tab            | `NextTab`           | `BufferLineCycleNext`                 |
| `Alt+H`    | Previous tab        | `PreviousTab`       | `BufferLineCyclePrev`                 |
| `Space+tt` | New tab page         | —                   | `:tabnew`                              |
| `Space+tl` | Move tab right      | —                   | `BufferLineMoveNext`                   |
| `Space+th` | Move tab left       | —                   | `BufferLineMovePrev`                   |
| `Space+t1`-`9` | Go to tab 1-9  | —                   | `BufferLineGoToBuffer 1-9`             |
| `Space+tp` | Previous tab page   | —                   | `BufferLineCyclePrev`                  |
| `Space+tn` | Next tab page       | —                   | `BufferLineCycleNext`                  |
| `Space+to` | Close other tabs    | `CloseAllEditorsButActive` | Close all buffers except current |

**Note:** `Ctrl+W` is reserved in Neovim for window management and is not
remapped. Use `Space+tw` to close buffers.

## Git

| Key        | Action             | IntelliJ backend          | Neovim backend     |
| ---------- | ------------------ | ------------------------- | ------------------ |
| `Space+lg` | LazyGit (full TUI) | `Lazygit.Toggle` (plugin) | `Snacks.lazygit()` |
| `Space+lc` | Commit             | `CheckinProject`          | — (use lazygit)    |
| `Space+lp` | Push               | `Vcs.Push`                | — (use lazygit)    |
| `Space+lu` | Pull / update      | `Vcs.UpdateProject`       | — (use lazygit)    |

**Note:** `Space+lc`/`lp`/`lu` are **IntelliJ-only** convenience bindings. In
Neovim, perform commit/push/pull inside lazygit.

## Window management

| Key        | Action                       | IntelliJ backend               | Neovim backend                |
| ---------- | ---------------------------- | ------------------------------ | ----------------------------- |
| `Space+sv` | Vertical split               | `SplitVertically`              | `<C-w>v`                      |
| `Space+sh` | Horizontal split             | `SplitHorizontally`            | `<C-w>s`                      |
| `Space+se` | Equalize split sizes         | —                              | `<C-w>=`                      |
| `Space+sx` | Close current split          | `CloseContent`                 | `:close`                      |
| `Space+sm` | Maximize / minimize split    | —                              | `Snacks.zen.zoom()`           |

## Formatting & linting

| Key        | Action              | IntelliJ backend     | Neovim backend                 |
| ---------- | ------------------- | -------------------- | ------------------------------ |
| `Space+mp` | Format code         | `ReformatCode`       | `conform.format()`             |
| `Space+l`  | Lint current file   | `InspectCode`        | `lint.try_lint()`              |

## Sessions

| Key        | Action                                 | IntelliJ backend     | Neovim backend                 |
| ---------- | -------------------------------------- | -------------------- | ------------------------------ |
| `Space+wr` | Restore session for current directory  | — (automatic)        | `:SessionRestore`              |
| `Space+ws` | Save session for current directory     | — (automatic)        | `:SessionSave`                 |

## LSP / code intelligence

| Key         | Action                     | Both environments                                      |
| ----------- | -------------------------- | ------------------------------------------------------ |
| `gd`        | Go to definition           | Works in both                                          |
| `gD`        | Go to declaration          | Works in both                                          |
| `gi`        | Go to implementation       | Works in both                                          |
| `gt`        | Go to type definition      | Works in both                                          |
| `gR`        | Find references            | Works in both                                          |
| `K`         | Hover / documentation      | Works in both                                          |
| `Space+th`  | Toggle inlay hints         | Works in both                                          |
| `Space+ca`  | Code actions / intentions  | `ShowIntentionActions` / `vim.lsp.buf.code_action`     |
| `Space+rn`  | Rename                     | `RenameElement` / `vim.lsp.buf.rename`                 |
| `[d` / `]d` | Previous / next diagnostic | Works in both                                          |
| `Space+xx`  | Toggle diagnostics list    | `ActivateProblemsViewToolWindow`                       | `Snacks.picker.diagnostics()` |
| `Space+xw`  | Workspace diagnostics      | —                                                      | `Snacks.picker.diagnostics()` |
| `Space+xl`  | Location list              | —                                                      | `Snacks.picker.loclist()` |
| `Space+xq`  | Quickfix list              | —                                                      | `Snacks.picker.qflist()` |
| `Space+xt`  | TODO list                  | `ActivateTODOToolWindow`                               | `Snacks.picker.todo_comments()` |
| `Space+xd`  | Document diagnostics       | `GotoNextError`                                        | `Snacks.picker.diagnostics_buffer()` |

## Terminal

| Key        | Action                    | IntelliJ backend             | Neovim backend                 |
| ---------- | ------------------------- | ---------------------------- | ------------------------------ |
| `Space+ot` | Toggle terminal           | `ActivateTerminalToolWindow` | `Snacks.terminal()`            |
| `Space+oT` | Floating terminal         | — (no mapping)               | `Snacks.terminal()` (floating) |

**Note on Neovim + tmux:** When running Neovim inside a tmux session, you
still have a bash shell available at `Ctrl+b [` for scrollback.
`Space+ot` opens a bottom-split terminal inside Neovim.

**User commands:**
- `:SnacksTerminal` — toggle terminal
- `:SnacksTerminalFloat` — open floating terminal

## Build & run

| Key        | Action                    | IntelliJ backend                     | Neovim backend           |
| ---------- | ------------------------- | ------------------------------------ | ------------------------ |
| `Space+mm` | Run                       | `Run`                                | — (use zellij bash pane) |
| `Space+mn` | Debug / Continue          | `Debug`                              | `dap.continue()`         |
| `Space+mk` | Stop                      | `Stop`                               | — (IntelliJ-only)        |
| `Space+m,` | Run config selector       | `RedesignedRunConfigurationSelector` | — (IntelliJ-only)        |

## Debug (DAP)

| Key        | Action                 | IntelliJ backend       | Neovim backend            |
| ---------- | ---------------------- | ---------------------- | ------------------------- |
| `Space+rd` | Start / continue debug | `Debug`                | `dap.continue()`          |
| `F5`       | Continue               | `ResumeProgram`        | `dap.continue()`          |
| `F10`      | Step over              | `StepOver`             | `dap.step_over()`         |
| `F11`      | Step into              | `StepInto`             | `dap.step_into()`         |
| `<S-F11>`  | Step out               | `StepOut`              | `dap.step_out()`          |
| `Space+dt` | Toggle breakpoint      | `ToggleLineBreakpoint` | `dap.toggle_breakpoint()` |
| `Space+du` | Toggle DAP UI panels   | —                      | `dapui.toggle()`          |
| `Space+de` | Evaluate expression    | `EvaluateExpression`   | `dapui.eval()`            |
| `Space+dr` | Run to cursor          | `RunToCursor`          | `dap.run_to_cursor()`     |
| `Space+dR` | Restart session        | `Rerun`                | `dap.restart()`           |
| `Space+dq` | Terminate session      | `Stop`                 | `dap.terminate()`         |

**Note:** F-keys (F5, F10, F11) work when Neovim runs outside zellij, or when
zellij is configured to pass F-keys through (`pane.focus` unbound from those keys,
or using `F5` passthrough in the layout). Within zellij, use the `Space+d*`
alternatives.

## Pi AI (tmux)

Pi runs in a `Snacks.terminal()` floating window — same pattern as
LazyGit.  Toggle hides/shows; Alt+K works from normal or terminal mode.
New session opens a fresh terminal alongside existing ones.

| Key          | Action                   | IntelliJ backend                | Neovim backend              |
| ------------ | ------------------------ | ------------------------------- | --------------------------- |
| `Space+ai`   | Toggle Pi                | `ActivateAIAssistantToolWindow` | `Snacks.terminal()` pi float  |
| `Alt+K`      | Toggle Pi (alt)          | —                               | `Snacks.terminal()` pi float  |
| `Space+pI`   | New Pi session           | —                               | `Snacks.terminal.open()` pi   |

## Tools

| Key        | Action              | IntelliJ backend                | Neovim backend                 |
| ---------- | ------------------- | ------------------------------- | ------------------------------ |
| `Space+db` | Toggle database     | `ActivateDatabaseToolWindow`    | — (use DataGrip)               |
| `Space+mv` | Toggle maven        | `ActivateMavenToolWindow`       | — (use zellij bash pane)       |

## Vim editing

These work identically in both environments:

| Key                   | Action                    |
| --------------------- | ------------------------- |
| `hjkl`                | Cursor movement           |
| `w` / `b` / `e`       | Word navigation           |
| `0` / `$` / `^`       | Line boundaries           |
| `gg` / `G`            | File boundaries           |
| `dd` / `yy` / `p`     | Cut/copy/paste lines      |
| `ciw` / `di"` / `yap` | Text objects              |
| `u` / `Ctrl+R`        | Undo / redo               |
| `/` / `?`             | Search forward / backward |
| `n` / `N`             | Next / previous match     |
| `:%s/old/new/g`       | Substitute                |
| `Ctrl+D` / `Ctrl+U`   | Scroll half-page          |
| `Ctrl+B` / `Ctrl+F`   | Page up / down            |

---

## Environment-specific defaults

### IntelliJ via IdeaVim (`~/.ideavimrc`)

```vim
set relativenumber
set number
set ignorecase
set smartcase
set scrolloff=3
set clipboard+=unnamedplus
set incsearch
set hlsearch
set ideajoin
set NERDTree
let g:NERDTreeMapActivateNode = 'l'
let g:NERDTreeMapJumpParent = 'h'
let g:NERDTreeMapQuit = 'q'
let g:NERDTreeMapRefreshRoot = 'r'
let g:NERDTreeMapDeleteNode = 'd'
let g:NERDTreeMapOpenExpl = 'o'
let g:NERDTreeMapPreview = 'p'
let g:NERDTreeQuitOnOpen = 1
```

### Neovim (`nvim/lua/dis446/core/options.lua`)

```lua
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.cursorline = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.clipboard:append("unnamedplus")
```

---

## What differs (acceptable)

These differences are environment-specific and don't affect muscle memory:

| Area                  | IntelliJ                                  | Neovim                                |
| --------------------- | ----------------------------------------- | ------------------------------------- |
| **Project switching** | `Alt+H` → RecentFiles, `Alt+L` → Switcher | `Ctrl+b s` — session picker (text-filterable) |
| **Window / tab focus** | IDE tool windows + `Alt+L`/`Alt+H` for tabs | `Ctrl+b` prefix; one tmux window per project |
| **Session mode**      | — (no session manager)                     | `Ctrl+b s` for session picker         |
| **Editing surface**   | IntelliJ editor + IdeaVim                 | Neovim editor                         |
| **File tree**         | NERDTree (`h`/`l`/`q`/`r`/`d`)           | Snacks Explorer                       |
| **Theme**             | Default IntelliJ theme                    | `tokyonight.nvim` (style: night)      |
| **Session restore**   | Automatic (IDE remembers state)           | `auto-session` + `tmux-resurrect`/`continuum` auto-save and restore across reboots |

---

## New keybinding reference

When adding a new keybinding, add it here first. Both `.ideavimrc` and the
Neovim config should reference this file as the source of truth.

### Available leader-key prefixes

| Prefix | Purpose          | Status                                                    |
| ------ | ---------------- | --------------------------------------------------------- |
| `e`    | Explorer         | Used (`ee`, `ef`)                                         |
| `f`    | Find             | Used (`ff`, `fr`, `fs`, `fc`, `ft`)                       |
| `l`    | Git / VCS        | Used (`lg`, `lc`, `lp`, `lu`)                             |
| `c`    | Code             | Used (`ca`)                                               |
| `r`    | Run / rename     | Used (`rb`, `rd`, `rn`)                                   |
| `x`    | Diagnostics      | Used (`xx`, `xd`)                                         |
| `o`    | Open / toggle    | Used (`ot`, `oT`)                                         |
| `d`    | Debug / database | Used (`db`, `dt`, `du`, `de`, `dr`, `dR`, `dq`)           |
| `m`    | Maven / build    | Used (`mm`, `mn`, `mk`, `m,`, `mv`)                       |
| `p`    | Pi / AI          | Used (`pI`)                                               |
| `t`    | Tabs             | Used (`tw`, `tt`, `tl`, `th`, `to`, `tp`, `tn`, `t1`-`9`) |
| `s`    | Splits / zoom    | Used (`sv`, `sh`, `se`, `sx`, `sm`)                       |
| `h`    | Hunks (git)      | Used (`hs`, `hr`, `hp`, `hb`, etc.)                       |
| `w`    | Workspace        | Used (`wr`, `ws`)                                         |
