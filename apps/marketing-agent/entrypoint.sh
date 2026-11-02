#!/bin/sh
set -eu
# The upstream root/s6 entrypoint is deliberately bypassed under restricted.
# /opt/data is an fsGroup-backed PVC; verify it is writable at startup.
test -w /opt/data
mkdir -p "$XDG_RUNTIME_DIR"
chmod 0700 "$XDG_RUNTIME_DIR"
exec /opt/hermes/.venv/bin/hermes serve --host 0.0.0.0 --port 9119
