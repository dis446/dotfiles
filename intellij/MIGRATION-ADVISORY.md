# IntelliJ Migration Advisory

> **Goal:** Transition primary development from zellij+neovim to IntelliJ IDEA
> Ultimate and unify keybindings. Zellij/Neovim muscle memory (last 6 months)
> is more recent and should take priority over older IntelliJ habits where
> they conflict. The IDE should feel like "Neovim keybinds in an IntelliJ
> shell" rather than the reverse.
>
> **Dotfiles strategy:** Track `.ideavimrc` + reference keymap in
> `~/dotfiles/intellij/`. Let JetBrains Settings Sync handle cross-machine
> sync of everything else (keymaps, codestyles, options, etc.). Symlink
> `.ideavimrc` to `~/.ideavimrc` via `fedora/install.sh`.

---

## 1. Current State Analysis

### 1.1 What you have today

| Environment | Role | Active keybinding set |
|---|---|---|
| IntelliJ 2026.1 Ultimate | Java/TS/DB/Git IDE, already used daily | "GNOME Vim" keymap + IdeaVim enabled |
| Zellij + Neovim | Terminal-first dev environment | Zellij Alt+hjkl panes, Neovim Space-leader |
| Both | Simultaneously active | Conflicts already partially resolved |

### 1.2 Current IntelliJ configuration

- **Keymap:** `GNOME Vim` (parent: `Default for GNOME`)
- **IdeaVim:** Enabled (v2.32.0+)
- **Ide shortcut conflicts already assigned to Vim:** `Ctrl+K`, `Ctrl+R`
- **Ide shortcuts intentionally removed:** `CloseActiveTab`, `EditorSelectWord`,
  `EditorSplitLine`, `EditorStartNewLine`, `GotoClass`, `GotoPreviousError`,
  `GotoTest`, `SmartSelect`, `Switcher`
- **Tool windows open regularly:** Project, Commit, Structure, Version Control,
  Terminal, Database, Maven, AI Assistant, Problems, Services
- **Terminal config:** `useOptionAsMetaKey = true`, bash shell, 191+ commands run

### 1.3 gSim project

The `~/Code/gSim` umbrella is an Nx monorepo workspace with 5 sub-repos
(globalSimNaut Java/Maven, globalSimClient React, globalSimSales Next.js,
globalSimWeb Next.js, globalSimApp Flutter). Each is its own git repo. The
umbrella already has `nx.json` + `projects/*/project.json` making it
compatible with the Nx Console IntelliJ plugin.

---

## 2. Keymap Conflict Matrix

There are **three** active muscle-memory layers, not two:

| Layer | Origin | Priority | Examples |
|---|---|---|---|
| **Zellij + Neovim leader** | Last 6 months (most recent) | **Primary** | `Alt+hjkl` pane/tab nav, `Space+ff` files, `Space+lg` git, `Space+ee` explorer |
| **Vim editor** | Years (IdeaVim + Neovim) | **Primary** | `hjkl` movement, `gd` defs, `gi` impls, `dt`/`ci` text objects |
| **IntelliJ IDE** | 10+ years (less recent) | **Fallback** | `Ctrl+N` class, `Ctrl+Shift+T` test, `Shift+Shift` search |

### 2.1 IntelliJ IDE vs Vim editor (within IntelliJ)

This is the **hardest conflict class** because both systems want the same
single-key chords.

| Keystroke | IntelliJ IDE action | Vim normal-mode action | Current resolution | Recommendation |
|---|---|---|---|---|
| `Ctrl+K` | **VCS Commit** (Git commit window) | Move cursor up | **Vim owns it** (from vim_settings.xml) | **Keep Vim owning it.** You navigate git via `Space+lg` (VCS tool window) and `Space+lc` (commit). The IntelliJ `Ctrl+K` commit shortcut is less important given your Space-leader git workflow. Use `k`/`↑` for movement regardless. |
| `Ctrl+R` | Replace (find & replace) | Redo | **Vim owns it** | **Give to IDE.** Use `u`/`Ctrl+R` for undo/redo via `<C-r>` in IdeaVim. Actually `Ctrl+R` in Vim IS redo... IdeaVim supports this natively. This one is actually fine as-is. |
| `Ctrl+J` | — (mostly unused) | Move cursor down | No conflict | Keep Vim |
| `Ctrl+N` | Go to Class | Move cursor down | **Removed from keymap!** | **Restore to IDE.** `Ctrl+N` = Go to Class is one of the most-used IntelliJ shortcuts. Use `j`/`↓` for movement. |
| `Ctrl+P` | — (varies by context) | Move cursor up | Potential | Keep Vim |
| `Ctrl+Shift+N` | **Go to File** | — | No conflict | Keep IDE (this is your "Space+ff" equivalent in IntelliJ) |
| `Ctrl+Shift+F` | **Find in Files** | — | No conflict | Keep IDE (this is your "Space+fs" equivalent in IntelliJ) |
| `Shift+Shift` | **Search Everywhere** | — | No conflict | Keep IDE |
| `Ctrl+Shift+T` | **Go to Test** | — | **Removed from keymap!** | **Restore to IDE.** Critical for Java/TDD workflow. |
| `Ctrl+Tab` | Switcher (recent files/tools) | — | **Removed from keymap!** | **Restore.** Vim doesn't use Ctrl+Tab. No reason to remove. |
| `Ctrl+W` | Extend selection | Previous window (`Ctrl+W` prefix in Vim) | Custom: `Ctrl+W` closes content (IntelliJ) | **Tricky.** In Vim, `Ctrl+W` is the window command prefix. In IntelliJ, `Ctrl+W` is Extend Selection. You mapped it to "Close Content" in your custom keymap. **Recommendation:** Keep `Ctrl+W` for IntelliJ (close tab works well), and use `Ctrl+W` + `h/j/k/l` via IdeaVim window commands only when Vim is in control. This is a known tension. |
| `Ctrl+D` | Duplicate line | Scroll down half-page | Potential conflict | In IdeaVim, `Ctrl+D` scrolls. In IntelliJ, duplicates line. **Test which you use more.** |

