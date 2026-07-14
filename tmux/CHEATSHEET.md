# Tmux Cheat Sheet

**Prefix:** `Ctrl+b`

## Session management (project switching)

| Key | Action |
|---|---|
| `Ctrl+b s` | **Session picker** — text-filterable list of all sessions (like IntelliJ recent projects) |
| `Ctrl+b S` | Create a new named session in the current directory |
| `Ctrl+b $` | Rename current session |
| `Ctrl+b (`  | Switch to previous session |
| `Ctrl+b )`  | Switch to next session |
| `Ctrl+b X`  | Kill current session |

## Windows

| Key | Action |
|---|---|
| `Ctrl+b c`  | Create new window |
| `Ctrl+b ,`  | Rename current window |
| `Ctrl+b w`  | Window picker (text-filterable) |
| `Ctrl+b 0-9` | Switch to window by number |
| `Ctrl+b n`  | Next window |
| `Ctrl+b p`  | Previous window |
| `Ctrl+b &`  | Kill current window |

## Panes

| Key | Action |
|---|---|
| `Ctrl+b %`  | Split vertically |
| `Ctrl+b "`  | Split horizontally |
| `Ctrl+b ←↑↓→` | Navigate panes |
| `Ctrl+b z`  | Toggle pane fullscreen |
| `Ctrl+b x`  | Kill current pane |
| `Ctrl+b !`  | Break pane into new window |
| `Ctrl+b {`  | Swap pane left |
| `Ctrl+b }`  | Swap pane right |

## Copy mode (scrolling)

| Key | Action |
|---|---|
| `Ctrl+b [`  | Enter copy/scroll mode |
| `q`         | Exit copy mode |
| `↑/↓/PgUp/PgDn` | Scroll (in copy mode) |
| `Space`     | Start selection (in copy mode) |
| `Enter`     | Copy selection to clipboard |

## Config

| Key | Action |
|---|---|
| `Ctrl+b r`  | Reload `tmux.conf` |

## Typical workflow

```
# Start a new session for a project
tmux new -s dotfiles
tmux new -s alpha-backend
tmux new -s api-gateway

# Switch between projects
Ctrl+b s  →  type project name  →  Enter

# Attach to an existing session from shell
tmux attach -t dotfiles
tmux ls   # list all sessions
```

**One session = one project = one Neovim.** Each session gets its own Neovim
process with auto-session.nvim restoring the correct buffers. No tabs, no panes —
just pure project switching.
