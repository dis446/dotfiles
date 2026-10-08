# reviewr — day-to-day guide

A code-review pane for herdr: the agent's diff, syntax-highlighted, beside the
chat. You comment on lines and send the comments into the agent's input. It
never edits the worktree and sends nothing on its own.

|           |                                                                                                       |
| --------- | ----------------------------------------------------------------------------------------------------- |
| Upstream  | https://github.com/persiyanov/herdr-reviewr                                                           |
| Install   | `herdr plugin install persiyanov/herdr-reviewr` (needs herdr ≥ 0.9.3)                                 |
| Toggle    | **`alt+d`** — or `herdr plugin action invoke toggle --plugin persiyanov.reviewr`                      |
| Config    | `~/.config/herdr/plugins/config/persiyanov.reviewr/config.toml` — machine-local, **not** in this repo |
| Every key | press `?` in the pane; it lists only what works in the current mode                                   |

## The loop

Press `alt+d` from the **`pi` tab** — it splits to the right of the *focused*
pane, so that puts the diff beside the agent's chat (press it from the nvim tab
and you get it beside nvim).

1. **Skim.** It opens on the `uncommitted` scope — staged, unstaged, untracked:
   everything the agent just touched. `j`/`k` move the file list, `]`/`[` step
   hunk by hunk across files, `f`/`F` jump file to file, `Tab` switches focus
   between navigator and diff.
2. **Comment.** `v` selects a line, `v` then `j`/`k` a range, then `c`, type,
   `Enter`.
3. **Check your notes.** `n`/`N` step between comments, `l` lists them all, `d`
   deletes, `e` re-edits. On an uncommented line `e` opens the file in
   `$EDITOR`/nvim at that line.
4. **Send.** `s` delivers the whole set to the workspace's agent. One agent takes
   them straight away; several open a picker. `y` copies to the clipboard
   instead.
5. **Verify.** `t` switches to `last turn` — only what that turn changed — and
   send again if the fix is off.

Nothing leaves the pane until you press `s`, and comments are in memory only:
closing a pane with unsent comments loses them.

## Scopes

`u` / `b` / `t` / `g` set what the diff is measured against. Switching beats the
`default_scope` setting for the rest of the session.

| Key | Scope       | Use it for                                                                                         |
| --- | ----------- | -------------------------------------------------------------------------------------------------- |
| `u` | uncommitted | right after an edit — working tree vs `HEAD`                                                       |
| `b` | branch      | **the pre-MR view**: uncommitted plus the branch's commits, vs the merge-base with the base branch |
| `t` | last turn   | cheapest way to check a single task — only what the agent's most recent turn touched               |
| `g` | commits     | a commit or contiguous range picked with `G` — what it committed, without unsaved edits mixed in   |

`B` re-picks the base for `b`: any branch or revision, fuzzily filtered. The list
marks the repo default, the open MR's target (`pr base`), and the branch checked
out here. The pick is per-worktree and holds until you change it. Every scope
respects `.gitignore`, so untracked build output never clutters the diff — track
a file to review it.

## Tabs