### 2.2 Alt+h/Alt+l: Zellij tab nav → IntelliJ project switching

In zellij, `Alt+←`/`Alt+→` switches tabs (repos), and `Alt+h`/`Alt+l` moves
focus between panes within a tab. Your request is to use **`Alt+h` and `Alt+l`**
to switch between IntelliJ projects — carrying the spatial muscle memory from
zellij's left/right navigation.

**Current conflict:** In your IntelliJ keymap, `Alt+H` is mapped to the Maven
tool window, and `Alt+L` is mapped to the Database tool window.

**Solution:** Remap Alt+h/Alt+l to project switching actions.

| Current binding | Action to remap to | New home for displaced action |
|---|---|---|
| `Alt+H` → Maven | Switch to previous project root | Maven → `Space+mv` (already in .ideavimrc) |
| `Alt+L` → Database | Switch to next project root | Database → `Space+db` (already in .ideavimrc) |

**How to implement (two options):**

**Option A — Navigate attached projects via Project tool window focus.**
Map `Alt+H` and `Alt+L` to these actions in Settings → Keymap:
- `Alt+H` → `PreviousProjectWindow` (or a macro: ActivateProjectToolWindow + focus previous root)
- `Alt+L` → `NextProjectWindow`

Unfortunately IntelliJ does not have a built-in "focus next project root"
action. But you can create two **macros**:

```
Macro: "Focus Previous Project Root"
  1. ActivateProjectToolWindow
  2. EditorUp (moves focus up in the project tree)

Macro: "Focus Next Project Root"
  1. ActivateProjectToolWindow
  2. EditorDown
```

Then bind `Alt+H` and `Alt+L` to these macros. This approximates "switch 
between project roots" by navigating the Project tool window.

**Option B — Use the Switcher for recent files across projects.**
Bind `Alt+H` → `RecentFiles` (shows recent files, naturally navigated with
arrow keys). Bind `Alt+L` → `Switcher` (same concept, different UI). This
gives two quick-launch surfaces for cross-project navigation.

**Recommendation: Option B** is simpler and more reliable. Option A's macros
can break if the Project view is collapsed or in a different mode.

### 2.3 Zellij vs IntelliJ tool window shortcuts

These **only conflict when Zellij is active**. When IntelliJ is the foreground
GUI app, Zellij keybinds don't fire.

| Keystroke | Zellij action | IntelliJ custom keymap | Resolution |
|---|---|---|---|
| `Alt+H` | Move focus left | Maven tool window | **Repurposed** → project switching (§2.2). Maven via `Space+mv`. |
| `Alt+L` | Move focus right | Database tool window | **Repurposed** → project switching (§2.2). Database via `Space+db`. |
| `Alt+J` | Move focus down | — | No conflict |
| `Alt+K` | Move focus up | AI Assistant tool window | Keep AI Assistant. `Alt+↑` also moves focus up in zellij. |
| `Alt+N` | New pane | New file | No conflict (different contexts) |
| `Alt+G` | — | GitHub Actions | No conflict |

**Key insight:** If you stop using Zellij as your primary terminal multiplexer
and use IntelliJ's built-in terminal instead, **all Zellij conflicts disappear.**
You would only open Zellij for rare multi-terminal sessions outside IntelliJ.

### 2.3 Neovim Space-leader vs IntelliJ

These CAN be replicated in IdeaVim. This is the **best path to unification**.

