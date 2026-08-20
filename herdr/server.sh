#!/usr/bin/env bash
# Start the herdr headless server (systemd user unit entrypoint).
# No-op when a server is already running (e.g. one spawned by a client),
# so the unit is safe to enable alongside normal `herdr` usage.
set -u

hdr="${HERDR_BIN_PATH:-herdr}"

if "$hdr" status server 2>/dev/null | grep -q 'status: running'; then
  exit 0
fi

exec "$hdr" server