| Key | Tab       | Notes                                                                                                                                                                                                                                                           |
| --- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `1` | Changes   | the default                                                                                                                                                                                                                                                     |
| `2` | All files | any file in the worktree, changed or not. `/` fuzzy-finds names and greps code; `Ctrl+F` finds in the open file; `m` flips markdown between source and rendered (handy for a feature's `BRIEF.md`); `p` cycles navigator position, `z` hides it, `<`/`>` resize |
| `3` | PR / MR   | read-only mirror of the branch's GitHub/GitLab MR via `gh`/`glab`. `o` opens it in the browser. It never posts                                                                                                                                                  |

## Keys you actually use

| Key                         | Does                                        |
| --------------------------- | ------------------------------------------- |
| `alt+d`                     | toggle the pane (herdr-level)               |
| `j` `k` · `]` `[` · `f` `F` | move · next/prev hunk · next/prev file      |
| `Tab`                       | switch focus between navigator and diff     |
| `v` `c`                     | select · comment                            |
| `n` `N` `l` `d` `e`         | next/prev comment · list · delete · edit    |
| `s` `y`                     | send to agent · copy to clipboard           |
| `u` `b` `t` `g` `B` `G`     | scope · base pick · commit pick             |
| `1` `2` `3`                 | tab                                         |
| `/` `Ctrl+F` `:`            | search worktree · find in file · go to line |
| `w` `m`                     | toggle wrap · toggle markdown render        |
| `r` `?` `q`                 | refresh · shortcuts · quit                  |

The mouse works too: drag to select and copy, click the line-number gutter to
comment, click files and tabs, scroll with the wheel.

## Day to day

- **After every agent turn** — `alt+d`, `t` (last turn), read, `c`, `s`. The
  pane is persistent, so the second time you just press `alt+d`.
- **Before opening an MR** — `b`, then read the whole branch as one diff. This is
  the pass that catches what a turn-by-turn review misses.
- **In the feature workflow** — `feature-start` opens one herdr workspace per
  feature with a worktree per touched repo. Open reviewr there and `b` is already
  that worktree's feature branch against its platform base; `3` shows the live MR
  once `feature_mr` has run.
- **When `s` refuses** — it means the agent is sitting at a permission prompt and
  the paste would be dropped. Answer the prompt, send again; your comments are
  still there.

## Gotchas

- **`auto_open` is off** in this repo's config. reviewr auto-opens on
  `worktree.opened`, and with ~40 restored worktree workspaces that means a pane
  in every one at boot — against this repo's lazy-pane tilt. Set
  `auto_open = true` if you'd rather it appear for new worktrees.
- **A pane in a background tab is lazy** — it picks up file changes 30 seconds
  after they happen, and immediately when you switch back. Press `r` to force it.
- **Sending is all-or-nothing** — `s` and `y` deliver the whole set and clear it.
  A failure leaves everything in place.
- **`herdr plugin install` leaves two dangling symlinks** (v0.46.0):
  `~/.local/bin/herdr-reviewr` and
  `~/.local/state/herdr/plugins/persiyanov.reviewr/bin/herdr-reviewr` both point
  at the installer's own deleted staging dir, because `herdr/install.sh` uses
  `$HERDR_PLUGIN_ROOT` as its link root. The pane and the actions are unaffected
  — they resolve `bin/herdr-reviewr` against the live plugin root. Re-point them
  only if you want the plain `herdr-reviewr <repo>` shell mode (works without
  herdr, but then `s` and the `last turn` scope are unavailable):

  ```bash
  R=$(echo ~/.config/herdr/plugins/github/persiyanov.reviewr-*/bin/herdr-reviewr)
  ln -sfn "$R" ~/.local/bin/herdr-reviewr
  ln -sfn "$R" ~/.local/state/herdr/plugins/persiyanov.reviewr/bin/herdr-reviewr
  ```

- **Updating** — uninstall then install; the config is keyed by plugin id and
  survives:

  ```bash
  herdr plugin uninstall persiyanov.reviewr && herdr plugin install persiyanov/herdr-reviewr
  ```

  Re-check the two symlinks above afterwards.

## Config

`~/.config/herdr/plugins/config/persiyanov.reviewr/config.toml` — reviewr's own
file; settings in herdr's `config.toml` never reach it. It is re-read on save, so
edits apply without a relaunch, and an invalid file is rejected whole and
recovers when you fix it. Machine-local: it does **not** come from this repo, so
recreate it on a new machine.

Currently set:

```toml
theme = "tokyo-night"   # matches herdr's [theme] name
auto_open = false       # see Gotchas
```

Other keys worth knowing: `default_scope`, `markdown_view = "rendered"`,
`navigator_position` (`right`/`bottom`/`left`/`top`), `toggle_placement`
(`split`/`overlay`/`zoomed`/`tab`) + `toggle_direction` (`right`/`down`),
`github_host`/`gitlab_host` for self-hosted forges, `editor` (e.g.
`"code -g {file}:{line}"`), and `[keybindings]` to rebind any action.