| Neovim key | Action | IntelliJ equivalent | IdeaVim mapping |
|---|---|---|---|
| `Space+ee` | Snacks explorer | Project tool window (`Alt+1`) | `nnoremap <leader>ee :action ActivateProjectToolWindow<CR>` |
| `Space+ef` | Reveal file in explorer | Select in Project View (`Alt+F1`) | `nnoremap <leader>ef :action SelectInProjectView<CR>` |
| `Space+ff` | Find files | Go to File (`Ctrl+Shift+N`) | `nnoremap <leader>ff :action GotoFile<CR>` |
| `Space+fr` | Recent files | Recent Files (`Ctrl+E`) | `nnoremap <leader>fr :action RecentFiles<CR>` |
| `Space+fs` | Live grep | Find in Files (`Ctrl+Shift+F`) | `nnoremap <leader>fs :action FindInPath<CR>` |
| `Space+fc` | Grep word under cursor | Find in Files (with selection) | `nnoremap <leader>fc :action FindInPath<CR>` (pre-fills word) |
| `Space+ft` | TODOs | TODO tool window | `nnoremap <leader>ft :action ActivateTODOToolWindow<CR>` |
| `Space+lg` | LazyGit | Lazygit plugin (full-screen editor tab) | `nnoremap <leader>lg <Action>(Lazygit.Toggle)` (keep lazygit via native IntelliJ plugin) |
| `Space+pi` | Pi AI pane | AI Assistant | `nnoremap <leader>pi :action ActivateAIAssistantToolWindow<CR>` |
| `Space+pI` | New Pi session | New AI chat | — (manual) |
| `Space+wr` | Restore session | — | No direct equivalent (IntelliJ remembers state) |
| `Space+ws` | Save session | — | No direct equivalent |
| `Space+ot` | Toggle terminal | Terminal tool window (`Alt+F12`) | `nnoremap <leader>ot :action ActivateTerminalToolWindow<CR>` |
| `Space+oT` | Floating terminal | Split terminal | `nnoremap <leader>oT :action Terminal.SplitVertically<CR>` |
| `Space+sm` | Maximize split | Toggle distraction-free | `nnoremap <leader>sm :action ToggleDistractionFreeMode<CR>` |
| `Space+xx` | Diagnostics list | Problems tool window | `nnoremap <leader>xx :action ActivateProblemsViewToolWindow<CR>` |
| `Space+xd` | Buffer diagnostics | Current file problems | Native (inline) |
| `Space+sv` | Vertical split | Split Right | `nnoremap <leader>sv :action SplitVertically<CR>` |
| `Space+sh` | Horizontal split | Split Down | `nnoremap <leader>sh :action SplitHorizontally<CR>` |
| `Space+sx` | Close split | Close tab (unsplit) | `nnoremap <leader>sx :action CloseContent<CR>` |

#### LSP keybinds

