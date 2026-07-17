# Tmux Session Persistence on Fedora / Nobara

## Overview

Tmux sessions persist across reboots using two plugins working together:

| Plugin             | Job                                                                          |
| ------------------ | ---------------------------------------------------------------------------- |
| **tmux-resurrect** | Save/restore sessions to/from disk (`~/.local/share/tmux/resurrect/`)        |
| **tmux-continuum** | Auto-save every 15 min + auto-restore on tmux start + auto-start via systemd |

## Setup

### 1. tmux.conf

```tmux
# ── Session persistence ──────────────────────────────
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'
set -g @continuum-restore 'on'
set -g @continuum-save-interval '15'
set -g @continuum-boot 'on'

# Critical: use start-server instead of new-session -d.
# Avoids systemd Type=forking PID tracking race (see Issue #1 below).
set -g @continuum-systemd-start-cmd 'start-server'

# Save/restore Neovim sessions
set -g @resurrect-capture-pane-contents 'on'
set -g @resurrect-strategy-vim 'session'

run '~/.config/tmux/plugins/tpm/tpm'
```

### 2. Reload and generate the systemd unit

```bash
# Delete any stale unit file first (if this isn't a fresh install)
rm -f ~/.config/systemd/user/tmux.service

# Reload config so continuum picks up all settings
tmux source-file ~/.config/tmux/tmux.conf

# Start a detached session — continuum regenerates the unit file
tmux new-session -d
```

This creates `~/.config/systemd/user/tmux.service` with:

```ini
ExecStart=/usr/bin/tmux start-server
ExecStop=.../save.sh
ExecStop=/usr/bin/tmux kill-server
```

### 3. Override to fix PID tracking (Fedora/Nobara only)

The continuum-generated unit uses `Type=forking`. On Fedora/Nobara, systemd can't reliably track the tmux server PID with this type — the service dies within 1 second before continuum can restore sessions.

Apply a drop-in override:

```bash
mkdir -p ~/.config/systemd/user/tmux.service.d
```

Write `~/.config/systemd/user/tmux.service.d/override.conf`:

```ini
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=
ExecStart=/home/HOME/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh
ExecStop=
ExecStop=/usr/bin/tmux kill-server
KillMode=process
```

Then:

```bash
systemctl --user daemon-reload
systemctl --user enable tmux.service   # already enabled, but verify
systemctl --user start tmux.service
```

### 4. Verify

```bash
systemctl --user status tmux.service
```

Expected output:

```
● tmux.service - tmux default session (detached)
     Active: active (exited)                ← "active" is the key state
   Main PID: 12345 (code=exited, status=0/SUCCESS)
     CGroup: /user.slice/.../tmux.service   ← has its own cgroup
```

Check the drop-in is loaded:

```bash
systemctl --user show tmux.service -p Type --value
# → oneshot
```

## Known Issues

### Issue #1: `Type=forking` PID tracking failure

**Symptoms:** `systemctl --user status tmux.service` shows `MainPID=0`, service dies within 1 second of starting, sessions lost on reboot.

**Root cause:** systemd with `Type=forking` + `GuessMainPID=yes` cannot reliably find the forked tmux server process. The service transitions to "dead" before continuum's `continuum_restore.sh` runs its 1-second delayed restore.

**Fix:** The `Type=oneshot` + `RemainAfterExit=yes` override above. This eliminates PID tracking entirely — systemd considers the service active as long as the ExecStart process (restore.sh) completed successfully.

### Issue #2: `ExecStop` save.sh says "no server running"

This is **harmless and expected**. The "no server running" messages in `journalctl --user -u tmux.service` are from continuum's internal auto-save running inside tmux, not from the systemd ExecStop. Save files are still written every 15 minutes by continuum, independent of systemd.

## Manual Save / Restore

### Key bindings (set by tmux-resurrect)

| Binding           | Action                      |
| ----------------- | --------------------------- |
| `prefix + Ctrl-s` | Save current sessions       |
| `prefix + Ctrl-r` | Restore last saved sessions |

### From the shell

```bash
# Save
~/.config/tmux/plugins/tmux-resurrect/scripts/save.sh

# Restore
~/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh

# Restore from a specific save file
rm ~/.local/share/tmux/resurrect/last
ln -s tmux_resurrect_20260716T224529.txt ~/.local/share/tmux/resurrect/last
~/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh
```

### Save file location

```
~/.local/share/tmux/resurrect/
├── tmux_resurrect_20260716T224529.txt   ← periodic saves
├── last → tmux_resurrect_20260716T224529.txt   ← symlink to most recent
├── pane_contents.tar.gz                 ← pane contents (if enabled)
└── restore/pane_contents/               ← restored pane contents cache
```

The `last` symlink is what restore.sh reads. It's updated by continuum auto-save and by manual `save.sh`.

## Troubleshooting

### Sessions didn't restore after reboot

1. **Check service state:**

   ```bash
   systemctl --user status tmux.service
   # Look for Active: active (exited) and Type=oneshot
   ```

2. **Check if save files exist:**

   ```bash
   ls -la ~/.local/share/tmux/resurrect/last
   cat ~/.local/share/tmux/resurrect/last  # verify it has session data
   ```

3. **Manual restore:**

   ```bash
   ~/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh
   ```

4. **Drop-in not loaded:**
   ```bash
   systemctl --user show tmux.service -p Type --value
   # Should say "oneshot", not "forking"
   ```
   If still `forking`, the override file isn't being read. Check:
   ```bash
   ls -la ~/.config/systemd/user/tmux.service.d/override.conf
   systemctl --user daemon-reload
   ```

### Service won't start

```bash
journalctl --user -u tmux.service --no-pager -n 50
```

Common errors:

- `can't find session: 0` — restore tried to recreate windows but layout is stale. Usually resolves on next save.
- `no server running on /tmp/tmux-1000/default` — continuum auto-save polling while server is restarting. Harmless.

## Architecture

```
Boot → systemd --user → tmux.service
                           │
                     restore.sh ← reads → ~/.../resurrect/last
                           │
                     tmux server (PID managed by tmux, not systemd)
                           │
                     continuum auto-save (every 15 min)
                           │
                     save.sh → writes → ~/.../resurrect/tmux_resurrect_*.txt
                           │
                     updates last symlink

Shutdown → systemd → ExecStop: kill-server → tmux exits cleanly
                     (save.sh fails silently — expected, continuum already saved)
```
