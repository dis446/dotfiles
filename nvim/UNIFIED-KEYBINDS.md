# Unified Keybindings

> **One keybinding set, two environments.**

---

## Leader: `Space`

In IntelliJ, set `let mapleader = " "` in `.ideavimrc`.
In Neovim, set `vim.g.mapleader = " "` in `keymaps.lua`.

## File & project navigation

| Key        | Action                              | IntelliJ backend            | Neovim backend                  |
| ---------- | ----------------------------------- | --------------------------- | ------------------------------- |
| `Space+ee` | Toggle file explorer / project tree | `ActivateProjectToolWindow` | `Snacks.explorer()`             |
| `Space+ef` | Reveal current file in tree         | `SelectInProjectView`       | `Snacks.explorer.reveal()`      |
| `Space+ff` | Find file by name                   | `GotoFile`                  | `Snacks.picker.files()`         |
| `Space+fr` | Recent files                        | `RecentFiles`               | `Snacks.picker.recent()`        |
| `Space+fs` | Search text in project (grep)       | `FindInPath`                | `Snacks.picker.grep()`          |
| `Space+fc` | Search word under cursor            | `FindInPath` (pre-filled)   | `Snacks.picker.grep_word()`     |
| `Space+ft` | Find TODOs                          | `ActivateTODOToolWindow`    | `Snacks.picker.todo_comments()` |

## Git

| Key        | Action             | IntelliJ backend          | Neovim backend     |
| ---------- | ------------------ | ------------------------- | ------------------ |
| `Space+lg` | LazyGit (full TUI) | `Lazygit.Toggle` (plugin) | `Snacks.lazygit()` |
| `Space+lc` | Commit             | `CheckinProject`          | — (use lazygit)    |
| `Space+lp` | Push               | `Vcs.Push`                | — (use lazygit)    |
| `Space+lu` | Pull / update      | `Vcs.UpdateProject`       | — (use lazygit)    |

**Note:** `Space+lc`/`lp`/`lu` are **IntelliJ-only** convenience bindings. In
Neovim, perform commit/push/pull inside lazygit.

## LSP / code intelligence

| Key         | Action                     | Both environments                                      |
| ----------- | -------------------------- | ------------------------------------------------------ | ----------------------------- |
| `gd`        | Go to definition           | Works in both                                          |
| `gi`        | Go to implementation       | Works in both                                          |
| `gt`        | Go to type definition      | Works in both                                          |
| `gR`        | Find references            | Works in both                                          |
| `K`         | Hover / documentation      | Works in both                                          |
| `Space+ca`  | Code actions / intentions  | `ShowIntentionActions` / `vim.lsp.buf.code_action`     |
| `Space+rn`  | Rename                     | `RenameElement` / `vim.lsp.buf.rename`                 |
| `[d` / `]d` | Previous / next diagnostic | Works in both                                          |
| `Space+xx`  | Toggle diagnostics list    | `ActivateProblemsViewToolWindow`                       | `Snacks.picker.diagnostics()` |
| `Space+xd`  | Buffer diagnostics         | `GotoNextError` / `Snacks.picker.diagnostics_buffer()` |

## Terminal

| Key        | Action                    | IntelliJ backend             | Neovim backend                 |
| ---------- | ------------------------- | ---------------------------- | ------------------------------ |
| `Space+ot` | Toggle terminal           | `ActivateTerminalToolWindow` | `Snacks.terminal()`            |
| `Space+oT` | Floating / split terminal | `Terminal.SplitVertically`   | `Snacks.terminal()` (floating) |

**Note on Neovim + zellij:** When running Neovim inside a zellij session, you
already have a bash pane below. `Space+ot` is still useful when running Neovim
standalone (outside zellij).

## Build & run

| Key        | Action           | IntelliJ backend | Neovim backend           |
| ---------- | ---------------- | ---------------- | ------------------------ |
| `Space+mm` | Run              | `Run`            | — (use zellij bash pane) |
| `Space+mn` | Debug / Continue | `Debug`          | `dap.continue()`         |

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

## Tools

| Key        | Action              | IntelliJ backend                | Neovim backend                 |
| ---------- | ------------------- | ------------------------------- | ------------------------------ |
| `Space+db` | Toggle database     | `ActivateDatabaseToolWindow`    | — (use DataGrip)               |
| `Space+mv` | Toggle maven        | `ActivateMavenToolWindow`       | — (use zellij bash pane)       |
| `Space+pi` | Toggle AI Assistant | `ActivateAIAssistantToolWindow` | — (Pi in separate zellij pane) |

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
set ideaput
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
| **Project switching** | `Alt+H` → RecentFiles, `Alt+L` → Switcher | Zellij `Alt+←`/`Alt+→` (tabs)         |
| **Window management** | IDE tool windows (right side)             | Zellij panes (top/middle/bottom)      |
| **Editing surface**   | IntelliJ editor + IdeaVim                 | Neovim editor                         |
| **Theme**             | Default IntelliJ theme                    | `tokyonight.nvim` (style: night)      |
| **Session restore**   | Automatic (IDE remembers state)           | `auto-session` (auto_restore_enabled) |

---

## New keybinding reference

When adding a new keybinding, add it here first. Both `.ideavimrc` and the
Neovim config should reference this file as the source of truth.

### Available leader-key prefixes

| Prefix | Purpose          | Status                                          |
| ------ | ---------------- | ----------------------------------------------- |
| `e`    | Explorer         | Used (`ee`, `ef`)                               |
| `f`    | Find             | Used (`ff`, `fr`, `fs`, `fc`, `ft`)             |
| `l`    | Git / VCS        | Used (`lg`, `lc`, `lp`, `lu`)                   |
| `c`    | Code             | Used (`ca`)                                     |
| `r`    | Run / rename     | Used (`rb`, `rd`, `rn`)                         |
| `x`    | Diagnostics      | Used (`xx`, `xd`)                               |
| `o`    | Open / toggle    | Used (`ot`, `oT`)                               |
| `d`    | Debug / database | Used (`db`, `dt`, `du`, `de`, `dr`, `dR`, `dq`) |
| `m`    | Maven / build    | Used (`mv`)                                     |
| `p`    | Pi / AI          | Used (`pi`)                                     |
| `s`    | —                | Free (was splits)                               |
| `t`    | —                | Free (was tabs)                                 |
| `h`    | Hunks (git)      | Used (`hs`, `hr`, `hp`, `hb`, etc.)             |
| `w`    | Workspace        | Free (was sessions)                             |