| Neovim key | IdeaVim equivalent | IntelliJ native |
|---|---|---|
| `gd` | `:action GotoDeclaration<CR>` | Already works (IntelliJ's own) |
| `gD` | `:action GotoDeclaration<CR>` | Same |
| `gi` | `:action GotoImplementation<CR>` | Already works |
| `gt` | `:action GotoTypeDeclaration<CR>` | Already works |
| `gR` | `:action FindUsages<CR>` | `Alt+F7` (conflict-free) |
| `K` | Quick documentation | Already works |
| `<leader>ca` | `:action ShowIntentionActions<CR>` | `Alt+Enter` standard |
| `<leader>rn` | `:action RenameElement<CR>` | `Shift+F6` standard |
| `[d` / `]d` | Next/previous error | `F2` / `Shift+F2` (IDE standard, remapped to `Shift+F2` in your keymap for RenameElement) |

**Note:** Your custom keymap remaps `Shift+F2` to `RenameElement`. But
`Shift+F2` is normally "Previous Highlighted Error" in IntelliJ. This is a
conflict worth fixing — restore `Shift+F2` to errors and use `Shift+F6` for
rename (the standard).

---

## 3. Multi-Project Workflow (Replacing Zellij Tabs)

### 3.1 Your Zellij pattern

```
Tab 1: gSim        →  [neovim][pi][bash]
Tab 2: path-service →  [neovim][pi][bash]
Tab 3: mdm          →  [neovim][pi][bash]
...
```

Each tab = one repo. `Alt+hjkl` between panes, `Alt+tab-number` between repos.

### 3.2 IntelliJ equivalent

IntelliJ opens projects as **separate windows** by default. You've already
identified this as the pain point: alt-tabbing between windows is annoying.

**Solution: Use "Attach Project" (IntelliJ 2024+)**

1. Open one project normally (e.g., `gSim`)
2. **File → Attach Project...** → pick a second repo directory
3. Each attached project appears as a **separate root** in the Project tool
   window, with its own VCS, run configs, module structure
4. Use `Ctrl+Tab` (Switcher) to jump between files across all attached projects
5. The Project tool window shows all attached repos in a tree

**For the gSim umbrella specifically:**

The umbrella already has Nx Console support. Open `~/Code/gSim` as the IntelliJ
project. Each sub-repo (`globalSimNaut`, `globalSimClient`, etc.) shows in the
Project view. Because Nx Console is installed, you get:
- Nx task runner for `nx:dev`, `nx:build`, `nx:test`
- Multi-module navigation
- Single-window git: each sub-repo is a separate VCS root, visible in the
  Version Control tool window and the Commit tab

**For unrelated repos (e.g., `path-service` + `mdm`):**

Option A: **Attach both to one window.** Project view shows both roots.
Option B: **Separate windows, but use a Linux window manager shortcut.**
  On GNOME: `Alt+` (backtick) switches between windows of the same application.
  This is faster than Alt+Tab across all apps.
Option C: **Use Recent Projects (`Ctrl+E`)** and `Ctrl+Shift+E` (Recent
  Locations) for quick navigation without closing projects.

**Recommendation:** Use Option A for related repos (all in `and/alpha/back-end/`)
and Option A + B for completely separate repos.

### 3.3 Terminal replacement for Zellij panes

| Zellij pane | IntelliJ replacement |
|---|---|
| Top: Neovim | Editor (the IDE is the editor) |
| Middle: Pi (AI) | AI Assistant tool window (`Alt+K`, or your `Space+pi`) |
| Bottom: Bash | Terminal tool window (`Alt+F12`, or your `Space+ot`) |

You get the same layout, but with IDE tool windows instead of terminal panes:
```
[   Editor (Java/TS code)        ]
[   Terminal tool window (bash)  ]
```

The AI Assistant and Database tool windows live on the right side (per your
current `window.layouts.xml` configuration):
```
[ Editor  ][ AI Assistant ]
[ Editor  ][ Database     ]
[ Terminal ][ Maven        ]
```

---

## 4. Pi Integration in IntelliJ

### 4.1 The goal

Integrate pi.dev as the backend agent for IntelliJ's built-in AI chat via ACP
(Agent Communication Protocol). Instead of running pi as a separate terminal
TUI, pi acts as the AI engine behind the IntelliJ AI Assistant tool window.

### 4.2 What is ACP?

ACP (Agent Communication Protocol) is JetBrains' protocol for external AI agents
to integrate with the IntelliJ AI Assistant. An ACP agent:
- Connects to IntelliJ via an agent registry
- Receives chat messages and code context from the IDE
- Returns responses that the IDE renders in the AI Assistant tool window
- Has access to IDE APIs (files, project structure, editor state)

You already have one ACP agent configured: **Junie** (`acp.registry.junie`,
auth: `MANAGED_EXTERNALLY`). The goal is to register pi as a second agent.

### 4.3 The bridge: pi RPC mode → IntelliJ ACP

Pi has an `--mode rpc` flag that enables a JSON protocol over stdin/stdout
(see `docs/rpc.md` in the pi package). This is an ideal foundation for an
ACP-compatible wrapper:

```
┌─────────────────────────────────────────────────────┐
│ IntelliJ AI Assistant                               │
│  ┌─────────┐    ACP     ┌───────────────┐          │
│  │ AI Chat │◄──────────►│ ACP bridge    │          │
│  │ tool    │  (JSON)    │ (thin adapter)│          │
│  │ window  │            │               │          │
│  └─────────┘            │ stdin/stdout  │          │
│                         │    ┌──────┐   │          │
│                         │    │ pi   │   │          │
│                         │    │ --rpc│   │          │
│                         │    └──────┘   │          │
│                         └───────────────┘          │
└─────────────────────────────────────────────────────┘
```

### 4.4 Implementation options

| Option | Effort | Description |
|---|---|---|
| **A. Wait for official pi ACP support** | None | Check if pi.dev plans to ship ACP as a first-class feature. Ask in the pi community. |
| **B. Build a thin Node.js ACP bridge** | 1-2 days | Write a small Node.js script that speaks ACP on one side and spawns `pi --mode rpc` on the other. Register it as a custom agent. |
| **C. Use JetBrains AI Assistant with pi-matching prompts** | 0 days (immediate) | Configure the existing AI Assistant (which already supports Claude/GPT) with system prompts that match pi's behavior. Use `~/.pi/settings.yaml` prompts as the base. |
| **D. Terminal tab (fallback)** | 0 days | Keep running pi in a terminal tab until ACP integration is ready. See §4.6. |

**Recommendation:** Start with **Option C** immediately (configure AI Assistant
prompts). In parallel, explore **Option A** (check if pi is adding ACP support)
or **Option B** (build it yourself if needed soon).

### 4.5 Option C details: Matching pi behavior in JetBrains AI

1. **Settings → Tools → AI Assistant → Prompts**
2. Add a custom prompt that mirrors pi's system prompt from
   `~/.pi/prompts/default.md` (or wherever you've configured it)
3. Key behaviors to replicate:
   - Agent-style tool calling (read files, execute commands, edit code)
   - Project context from AGENTS.md / CLAUDE.md files
   - Your custom skill prompts (pi skills like `caveman`, `and-audit-publish-*`)

JetBrains AI Assistant 2026.1+ supports agent mode with code editing tools.
If you set a matching system prompt and use Claude as the backend model, the
experience will be very close to pi.

### 4.6 Terminal tab fallback (interim)

Until ACP integration is ready, run pi in a dedicated terminal tab:

```
1. Alt+F12 → open Terminal
2. Ctrl+Shift+T → new terminal tab, rename to "Pi"
3. cd $PROJECT_DIR && pi
4. Switch between bash terminal and Pi terminal with Ctrl+Tab
```

Or use an External Tool (Settings → Tools → External Tools) bound to
`Space+pI` to launch pi in a separate terminal window.

---

## 5. Recommended `.ideavimrc`

Create `~/.ideavimrc` (or symlink from `~/dotfiles/intellij/ideavimrc`):

```vim
" ── Leader ──────────────────────────────────────────
let mapleader = " "

" Ctrl+K stays with Vim (cursor up). You navigate git via Space-leader.
" No need to unmap it — keep the Vim default.

" ── Space-leader mappings (from Neovim muscle memory) ──

" File explorer → Project tool window
nnoremap <leader>ee :action ActivateProjectToolWindow<CR>
nnoremap <leader>ef :action SelectInProjectView<CR>

" Find files → Go to File
nnoremap <leader>ff :action GotoFile<CR>
nnoremap <leader>fr :action RecentFiles<CR>
nnoremap <leader>fs :action FindInPath<CR>
nnoremap <leader>fc :action FindInPath<CR>

" TODOs
nnoremap <leader>ft :action ActivateTODOToolWindow<CR>

" Git / VCS (lazygit via native IntelliJ plugin, Ctrl+Alt+G default)
nnoremap <leader>lg <Action>(Lazygit.Toggle)
nnoremap <leader>lc :action CheckinProject<CR>       " commit (IDE)
nnoremap <leader>lp :action Vcs.Push<CR>             " push (IDE)
nnoremap <leader>lu :action Vcs.UpdateProject<CR>     " pull (IDE)

" Terminal
nnoremap <leader>ot :action ActivateTerminalToolWindow<CR>
nnoremap <leader>oT :action Terminal.SplitVertically<CR>

" Window management (IDE splits, not Vim windows)
nnoremap <leader>sv :action SplitVertically<CR>
nnoremap <leader>sh :action SplitHorizontally<CR>
nnoremap <leader>sx :action CloseContent<CR>
nnoremap <leader>sm :action ToggleDistractionFreeMode<CR>

" Diagnostics
nnoremap <leader>xx :action ActivateProblemsViewToolWindow<CR>
nnoremap <leader>xd :action GotoNextError<CR>

" AI Assistant
nnoremap <leader>pi :action ActivateAIAssistantToolWindow<CR>

" LSP (most work natively — these are fallbacks for IdeaVim mode)
nnoremap gd :action GotoDeclaration<CR>
nnoremap gi :action GotoImplementation<CR>
nnoremap gt :action GotoTypeDeclaration<CR>
nnoremap gR :action FindUsages<CR>
nnoremap <leader>ca :action ShowIntentionActions<CR>
nnoremap <leader>rn :action RenameElement<CR>

" Database
nnoremap <leader>db :action ActivateDatabaseToolWindow<CR>

" Build / Run
nnoremap <leader>rb :action Run<CR>
nnoremap <leader>rd :action Debug<CR>
nnoremap <leader>rm :action Maven.RunBuild<CR>

" Maven
nnoremap <leader>mv :action ActivateMavenToolWindow<CR>

" ── Restore critical IDE shortcuts removed from keymap ──
" These were removed in your "GNOME Vim" keymap. Add them back.
" Do this in Settings → Keymap, not in .ideavimrc:
"   • GotoClass → Ctrl+N
"   • GotoTest → Ctrl+Shift+T
"   • Switcher → Ctrl+Tab
"   • PreviousHighlightedError → Shift+F2 (not RenameElement!)
"   • RenameElement → Shift+F6 (the standard)

" ── Vim editor quality-of-life ──
set relativenumber
set number
set ignorecase
set smartcase
set scrolloff=3
set clipboard+=unnamedplus
set incsearch
set hlsearch

" Use system clipboard
set clipboard=unnamed,unnamedplus

" ── IDE-specific Vim settings ──
" Let the IDE handle some things
set ideajoin
set ideaput
```

---

## 6. Keymap Changes in IntelliJ Settings

### 6.1 Changes to "GNOME Vim" keymap

**Add back these removed shortcuts:**

| Action ID | New shortcut | Why |
|---|---|---|
| `GotoClass` | `Ctrl+N` | You removed this (Vim conflict). Use `j`/`↓` for movement instead. This is too important to lose. |
| `GotoTest` | `Ctrl+Shift+T` | You removed this. Critical for Java workflow. |
| `Switcher` | `Ctrl+Tab` | You removed this. No Vim conflict. Restore it. |
| `GotoPreviousError` | `Shift+F2` | Currently mapped to `RenameElement` in your keymap. Move RenameElement back to `Shift+F6`. |

**Move these:**

| Action ID | Old shortcut | New shortcut | Why |
|---|---|---|---|
| `RenameElement` | `Shift+F2` | `Shift+F6` | Standard IntelliJ. Free up Shift+F2 for errors. |
| `ActivateProjectToolWindow` | `Alt+1` (default) | (keep `Alt+1`, add `Space+ee` via IdeaVim) | Let IdeaVim handle Space leader. Keep IDE shortcuts as fallback. |

### 6.2 Conflicts to keep resolved in Vim's favor

These Vim shortcuts are worth keeping because the IDE alternatives are accessible:

| Shortcut | Vim action | IDE alternative |
|---|---|---|
| `Ctrl+D` | Scroll half-page down | Duplicate line via `Ctrl+C` then `Ctrl+V` or `Ctrl+D` context menu |
| `Ctrl+U` | Scroll half-page up | — (unused in IDE) |
| `Ctrl+B` | Page up | — |
| `Ctrl+F` | Page down | — (Find is `Ctrl+Shift+F` in IDE) |
| `Ctrl+E` | Scroll line down | Recent Files is accessible via `Ctrl+Tab` or `Space+fr` |
| `Ctrl+Y` | Scroll line up | Redo is `Ctrl+Shift+Z` in IDE |

---

## 7. What You Lose and What You Gain

### 7.1 What you lose

| Neovim/Zellij feature | In IntelliJ |
|---|---|
| `lazygit` TUI | Keep it. The [Lazygit IntelliJ plugin](https://plugins.jetbrains.com/plugin/30919-lazygit) by ckob embeds lazygit as a full-screen editor tab inside IntelliJ. Press `e` on any file to open it in the IDE. `Space+lg` toggles it. Your lazygit muscle memory carries over directly. |
| `snacks.picker` fuzzy finding | IntelliJ's `Search Everywhere` (`Shift+Shift`) and `Go to File` (`Ctrl+Shift+N`). These are actually better for large codebases because they index the project. |
| `nvim-dbee` (SQL client) | DataGrip built into IntelliJ Ultimate (`Alt+L`). This is a **massive upgrade**. DataGrip is the best SQL client you'll ever use. |
| `conform.nvim` (format-on-save) | IntelliJ has built-in formatters, reformat-on-save, and code style settings per language/project. **Upgrade.** |
| `nvim-lint` | IntelliJ inspections engine. **Massive upgrade** — inspections run in real-time, are configurable per-scope, and cover far more than any CLI linter. |
| `todo-comments` highlighting | IntelliJ has built-in TODO highlighting and the TODO tool window (`Alt+6` by default). |
| `which-key` (keymap discovery) | IntelliJ doesn't have a which-key equivalent. Use `Ctrl+Shift+A` (Find Action) to search for any action by name. |
| Terminal-based Pi | You can still run Pi in a terminal tab. See §4. |
| Zellij pane management | IntelliJ's split editor + tool windows. More structured, less flexible. |

### 7.2 What you gain (IntelliJ Ultimate exclusives)

| Feature | Why it's better |
|---|---|
| **Java IDE features** | No Neovim setup can match IntelliJ's Java: refactoring (extract method/class/interface, change signature, inline), intention actions, data flow analysis, dependency structure matrix, Spring/Micronaut framework integration |
| **DataGrip** built in | Full SQL IDE: query console, schema editor, data editor, import/export, ER diagrams. You already use this (`Alt+L`). |
| **Debugger** | Step-through debugger with breakpoints, watches, evaluate expression, frame drop, hot method replace. Java, Node.js, and Go. |
| **Built-in test runner** | Run/debug individual tests, test suites, coverage. No neotest needed. |
| **Refactoring depth** | Rename across the entire codebase (not just text replace — understands language semantics, renames in comments/strings, updates imports) |
| **VCS integration** | Commit UI (select hunks to include/exclude), shelve/unshelve, annotate/blame, compare with branch, interactive rebase |
| **HTTP Client** | `.http` files for API testing, saved in project |
| **Profiler** | Built-in CPU/memory profiling for Java and Node.js |
| **Endpoints tool window** | Lists all REST endpoints (Spring/Micronaut/JAX-RS) with URL, method, and a one-click HTTP client test |
| **TypeScript/React** | Full JS/TS/React/Next.js support with auto-imports, refactoring, JSX awareness |
| **Nx Console** | Visual Nx task runner for the gSim umbrella |
| **Low-memory startup** | IntelliJ 2026.1 loads projects fast, even large ones |
| **Terminal integration** | Terminal has smart command completion (suggests npm/maven/gradle commands from project), runs as a native shell with colors |

---

## 8. Phased Migration Plan

### 8.1 Phase 1 — Foundation (Day 1-2)

1. **Fix the keymap** — Restore the critical IDE shortcuts removed from
   "GNOME Vim" keymap (§6.1). Without `Ctrl+N`, `Ctrl+Shift+T`, and
   `Ctrl+Tab`, IntelliJ feels broken.
2. **Create `.ideavimrc`** — Use the template in §5. Start with just the
   `mapleader` and the most important Space-leader mappings (`Space+ee`,
   `Space+ff`, `Space+fs`, `Space+lg`, `Space+ot`).
3. **Unmap `Ctrl+K` from Vim** — Give it back to the IDE for VCS Commit.
   Add `iunmap <C-k>` and `nunmap <C-k>` to `.ideavimrc`.
4. **Open gSim in IntelliJ** — Use `File → Open → ~/Code/gSim`. Make sure
   Nx Console plugin is installed. Check that Maven imports succeed for
   `globalSimNaut`.

### 8.2 Phase 2 — Terminal & Pi (Day 3-5)

1. **Set up Pi** in a dedicated terminal tab (§4.2, Option A).
2. **Create Pi external tool** (§4.3) for a separate window if you prefer.
3. **Configure terminal** — Set terminal font, colors, and shell to match
   your current zellij terminal. `Settings → Tools → Terminal`.
4. **Disable Zellij autostart** for IntelliJ sessions. Use `zellij` only
   when you actually need a multiplexer.

### 8.3 Phase 3 — Git workflow (Week 1)

1. **Install the Lazygit IntelliJ plugin** ([Marketplace](https://plugins.jetbrains.com/plugin/30919-lazygit))
   by ckob. This brings lazygit into IntelliJ as a full-screen editor tab —
   no context-switching to a terminal needed.
2. **Map `Space+lg`** to `Lazygit.Toggle` in your `.ideavimrc`:
   `nnoremap <leader>lg <Action>(Lazygit.Toggle)`
3. **Press `e` on files** in lazygit to open them directly in the IDE editor
   (zero-config IPC bridge).
4. **Keep IntelliJ VCS as fallback** — `Space+lc` (commit), `Space+lp` (push),
   `Space+lu` (pull) still work via the IDE's VCS actions for quick operations.

### 8.4 Phase 4 — Pi via ACP (Week 1-3, ongoing)

1. **Immediate:** Configure JetBrains AI Assistant with pi-matching prompts
   (§4.5, Option C). This gives you pi-like behavior in the AI chat today.
2. **Short-term:** Check pi.dev roadmap / community for ACP support plans.
3. **If needed:** Build a thin ACP bridge that spawns `pi --mode rpc` (§4.4,
   Option B). This gives full pi agent capabilities inside the IDE.
4. **Fallback:** Keep a Pi terminal tab until ACP integration is ready.

### 8.5 Phase 5 — Multi-project + Alt+h/Alt+l (Week 2-3)

1. **Attach projects** — For repos you work on together, use
   `File → Attach Project`.
2. **Configure Alt+h/Alt+l** — Remap Maven and Database tool windows to
   `Space+mv` and `Space+db` (already in .ideavimrc). Bind `Alt+H` and
   `Alt+L` to `RecentFiles` and `Switcher` for cross-project navigation
   (§2.2, Option B).
3. **Learn the Switcher** (`Alt+L` / `Ctrl+Tab`) — Shows recent files
   across all attached projects.

### 8.6 Phase 6 — Polish (Week 3-4)

1. **Tune Space-leader mappings** — Add/remove IdeaVim mappings based on
   what you actually use.
2. **Create project templates** — For new Micronaut/Quarkus/Next.js
   projects, IntelliJ's New Project wizard is fast.
3. **Set up code style** — Import your Eclipse formatter XML for Java
   projects. `Settings → Editor → Code Style → Java → Scheme → Import`.
4. **Set up run configurations** — For gSim, create run configs for each
   service. Save them in the project so they sync via git.

---

## 9. Quick Reference: Keybinding Cheat Sheet

### Navigation

| Action | IntelliJ shortcut | IdeaVim (Space-leader) |
|---|---|---|
| Project tool window | `Alt+1` | `Space+ee` |
| Go to file | `Ctrl+Shift+N` | `Space+ff` |
| Find in files | `Ctrl+Shift+F` | `Space+fs` |
| Search everywhere | `Shift+Shift` | — |
| Go to class | `Ctrl+N` | — |
| Go to test | `Ctrl+Shift+T` | — |
| Recent files | `Ctrl+E` | `Space+fr` |
| Switcher (recent files + tools) | `Ctrl+Tab` | — |

### Editing

| Action | IntelliJ shortcut | Vim keys |
|---|---|---|
| Go to declaration | `Ctrl+B` / `Ctrl+Click` | `gd` |
| Go to implementation | `Ctrl+Alt+B` | `gi` |
| Find usages | `Alt+F7` | `gR` |
| Rename | `Shift+F6` | `Space+rn` |
| Show intentions | `Alt+Enter` | `Space+ca` |
| Quick documentation | `Ctrl+Q` | `K` |
| Reformat code | `Ctrl+Alt+L` | — |
| Optimize imports | `Ctrl+Alt+O` | — |

### Git

| Action | IntelliJ shortcut | IdeaVim (Space-leader) |
|---|---|---|
| Lazygit (full TUI) | `Ctrl+Alt+G` | `Space+lg` |
| Commit (IDE) | `Ctrl+K` | `Space+lc` |
| Push (IDE) | `Ctrl+Shift+K` | `Space+lp` |
| Update/pull (IDE) | `Ctrl+T` | `Space+lu` |

**Lazygit plugin:** Install from [Marketplace](https://plugins.jetbrains.com/plugin/30919-lazygit).
Press `e` on any file in lazygit to open it in the IDE editor.

### Terminal & Tools

| Action | IntelliJ shortcut | IdeaVim |
|---|---|---|
| Terminal | `Alt+F12` | `Space+ot` |
| Database | `Alt+L` | `Space+db` |
| AI Assistant | `Alt+K` | `Space+pi` |
| Problems | — | `Space+xx` |
| Maven | `Alt+H` | `Space+mv` |
| Run | `Shift+F10` | `Space+rb` |
| Debug | `Shift+F9` | `Space+rd` |

---

## 10. FAQ

### Q: Am I wishing for too much?

No. You're not wishing for too much. You have two real needs:

1. **Unify keybindings across two environments** — The Space-leader pattern
   from Neovim CAN be replicated in IdeaVim. The IntelliJ IDE shortcuts that
   conflict with Vim can be resolved by choosing which system owns each chord.
   This is configuration work, not impossible. The `.ideavimrc` in §5 handles
   80% of it.

2. **Multi-project workflow** — IntelliJ's "Attach Project" + Switcher +
   Recent Projects handles this well. It won't feel exactly like Zellij tabs,
   but it's more capable (full IDE features per project, not just terminal
   panes).

### Q: Will I ever be as fast as I am in Neovim?

For **editing text**, Neovim + Vim motions is about as fast as IntelliJ +
IdeaVim — you keep the Vim editing model either way.

For **code understanding and refactoring**, IntelliJ is faster. Operations
that take multiple Neovim LSP calls (e.g., "find all callers, then rename
this method, then update the interface, then fix imports in all callers")
are a single refactoring action in IntelliJ.

For **git**, the [Lazygit IntelliJ plugin](https://plugins.jetbrains.com/plugin/30919-lazygit)
lets you keep your lazygit workflow inside IntelliJ. `Space+lg` toggles it
as a full-screen editor tab. Press `e` on any file to open it in the IDE.
Your lazygit muscle memory transfers directly — no compromise needed.

### Q: What about Zed / Cursor / VS Code?

You've invested 13 years in IntelliJ and know its advanced features. You
have IntelliJ Ultimate. You work in Java and TypeScript. Switching to
another IDE would lose the Java features that are the main reason to use
IntelliJ. This is the right tool for your stack.

### Q: Can I keep using Neovim for quick edits?

Yes. `nvim` is just a program. You can still open it from the terminal for
quick config edits, dotfiles, or scripts where you don't need the full IDE.
IntelliJ and Neovim are not mutually exclusive — they're complementary.
Use IntelliJ for project work, Neovim for quick terminal edits.

---

## 11. Dotfiles Integration

### 11.1 What can be tracked

Unlike neovim/zellij/pi — where the entire config directory is symlinked into
`~/.config/` — IntelliJ's config directory is **version-specific**
(`~/.config/JetBrains/IntelliJIdea2026.1/`) and contains machine-local state
(recent projects, window layouts, JDK tables, licenses). You cannot symlink
the whole thing.

**JetBrains Settings Sync** already handles cross-machine sync for:
- Keymaps (`keymaps/`)
- Code styles (`codestyles/`)
- Color schemes (`colors/`)
- File templates (`fileTemplates/`)
- Inspection profiles (`inspection/`)
- Most options (`options/vim_settings.xml`, `options/editor.xml`, etc.)

**The only file Settings Sync does NOT handle** is `~/.ideavimrc` (IdeaVim
reads it from the home directory, not from the IntelliJ config tree).

### 11.2 Dotfiles directory structure

```
~/dotfiles/intellij/
  .gitignore            ← whitelist: ignore *, unignore specific files
  ideavimrc             ← ~/.ideavimrc (symlinked)
  keymaps/
    GNOME Vim.xml       ← reference copy (Settings Sync handles live sync)
  MIGRATION-ADVISORY.md ← this file
```

### 11.3 `.gitignore` whitelist

Add to `~/dotfiles/.gitignore`:

```gitignore
# IntelliJ — track config only
intellij/*
!intellij/ideavimrc
!intellij/keymaps/
!intellij/MIGRATION-ADVISORY.md
```

### 11.4 `fedora/install.sh` additions

```bash
# IntelliJ IdeaVim config (home directory, version-independent)
ln -sf "$HOME/dotfiles/intellij/ideavimrc" "$HOME/.ideavimrc"
```

### 11.5 Why not symlink the keymap?

The keymap XML lives at a version-specific path:
`~/.config/JetBrains/IntelliJIdea2026.1/keymaps/GNOME Vim.xml`

When IntelliJ upgrades to `2026.2`, that path changes. Symlinking would break.
Instead:

1. **Settings Sync** keeps the live keymap in sync across machines
2. **The dotfiles copy** (`intellij/keymaps/GNOME Vim.xml`) serves as a
   version-controlled backup with full git history
3. For first-time setup, you can manually copy it into the current IntelliJ
   config dir, or just let Settings Sync pull it from the cloud

### 11.6 Creating `ideavimrc` from the template

Once you finalize your `.ideavimrc` (using the template in §5), save it as
`~/dotfiles/intellij/ideavimrc`. The `fedora/install.sh` symlink will take
effect on the next run.

```bash
# First time: create the file, then let install.sh symlink it
cp ~/.ideavimrc ~/dotfiles/intellij/ideavimrc
# On future machines: install.sh does:
#   ln -sf "$HOME/dotfiles/intellij/ideavimrc" "$HOME/.ideavimrc"
```
