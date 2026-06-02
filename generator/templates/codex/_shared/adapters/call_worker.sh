#!/usr/bin/env bash
# call_worker.sh — backends.json 디스패처 (cli/api 전용).
# native/mcp는 오케스트레이터가 직접 호출(디스패처 비경유).
# 사용: call_worker.sh <role> <brief-file>
# 반환: stdout에 result envelope(JSON). exit 0=성공, 비0=실패/거부.
#
# 안전 계약(rev2): execve 배열(shell/eval 금지), brief 절대경로, timeout+kill-after,
# 비대화(stdin /dev/null), result envelope, fallback 순차, stderr key redaction.
set -euo pipefail

die() { echo "call_worker: $1" >&2; exit "${2:-1}"; }

ROLE="${1:-}"; BRIEF="${2:-}"
[ -n "$ROLE" ] && [ -n "$BRIEF" ] || die "usage: call_worker.sh <role> <brief-file>" 64

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${MULTIAGENT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
BACKENDS="$ROOT/_shared/backends.json"

command -v jq >/dev/null 2>&1 || die "jq 필요(JSON 파싱)" 5
[ -f "$BACKENDS" ] || die "backends.json 없음: $BACKENDS" 5

# timeout 명령 탐지
TIMEOUT_BIN=""
command -v timeout  >/dev/null 2>&1 && TIMEOUT_BIN=timeout
[ -z "$TIMEOUT_BIN" ] && command -v gtimeout >/dev/null 2>&1 && TIMEOUT_BIN=gtimeout

# brief 절대경로화 + 검증
case "$BRIEF" in *..*) die "brief 경로에 '..' 금지" 6;; esac
[ -f "$BRIEF" ] || die "brief 파일 없음: $BRIEF" 6
BRIEF="$(cd "$(dirname "$BRIEF")" && pwd)/$(basename "$BRIEF")"

rec="$(jq -c --arg r "$ROLE" '.workers[$r] // empty' "$BACKENDS")"
[ -n "$rec" ] || die "role 미정의: $ROLE" 2

# stderr key/token redaction (긴 영숫자열 마스킹)
redact() { sed -E 's/[A-Za-z0-9_-]{32,}/[REDACTED]/g'; }

# 단일 backend(또는 fallback) 실행 → envelope 부분(JSON)을 stdout, exit code 반환
run_backend() {
  local spec="$1"
  local ctype bmode tmo cwdp model wd out err rc start dur
  ctype="$(jq -r '.call_type' <<<"$spec")"
  model="$(jq -r '.model // "?"' <<<"$spec")"
  case "$ctype" in
    native|mcp) die "native/mcp는 오케스트레이터 직접 호출(디스패처 비경유)" 3 ;;
    cli|api) ;;
    *) die "잘못된 call_type: $ctype" 7 ;;
  esac
  bmode="$(jq -r '.brief_mode // "content"' <<<"$spec")"
  tmo="$(jq -r '.timeout // 300' <<<"$spec")"
  cwdp="$(jq -r '.cwd_policy // "repo_root"' <<<"$spec")"

  # 실행 cwd
  case "$cwdp" in
    isolated_tmp) wd="$(mktemp -d)";;
    repo_root)    wd="$ROOT";;
    target)       wd="${TARGET_REPO:-$ROOT}";;
    *)            wd="$ROOT";;
  esac

  # argv 조립 (execve 배열, eval 금지)
  local -a cmd=()
  if [ "$ctype" = "cli" ]; then
    local command_bin
    command_bin="$(jq -r '.cli.command' <<<"$spec")"
    case "$command_bin" in agy|codex|claude) ;; *) die "command allowlist 위반: $command_bin" 7;; esac
    cmd+=("$command_bin")
    local a
    while IFS= read -r a; do
      case "$a" in
        "@brief")         cmd+=("$BRIEF");;
        "@brief_content") cmd+=("$(cat "$BRIEF")");;
        *)                cmd+=("$a");;
      esac
    done < <(jq -r '.cli.args_template[]' <<<"$spec")
  else
    # api: ref 정규화(adapters/ 내부, .. 금지)
    local ref reqenv brief_pass
    ref="$(jq -r '.api.ref' <<<"$spec")"
    case "$ref" in adapters/*) ;; *) die "api.ref는 adapters/ 내부만" 7;; esac
    case "$ref" in *..*) die "api.ref에 '..' 금지" 7;; esac
    [ -f "$ROOT/_shared/$ref" ] || die "api 스크립트 없음: $ref" 4
    while IFS= read -r reqenv; do
      [ -n "$reqenv" ] || continue
      [ -n "${!reqenv:-}" ] || die "필수 env 없음: $reqenv" 4
    done < <(jq -r '.api.required_env[]? // empty' <<<"$spec")
    brief_pass="$(jq -r '.api.brief_pass // "arg1"' <<<"$spec")"
    cmd+=("bash" "$ROOT/_shared/$ref")
    [ "$brief_pass" = "arg1" ] && cmd+=("$BRIEF")
    [ "$brief_pass" = "stdin" ] && bmode="stdin"
  fi

  out="$(mktemp)"; err="$(mktemp)"
  start=$(date +%s)
  set +e
  (
    cd "$wd" || exit 70
    if [ "$bmode" = "stdin" ]; then
      if [ -n "$TIMEOUT_BIN" ]; then "$TIMEOUT_BIN" -k 5 "$tmo" "${cmd[@]}" <"$BRIEF"; else "${cmd[@]}" <"$BRIEF"; fi
    else
      if [ -n "$TIMEOUT_BIN" ]; then "$TIMEOUT_BIN" -k 5 "$tmo" "${cmd[@]}" </dev/null; else "${cmd[@]}" </dev/null; fi
    fi
  ) >"$out" 2>"$err"
  rc=$?
  set -e
  dur=$(( $(date +%s) - start ))

  local status="ok"
  [ "$rc" -ne 0 ] && status="error"
  [ "$rc" -eq 124 ] && status="timeout"

  jq -n --arg status "$status" --argjson exit "$rc" \
        --rawfile stdout "$out" --arg stderr "$(redact <"$err")" \
        --argjson dur "$dur" --arg backend "$ctype" --arg model "$model" \
        '{status:$status, exit_code:$exit, backend:$backend, model:$model,
          duration_s:$dur, stdout:$stdout, stderr_sanitized:$stderr}'
  rm -f "$out" "$err"
  [ "$cwdp" = "isolated_tmp" ] && rm -rf "$wd"
  return "$rc"
}

# primary → 실패 시 fallbacks 순차
env_primary="$(run_backend "$rec")" ; prc=$?
if [ "$prc" -eq 0 ]; then
  jq -n --argjson e "$env_primary" '$e + {fallback_used:false}'
  exit 0
fi
nf="$(jq '.fallbacks | length' <<<"$rec")"
i=0
while [ "$i" -lt "${nf:-0}" ]; do
  fb="$(jq -c --argjson i "$i" '.fallbacks[$i]' <<<"$rec")"
  env_fb="$(run_backend "$fb")" ; frc=$?
  if [ "$frc" -eq 0 ]; then
    jq -n --argjson e "$env_fb" '$e + {fallback_used:true}'
    exit 0
  fi
  i=$((i+1))
done
# 전부 실패 → 마지막 envelope + 비0
jq -n --argjson e "${env_fb:-$env_primary}" '$e + {fallback_used:true}'
exit 1
