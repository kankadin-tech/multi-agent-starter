#!/usr/bin/env bash
# 디스패처 테스트 공용 헬퍼. 각 test_*.sh 첫 줄: . "$(dirname "$0")/_lib.sh"
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DISPATCHER="$REPO/_shared/adapters/call_worker.sh"
PASS=0; FAIL=0

assert_eq() {       # assert_eq <desc> <expected> <actual>
  if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS+1))
  else echo "  FAIL: $1 (expected [$2] got [$3])"; FAIL=$((FAIL+1)); fi
}
assert_contains() { # assert_contains <desc> <needle> <haystack>
  case "$3" in *"$2"*) echo "  PASS: $1"; PASS=$((PASS+1));;
            *) echo "  FAIL: $1 (missing [$2])"; FAIL=$((FAIL+1));; esac
}
finish() { echo "  ($PASS pass / $FAIL fail)"; [ "$FAIL" -eq 0 ]; }

new_root() {        # stdin=backends.json → echoes temp root path
  local d; d="$(mktemp -d)"; mkdir -p "$d/_shared/bin"
  cat > "$d/_shared/backends.json"; printf '%s' "$d"
}
fake_bin() {        # fake_bin <root> <name> <exit> [sleep_secs]
  local r="$1" n="$2" rc="$3" s="${4:-0}"
  { echo '#!/usr/bin/env bash'; echo "sleep $s"; echo "echo fake-$n-out"; echo "exit $rc"; } \
    > "$r/_shared/bin/$n"
  chmod +x "$r/_shared/bin/$n"
}
dispatch() {        # dispatch <root> <role> <brief> → sets OUT, ERR, RC
  local ef; ef="$(mktemp)"
  OUT="$(MULTIAGENT_ROOT="$1" PATH="$1/_shared/bin:$PATH" bash "$DISPATCHER" "$2" "$3" 2>"$ef")"; RC=$?
  ERR="$(cat "$ef")"; rm -f "$ef"
}
