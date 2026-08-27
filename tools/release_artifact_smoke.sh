#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
VERSION=$(sed -n 's/.*:version "\([^"]*\)".*/\1/p' "$ROOT/project.janet")
JANET_ARCHIVE="$ROOT/dist/slynet-$VERSION.tar.gz"
EMACS_ARCHIVE="$ROOT/dist/slynet-$VERSION.tar"

[ -n "$VERSION" ] || { echo "artifact-smoke: cannot determine project version" >&2; exit 1; }
[ -f "$JANET_ARCHIVE" ] || { echo "artifact-smoke: missing $JANET_ARCHIVE" >&2; exit 1; }
[ -f "$EMACS_ARCHIVE" ] || { echo "artifact-smoke: missing $EMACS_ARCHIVE" >&2; exit 1; }

TMP=$(mktemp -d "${TMPDIR:-/tmp}/slynet-artifact-smoke.XXXXXX")
SERVER_PID=
cleanup() {
  if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$TMP/janet" "$TMP/emacs"
tar -xzf "$JANET_ARCHIVE" -C "$TMP/janet"
tar -xf "$EMACS_ARCHIVE" -C "$TMP/emacs"

JANET_ROOT="$TMP/janet/slynet-$VERSION"
EMACS_ROOT="$TMP/emacs/slynet-$VERSION"
[ -f "$JANET_ROOT/slynet/cli.janet" ] || { echo "artifact-smoke: Janet CLI missing after extraction" >&2; exit 1; }
[ -f "$JANET_ROOT/docs/RELEASE_STATUS.md" ] || { echo "artifact-smoke: release status missing from Janet artifact" >&2; exit 1; }
[ -f "$JANET_ROOT/docs/generated/protocol-inventory.yml" ] || { echo "artifact-smoke: protocol inventory missing from Janet artifact" >&2; exit 1; }
[ -f "$EMACS_ROOT/slynet.el" ] || { echo "artifact-smoke: Emacs slynet.el missing after extraction" >&2; exit 1; }
[ -f "$EMACS_ROOT/slynet-client.el" ] || { echo "artifact-smoke: Emacs slynet-client.el missing after extraction" >&2; exit 1; }

VERSION_OUTPUT=$(cd "$JANET_ROOT" && JANET_PATH="${JANET_PATH:-}:$JANET_ROOT" janet slynet/cli.janet --version)
printf '%s\n' "$VERSION_OUTPUT" | grep -F "$VERSION" >/dev/null || {
  echo "artifact-smoke: extracted Janet CLI version mismatch" >&2
  printf '%s\n' "$VERSION_OUTPUT" >&2
  exit 1
}

PORT=$(python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)

(
  cd "$JANET_ROOT"
  exec env JANET_PATH="${JANET_PATH:-}:$JANET_ROOT" \
    janet slynet/cli.janet --tcp --host 127.0.0.1 --port "$PORT"
) >"$TMP/server.log" 2>&1 &
SERVER_PID=$!

python3 - "$PORT" "$SERVER_PID" "$TMP/server.log" <<'PY'
import os
import socket
import sys
import time

port = int(sys.argv[1])
pid = int(sys.argv[2])
log = sys.argv[3]
deadline = time.monotonic() + 10
while time.monotonic() < deadline:
    try:
        os.kill(pid, 0)
    except OSError:
        print("artifact-smoke: extracted Janet server exited before readiness", file=sys.stderr)
        print(open(log, encoding="utf-8", errors="replace").read(), file=sys.stderr)
        raise SystemExit(1)
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=0.2):
            break
    except OSError:
        time.sleep(0.05)
else:
    print(f"artifact-smoke: server never became ready on 127.0.0.1:{port}", file=sys.stderr)
    print(open(log, encoding="utf-8", errors="replace").read(), file=sys.stderr)
    raise SystemExit(1)
PY

SLYNET_SMOKE_PORT="$PORT" emacs -Q --batch \
  -L "$EMACS_ROOT" \
  -l "$ROOT/tools/release_artifact_smoke.el"

echo "artifact-smoke: extracted Janet and Emacs artifacts passed start/connect/MREPL/eval"
