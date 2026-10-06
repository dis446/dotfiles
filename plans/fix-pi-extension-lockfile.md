# Fix the corrupted pi extension lockfile

> Written 2026-10-06 on the Fedora work host, from a hand-diagnosed repair.
> **Audience: a pi instance running on another machine** that was provisioned
> before that date. Do §1 (detect). If it reports bogus keys, do §2–§4.

## Why this file exists

`~/.pi/agent/npm` holds the pi extensions (`pi-subagents`, `context-mode`,
`pi-btw`, `rpiv-ask-user-question`, `ponytail`). It is npm-managed and
**gitignored** — `pi/agent/npm/.gitignore` is `*` + `!.gitignore` — so its state
is per machine, not in the repo. A `git pull` cannot fix this, and every machine
needs its own repair.

## What is broken

The lockfile accumulated bogus, `../`-relative keys, one `dotfiles/` level per
extension update:

```
../../../dotfiles/dotfiles/dotfiles/pi/agent/npm/node_modules/pi-subagents
```

Those keys are relative to the **symlinked** path (`~/.pi/agent/npm` →
`~/dotfiles/pi/agent/npm`) instead of the realpath, so npm has no correct view of
the tree: `npm ls` reports most packages as `extraneous`, and
`node_modules/.package-lock.json` is corrupted the same way.

It is **not a functional break** — extensions still load and run. It is a broken
npm state: it hides which extension versions are installed, and makes any npm
operation in that directory unpredictable. The machine this was diagnosed on had
1159 entries / 1158 bogus / 0 canonical, spread over 8 accumulated levels.

## 1. Detect

```bash
python3 -c "
import json, os
p = os.path.expanduser('~/.pi/agent/npm/package-lock.json')
if not os.path.exists(p):
    print('no lockfile — nothing to fix'); raise SystemExit
pk = json.load(open(p))['packages']
bogus = sum(1 for k in pk if 'dotfiles' in k)
canon = sum(1 for k in pk if k.startswith('node_modules/'))
print(f'entries={len(pk)} canonical={canon} bogus={bogus}')
print('FIX NEEDED' if bogus else 'OK — canonical, stop here')
"
```

**`bogus=0` means you are done — do not run the fix.** On a healthy machine the
output looks like `entries=288 canonical=287 bogus=0`.

## 2. Fix

```bash
cd ~/dotfiles/pi/agent/npm          # the realpath — never ~/.pi/agent/npm

# a) Record the currently installed versions, so nothing silently bumps.
node -e '
const fs = require("fs");
const deps = JSON.parse(fs.readFileSync("package.json")).dependencies || {};
for (const name of Object.keys(deps)) {
  try { console.log(name + "@" + JSON.parse(fs.readFileSync(`node_modules/${name}/package.json`)).version); }
  catch { }
}' | tee /tmp/pi-ext-versions.txt

# b) Back up the broken state.
mkdir -p /tmp/pi-ext-backup
cp -a package.json package-lock.json /tmp/pi-ext-backup/ 2>/dev/null || true

# c) Rebuild from scratch. The removal is REQUIRED — see below.
rm -rf node_modules package-lock.json
npm install --no-audit --no-fund
```

**The `rm -rf` is the whole fix.** Running `npm install` on top of a corrupt
lockfile does *not* repair it: npm preserves the entries it cannot map and
re-relativises them, which is exactly how this grew to 8 levels across 8 updates.
Measured on the repaired machine: `npm install` over a corrupt lockfile grew it
to 436 entries while *retaining* 148 bogus keys; only the `rm -rf` produced 0.

Do **not** hand-edit the lockfile, and prefer not to `npm update` in this
directory — bumping extensions is what caused past incidents (pi-subagents
0.76.0 called a method its own module did not define; fixed in 0.76.1).

## 3. Verify

```bash
cd ~/dotfiles/pi/agent/npm
python3 -c "
import json
for p in ('package-lock.json', 'node_modules/.package-lock.json'):
    pk = json.load(open(p))['packages']
    print(f'{p}: entries={len(pk)} canonical={sum(1 for k in pk if k.startswith(\"node_modules/\"))} bogus={sum(1 for k in pk if \"dotfiles\" in k)}')
"
echo "extraneous: $(npm ls --depth=0 2>/dev/null | grep -c extraneous)   # expect 0"
echo "--- versions (compare with /tmp/pi-ext-versions.txt) ---"
for p in pi-subagents context-mode pi-btw @juicesharp/rpiv-ask-user-question @dietrichgebert/ponytail; do
  printf "  %-42s %s\n" "$p" "$(python3 -c "import json;print(json.load(open('node_modules/$p/package.json'))['version'])" 2>/dev/null || echo MISSING)"
done
```

Expected: both files `bogus=0`, `extraneous: 0`, and the same versions as step
2a. If a version moved, that is a semver-compatible bump inside its `^` range —
either accept it, or pin back the old one and re-verify:

```bash
npm install --no-audit --no-fund --no-save <pkg>@<version>   # then re-run §3
```

(Verified safe: on a clean lockfile this form leaves the keys canonical.)

## 4. Restart pi

**Required.** The fix replaces the entire `node_modules` tree that the running
pi session loaded its extensions from, so in-memory extension code is stale and
live children (the context-mode MCP servers run out of that directory) are on
deleted inodes. Quit and restart pi; do not just `/reload` — it re-runs the
extension entry without re-reading its transitive modules.

## 5. Report

Quote the §1 before-line and the §3 after-lines, and say whether any extension
version moved. Then note that this is machine-local: nothing was committed.

## Notes

- **Related, already automated:** the other change these machines needed — pi
  moving from an npm global in `~/.local` to the official flake
  (`github:earendil-works/pi/stable`) — is handled by the OS install script
  itself. Look for the `TODO(pi-npm-migration)` block in
  `arch|fedora|nobara|ubuntu/install.sh`; re-running that script performs it
  idempotently. macOS keeps npm pi (pre-Home-Manager track) and needs neither.
- **Evidence, and what was ruled out** (so this is not re-litigated): the bogus
  keys could not be *recreated* with the current npm from a clean state by any
  invocation tried — plain `npm install`, explicit-spec install, explicit-spec +
  `--no-save`, `--package-lock-only`, or the same install run from an **aliased
  cwd** (a symlink pointing at the project). All produced canonical keys. The
  depth distribution of the damage (1–8 `dotfiles` levels, each holding a
  near-complete copy of the tree) shows it was compounded, not created, by the
  update runs; `$PWD`, `process.cwd()`, and the shell all agreed on the realpath,
  and no `npm_config_*` variable was set. Conclusion: an older npm or an older pi
  introduced the first bad level, and inheritance did the rest — so a pristine
  rebuild is both the fix and durable.
- **Tripwire** if you want to check later: §1 returning `bogus=0` after an
  extension update means it has not come back.
