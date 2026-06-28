#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────
# export_to_vault.sh — 하네스 task 산출물을 LLM Wiki 볼트 inbox로 단방향 전송
#
#   하네스 tasks/<task>/ (result.md + artifacts)  ──►  <vault>/inbox/notes/_misc/
#
# 볼트는 무수정. 닿는 것은 inbox에 떨어지는 capture 파일뿐(= inbox 설계된 용도).
# 분류/분석/연결은 볼트가 독립적으로 /inbox → /ingest → graphify 로 수행.
#
# 사용법:
#   _shared/adapters/export_to_vault.sh <task> [<task2> ...] [옵션]
#   _shared/adapters/export_to_vault.sh --all [옵션]            # (a) 배치
#
# 옵션:
#   --all            tasks/ 아래 task.md 가진 모든 폴더 export
#   --dry-run        쓰지 않고 생성될 내용을 출력
#   --domain <d>     도메인 강제(기본 _misc — 볼트 /inbox가 판정)
#   --vault <path>   볼트 경로 강제
#   --inbox-dir <p>  볼트 내 목적지 하위경로(기본 inbox/notes/_misc). 폴더별 분리용.
#   --media <mode>   (b) 아티팩트 처리: ref(기본)=경로 참조 | copy=볼트로 복사+임베드
#
# 볼트 경로 우선순위:   --vault > $KNOT_VAULT > _shared/vault.config(vault=) > 기본값
# 목적지 우선순위:     --inbox-dir > _shared/vault.config(inbox_dir=) > inbox/notes/_misc
# ──────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# 기본 볼트: $HOME 기반(머신 이식성·하드코딩 사용자명 회피). 폴더별로 _shared/vault.config 에서 변경.
DEFAULT_VAULT="$HOME/vaults/kankadin-wiki"
# 선행 ~ / $HOME 확장(config·플래그 값에 적용; eval 미사용)
expand_tilde() {
  case "$1" in
    "~")    printf '%s' "$HOME" ;;
    "~/"*)  printf '%s/%s' "$HOME" "${1#\~/}" ;;
    '$HOME'/*) printf '%s/%s' "$HOME" "${1#\$HOME/}" ;;
    *)      printf '%s' "$1" ;;
  esac
}

# ── 인자 파싱 ──────────────────────────────────────────────────────────────
TASKS=()
ALL=0; DRY_RUN=0; DOMAIN="_misc"; MEDIA="ref"; VAULT_FLAG=""; INBOX_DIR_FLAG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)       ALL=1; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --domain)    DOMAIN="${2:?--domain 값 필요}"; shift 2 ;;
    --vault)     VAULT_FLAG="${2:?--vault 값 필요}"; shift 2 ;;
    --inbox-dir) INBOX_DIR_FLAG="${2:?--inbox-dir 값 필요}"; shift 2 ;;
    --media)     MEDIA="${2:?--media 값 필요}"; shift 2 ;;
    -*)          echo "알 수 없는 옵션: $1" >&2; exit 2 ;;
    *)           TASKS+=("$1"); shift ;;
  esac
done
case "$MEDIA" in ref|copy) ;; *) echo "--media 는 ref|copy" >&2; exit 2 ;; esac

# ── 볼트 경로 결정 ─────────────────────────────────────────────────────────
VAULT=""
if [[ -n "$VAULT_FLAG" ]]; then VAULT="$VAULT_FLAG"
elif [[ -n "${KNOT_VAULT:-}" ]]; then VAULT="$KNOT_VAULT"
elif [[ -f "$HARNESS_ROOT/_shared/vault.config" ]]; then
  VAULT="$(awk -F= '/^[[:space:]]*vault[[:space:]]*=/{sub(/^[^=]*=/,"");gsub(/^[[:space:]]+|[[:space:]]+$/,"");print;exit}' "$HARNESS_ROOT/_shared/vault.config")"
fi
[[ -n "$VAULT" ]] || VAULT="$DEFAULT_VAULT"
VAULT="$(expand_tilde "$VAULT")"

# inbox 목적지 하위경로(볼트 루트 기준). 폴더별 분리용.
# 우선순위: --inbox-dir > _shared/vault.config(inbox_dir=) > 기본 inbox/notes/_misc
INBOX_REL="$INBOX_DIR_FLAG"
if [[ -z "$INBOX_REL" && -f "$HARNESS_ROOT/_shared/vault.config" ]]; then
  INBOX_REL="$(awk -F= '/^[[:space:]]*inbox_dir[[:space:]]*=/{sub(/^[^=]*=/,"");gsub(/^[[:space:]]+|[[:space:]]+$/,"");print;exit}' "$HARNESS_ROOT/_shared/vault.config")"
fi
[[ -n "$INBOX_REL" ]] || INBOX_REL="inbox/notes/_misc"
# 안전: 볼트 내부 상대경로만(절대·.. 금지 → 볼트 밖 탈출 방지)
case "$INBOX_REL" in
  /*|*..*) echo "✗ inbox_dir 은 볼트 내부 상대경로여야(절대·.. 금지): $INBOX_REL" >&2; exit 2 ;;
esac
NOTES_DIR="$VAULT/$INBOX_REL"
PAPERS_DIR="$VAULT/inbox/papers/_misc"

# ── 대상 task 목록 ─────────────────────────────────────────────────────────
if [[ "$ALL" -eq 1 ]]; then
  while IFS= read -r d; do
    [[ -f "$d/task.md" ]] && TASKS+=("$(basename "$d")")
  done < <(find "$HARNESS_ROOT/tasks" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
fi
[[ ${#TASKS[@]} -gt 0 ]] || { echo "대상 task 없음. <task> 지정 또는 --all 사용." >&2; exit 2; }

# ── 공통 가드(실제 쓰기 시) ────────────────────────────────────────────────
if [[ "$DRY_RUN" -eq 0 ]]; then
  [[ -d "$VAULT" ]]     || { echo "볼트 없음: $VAULT" >&2; exit 1; }
  [[ -d "$NOTES_DIR" ]] || { echo "대상 폴더 없음(볼트 구조 변경?): $NOTES_DIR" >&2; exit 1; }
fi

# slug: 유니코드 보존(로케일 무관). [:alnum:]는 LC_ALL=C에서 한글을 지우므로 쓰지 않는다.
# 공백·슬래시→'-', 제어문자·파일시스템 위험문자(ASCII)만 삭제. 멀티바이트 UTF-8은 보존.
slugify() {
  local s
  s="$(printf '%s' "$1" | tr ' /' '--' | LC_ALL=C tr -d '[:cntrl:]' | LC_ALL=C tr -d '\\:*?"<>|')"
  s="${s#-}"; s="${s%-}"
  [[ -n "$s" ]] && printf '%s' "$s" || printf 'task'
}
lc_ext()  { echo "${1##*.}" | tr '[:upper:]' '[:lower:]'; }

# ── task 1건 export ────────────────────────────────────────────────────────
export_one() {
  local TASK="$1"
  # path traversal 차단: task명에 '/' 나 '..' 금지 (tasks/ 밖 접근 방지)
  case "$TASK" in
    */*|*..*|"") echo "✗ 잘못된 task명(슬래시·.. 금지): '$TASK'" >&2; return 1 ;;
  esac
  local TASK_DIR="$HARNESS_ROOT/tasks/$TASK"
  [[ -d "$TASK_DIR" ]] || { echo "✗ task 폴더 없음: $TASK" >&2; return 1; }

  local TODAY NOW SLUG OUT_NAME DEST GOAL
  TODAY="$(date +%F)"; NOW="$(date +'%Y-%m-%d %H:%M')"
  SLUG="$(slugify "$TASK")"
  # 날짜 제외 안정 파일명 → 재export는 같은 노트를 in-place 갱신(파편화 방지). 날짜는 frontmatter에.
  OUT_NAME="harness_${SLUG}.md"
  DEST="$NOTES_DIR/$OUT_NAME"

  # no-clobber: 하네스 산출물이 아닌 사용자 파일은 절대 덮어쓰지 않음
  if [[ "$DRY_RUN" -eq 0 && -e "$DEST" ]] && ! grep -q '^source: harness$' "$DEST" 2>/dev/null; then
    echo "✗ 거부(사용자 파일 보호 — 하네스 산출물 아님): $DEST" >&2; return 1
  fi

  GOAL=""
  [[ -f "$TASK_DIR/task.md" ]] && \
    GOAL="$(awk '/^## *Goal/{f=1;next} /^## /{f=0} f && NF{print; exit}' "$TASK_DIR/task.md" | sed 's/^[[:space:]]*//')"
  [[ -n "$GOAL" ]] || GOAL="(task.md에 Goal 없음)"

  local RESULTS=() ARTIFACTS=()
  while IFS= read -r l; do [[ -n "$l" ]] && RESULTS+=("$l"); done \
    < <(find "$TASK_DIR/workers" -name result.md 2>/dev/null | sort)
  while IFS= read -r l; do [[ -n "$l" ]] && ARTIFACTS+=("$l"); done \
    < <(find "$TASK_DIR/artifacts" -type f 2>/dev/null | sort)

  # 본문을 임시 변수로 빌드(copy 모드는 부수효과로 볼트에 blob 복사)
  build_body() {
    cat <<EOF
---
title: "harness: ${TASK}"
type: note
date_created: ${TODAY}
domain: ${DOMAIN}
topics: []
tags: [harness, multiagent]
status: unprocessed
source: harness
harness_task: tasks/${TASK}
harness_root: ${HARNESS_ROOT}
exported_at: ${NOW}
related: []
---

> [!NOTE] 멀티에이전트 하네스 산출물
> 자동 export. 볼트에서 \`/inbox\` 트리아지 → \`/ingest\` 로 분류·분석·연결.
> 원본·재현: \`${TASK_DIR}/\`

## Goal

${GOAL}

## Worker Results
EOF
    if [[ ${#RESULTS[@]} -eq 0 ]]; then
      printf '\n(result.md 없음)\n'
    else
      local r role
      for r in "${RESULTS[@]}"; do
        role="$(basename "$(dirname "$r")")"
        printf '\n### %s\n\n<!-- 원본: %s -->\n\n' "$role" "$r"
        cat "$r"; printf '\n'
      done
    fi

    printf '\n## Artifacts\n\n'
    if [[ ${#ARTIFACTS[@]} -eq 0 ]]; then
      printf '(없음)\n'
    else
      local a ext base assetname
      for a in "${ARTIFACTS[@]}"; do
        ext="$(lc_ext "$a")"; base="$(basename "$a")"
        if [[ "$MEDIA" == "copy" ]]; then
          assetname="${TODAY}_harness_${SLUG}__${base}"
          case "$ext" in
            pdf|doc|docx|ppt|pptx|xls|xlsx)
              # 볼트 규약: PDF·오피스 문서는 inbox/papers/ (git-ignored, blob 동기화 별도)
              # 볼트 구조를 만들지 않음(무수정) — papers/_misc 없으면 경로 참조로 폴백.
              if [[ -d "$PAPERS_DIR" ]]; then
                [[ "$DRY_RUN" -eq 0 ]] && cp -p "$a" "$PAPERS_DIR/$assetname"
                printf -- '- 📄 [[%s]]  <!-- ← inbox/papers/_misc/ (원본 %s) -->\n' "$assetname" "$a"
              else
                printf -- '- 📄 `%s`  <!-- papers/_misc 없음 → 경로참조 폴백 -->\n' "$a"
              fi ;;
            png|jpg|jpeg|gif|webp|svg|bmp|tif|tiff)
              # 이미지: 노트와 같은 버킷(notes/_misc)에 두고 Obsidian 임베드
              if [[ "$DRY_RUN" -eq 0 ]]; then cp -p "$a" "$NOTES_DIR/$assetname"; fi
              printf -- '- 🖼 ![[%s]]  <!-- 원본 %s -->\n' "$assetname" "$a" ;;
            *)
              # 텍스트·기타: 복사하지 않고 경로 참조
              printf -- '- `%s`\n' "$a" ;;
          esac
        else
          printf -- '- `%s`\n' "$a"
        fi
      done
    fi

    printf '\n## Connections\n\n- [[ ]]\n'
  }

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "# ── DRY RUN [$TASK] → $DEST (media=$MEDIA) ──" >&2
    build_body
  else
    build_body > "$DEST"
    echo "✅ [$TASK] → $DEST"
  fi
}

FAILED=0
for t in "${TASKS[@]}"; do export_one "$t" || FAILED=$((FAILED+1)); done

if [[ "$DRY_RUN" -eq 0 ]]; then
  echo "   볼트: $VAULT"
  echo "   다음: 볼트에서 \`cd \"$VAULT\" && claude\` → /inbox → /ingest 로 분류·분석·연결"
fi
# 명시·--all 무관하게 실패가 하나라도 있으면 비0 종료(자동화에서 감지 가능)
[[ "$FAILED" -eq 0 ]] || { echo "✗ $FAILED개 task 실패/거부" >&2; exit 1; }
