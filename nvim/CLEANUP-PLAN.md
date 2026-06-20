# Neovim Config Cleanup Plan

> **Goals:** Remove tab/split keybinds (never used), automate session handling, simplify config.

---

## 1. Why clean this up

Your workflow uses zellij for layout management (panes, tabs per repo). Neovim
is always a **single-pane, full-size editor** inside a zellij pane. You never:

- Open new neovim tabs
- Switch between neovim tabs
- Split neovim windows vertically or horizontally
- Manually resize or close neovim splits
- Use `vim-tmux-navigator` (you use zellij, not tmux — and zellij uses Alt+hjkl,
  not Ctrl+hjkl)

You run Pi in a separate zellij pane (middle pane, between neovim and bash).
The `pi.lua` neovim plugin that opened Pi as a right-side split has never
been used — it's also being removed in this cleanup.

---

## 2. Changes

### 2.1 Remove tab keybinds

**File:** `nvim/lua/dis446/core/keymaps.lua`

Remove these lines:

| Keybind | What it does | Why remove |
|---|---|---|
| `<leader>tt` → `tabnew` | Open new tab | Never used |
| `<leader>tw` → `tabclose` | Close current tab | Never used |
| `<leader>tl` → `tabn` | Next tab | Never used |
| `<leader>th` → `tabp` | Previous tab | Never used |
| `<leader>ty` → `tabnew %` | Buffer to new tab | Never used |

### 2.2 Remove split/pane keybinds

**File:** `nvim/lua/dis446/core/keymaps.lua`

Remove these lines:

| Keybind | What it does | Why remove |
|---|---|---|
| `<leader>sv` → `<C-w>v` | Vertical split | Never used (zellij handles layout) |
| `<leader>sh` → `<C-w>s` | Horizontal split | Never used |
| `<leader>se` → `<C-w>=` | Equalize splits | Never used |
| `<leader>sx` → `:close` | Close current split | Never used |

### 2.3 Remove maximize-split keybind

**File:** `nvim/lua/dis446/plugins/snacks.lua`

Remove this keymap from the `config` function:

```lua
keymap.set("n", "<leader>sm", function()
    Snacks.zen.zoom()
end, { desc = "Maximize/minimize a split" })
```

This frees up `<leader>sm` if you want it later, but since zellij handles
window management, you don't need `Snacks.zen.zoom()` inside neovim.

### 2.4 Remove split options

**File:** `nvim/lua/dis446/core/options.lua`

Remove these lines (they only affect manual split behavior, which you never use):

```lua
-- split windows
opt.splitright = true
opt.splitbelow = true
```

### 2.5 Remove bufferline or switch to buffer mode

**File:** `nvim/lua/dis446/plugins/bufferline.lua`

Currently set to `mode = "tabs"`. Since you never open neovim tabs, this shows:

```
┌─ Tab 1 (1 file) ──────────────────────────────────────────┐
```

This is dead UI. Two options:

**Option A (recommended): Remove bufferline entirely.**
Delete the file. After removing tab keybinds, you have no way to create tabs
anyway. The vim-native `:ls`/`:buffers`/`:b` commands still work for buffer
navigation.

**Option B: Switch to buffer mode.**
Change `mode = "tabs"` to `mode = "buffers"`. This shows open buffers at the
top like a VS Code tab bar. Can be useful for visual buffer awareness.

**Recommendation: Option A.** You navigate buffers via picker (`Space+ff`,
`Space+fr`) and vim commands (`:b`, `:bp`, `:bn`). A bufferline bar adds
visual noise for a feature you navigate through other means.

### 2.6 Remove vim-tmux-navigator

**File:** `nvim/lua/dis446/plugins/init.lua`

Remove this line:

```lua
"christoomey/vim-tmux-navigator", -- tmux & split window navigation
```

This plugin maps `Ctrl+hjkl` to navigate between vim splits and tmux panes.
You don't use tmux (you use zellij with Alt+hjkl), and you don't split vim
windows. The plugin loads on every startup for no benefit.

### 2.7 Auto-session: enable automatic save/restore

**File:** `nvim/lua/dis446/plugins/auto-session.lua`

Replace the config:

```lua
-- BEFORE
auto_session.setup({
    auto_restore_enabled = false,
    auto_session_suppress_dirs = {
        "~/", "~/Dev/", "~/Downloads", "~/Documents", "~/Desktop/",
    },
})

local keymap = vim.keymap
keymap.set("n", "<leader>wr", "<cmd>SessionRestore<CR>",
    { desc = "Restore session for cwd" })
keymap.set("n", "<leader>ws", "<cmd>SessionSave<CR>",
    { desc = "Save session for auto session root dir" })
```

```lua
-- AFTER
auto_session.setup({
    auto_restore_enabled = true,      -- restore session on `nvim .`
    auto_save_enabled = true,          -- save session on exit
    auto_session_suppress_dirs = {
        "~/", "~/Dev/", "~/Downloads", "~/Documents", "~/Desktop/",
    },
    -- Optional: auto-create session if none exists
    -- auto_create_enabled = true,
})
-- No manual keybinds needed. Just open nvim and it restores.
```

### 2.8 Remove Pi integration

**File:** `nvim/lua/dis446/plugins/pi.lua`

Delete this file. You've never used it — Pi runs in its own zellij pane,
not embedded inside neovim. This removes:

- Keybinds: `<leader>pi` (toggle Pi pane), `<leader>pI` (new Pi session)
- User commands: `:Pi`, `:PiToggle`, `:PiNew`
- The `botright vsplit` Pi pane
- Per-project session dirs under `~/.local/state/nvim/pi-sessions/`

### 2.9 Remove DBee (database client)

**Files:** `nvim/lua/dis446/plugins/dbee.lua` + `nvim/lua/dis446/dbee/` directory

You've never been able to use it effectively, and DataGrip (built into
IntelliJ Ultimate, `Alt+L`) is objectively better for SQL work. This removes:

- Plugin: `kndndrj/nvim-dbee` and its dependency `MunifTanjim/nui.nvim`
- Keybinds: `<leader>od` (open DBee), `<leader>oD` (reload DB connections)
- User commands: `:DbeeRepoOpen`, `:DbeeRepoToggle`, `:DbeeRepoReload`,
  `:DbeeRepoEditConfig`, `:DbeeRepoEditLocalConfig`
- The entire `dis446.dbee` module (repo-scoped connection loading)

### 2.10 Terminal keybinds: keep or remove?

**File:** `nvim/lua/dis446/plugins/snacks.lua`

These keybinds open a terminal via Snacks inside neovim:

| Keybind | What it does |
|---|---|
| `<leader>ot` | Toggle bottom terminal |
| `<leader>oT` | Open floating terminal |

If you have a zellij bash pane open below neovim, these are redundant. But if
you ever run neovim standalone (without zellij), having a quick terminal toggle
is useful.

**Decision:** Keep them. They're two keybinds and don't hurt anything. If you
find you never use them after a few weeks, remove them then.

---

## 3. Summary of free keymaps

After cleanup, these leader-key combinations become available for future use:

| Key | Became free because |
|---|---|
| `<leader>sv` | Removed vertical split |
| `<leader>sh` | Removed horizontal split |
| `<leader>se` | Removed equalize splits |
| `<leader>sx` | Removed close split |
| `<leader>sm` | Removed maximize split |
| `<leader>tt` | Removed new tab |
| `<leader>tw` | Removed close tab |
| `<leader>tl` | Removed next tab |
| `<leader>th` | Removed previous tab |
| `<leader>ty` | Removed buffer to new tab |
| `<leader>wr` | Removed manual session restore |
| `<leader>ws` | Removed manual session save |
| `<leader>pi` | Removed Pi pane |
| `<leader>pI` | Removed new Pi session |
| `<leader>od` | Removed DBee |
| `<leader>oD` | Removed DBee reload |

That's **16 freed leader-key combinations**. The `s` prefix group (window
splits), `t` prefix group (tabs), `p` prefix group, and `o` prefix group
are now available.

---

## 4. File-by-file change summary

### Delete

```
nvim/lua/dis446/plugins/bufferline.lua    (if choosing Option A)
nvim/lua/dis446/plugins/pi.lua
nvim/lua/dis446/plugins/dbee.lua
nvim/lua/dis446/dbee/                     (entire directory)
```

### Edit

| File | Change |
|---|---|
| `nvim/lua/dis446/core/keymaps.lua` | Remove tab keybinds (5 lines) + split keybinds (4 lines) |
| `nvim/lua/dis446/core/options.lua` | Remove `splitright` and `splitbelow` |
| `nvim/lua/dis446/plugins/snacks.lua` | Remove `<leader>sm` keymap |
| `nvim/lua/dis446/plugins/auto-session.lua` | Enable `auto_restore_enabled`, add `auto_save_enabled`, remove manual keybinds |
| `nvim/lua/dis446/plugins/init.lua` | Remove `vim-tmux-navigator` |
| `nvim/lua/dis446/dbee/` | Delete entire directory (init.lua, repo.lua, source.lua, env.lua) |
| `nvim/lazy-lock.json` | Regenerate after plugin removals |

### Update docs

| File | Change |
|---|---|
| `nvim/README.md` | Remove tab/split/Pi/DBee sections, update session docs |
| `nvim/CHEATSHEET.md` | Remove tab/split/Pi/DBee entries, update session entry |
| `nvim/REVIEW-2026.md` | Note cleanup |

---

## 5. What stays unchanged

| Feature | Why keep it |
|---|---|
| Dashboard (snacks) | Entry point when opening nvim without a file |
| Explorer (snacks) | `Space+ee` file navigation |
| Picker (snacks) | `Space+ff`, `Space+fs`, `Space+fr`, `Space+ft` |
| Lazygit (snacks) | `Space+lg` git operations |
| Terminal (snacks) | `Space+ot` quick terminal (useful standalone) |
| All LSP config | gd, gi, gR, ca, rn, K, diagnostics |
| Auto-session | Now automatic (restore on open, save on close) |
| Gitsigns, formatting, linting | Core editing features |
| Treesitter, blink.cmp | Core editing features |
---

## 6. Optional ideas (not part of this plan)

- **Remove terminal keybinds** — if you always use zellij, `Space+ot`/`Space+oT`
  are redundant. But keep them for now — they're useful when running nvim
  standalone.
