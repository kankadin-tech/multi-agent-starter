---
name: configure-multiagent
description: Use when the user wants to set up / scaffold / install a file-based multi-agent orchestration system in a folder. Triggers on "멀티 에이전트 시스템 구성해줘", "멀티에이전트 세팅", "멀티 에이전트 시스템 만들어줘", "set up a multi-agent system", "configure multi-agent orchestration here". Scaffolds the system (approval gate, task re-entry protocol, topology patterns, invariant self-check) for Claude Code or Codex via a deterministic generator.
---

# Configure MultiAgent System

이 스킬은 **file-as-memory 멀티에이전트 오케스트레이션 시스템**을 대상 폴더에 생성한다.
**직접 파일을 손으로 쓰지 말 것** — 반드시 번들된 결정적 생성기 `generator/init.py`를 실행한다 (불변식·일관성 보장).

## 절차

1. **flavor 확인** — 사용자에게 묻는다(또는 현재 호스트로 제안):
   - `claude` — Claude Code 오케스트레이터 (워커: claude-main / codex-main / codex-critic / gemini)
   - `codex` — Codex 오케스트레이터 (워커: codex-main / claude-critic / gemini)
2. **대상 폴더 확인** — 어디에 설치할지 묻는다. (상위 폴더 오인 주의 — 정확한 경로를 확인받는다.)
3. **생성기 위치** — 이 플러그인에 함께 설치된 `generator/init.py`:
   - Claude Code: `"$CLAUDE_PLUGIN_ROOT/generator/init.py"`
   - Codex/기타: 이 플러그인 루트의 `generator/init.py` (스킬 기준 `../../generator/init.py`)
4. **실행** — 확인 후:
   ```bash
   python3 "<plugin-root>/generator/init.py" --flavor <claude|codex> --target "<대상폴더>" --yes
   ```
   대화형으로 진행하려면 인자 없이 실행하면 메뉴가 뜬다.
5. **결과 보고** — `init.py`가 끝에 `validate.py`를 자동 실행한다. 그 **PASS/FAIL을 그대로 사용자에게 보고**한다. FAIL이 하나라도 있으면 "완료"라고 말하지 말 것.

## 동작 보장

- **결정적**: 번들 템플릿을 그대로 복사. 모델이 시스템 파일을 창작하지 않는다.
- **안전**: 대상에 기존 `tasks/`·`_local/` 사용자 데이터가 있으면 보존(update 모드).
- **쓰기 권한**: 파일 생성이므로 쓰기 권한이 필요하다. Codex에서는 `workspace-write` + 승인이 필요할 수 있다 — 막히면 사용자에게 권한을 안내한다.

## Do NOT

- 시스템 파일(CLAUDE.md/AGENTS.md, `_shared/*`, `_templates/*`)을 직접 작성·수정하지 말 것. 항상 `init.py`로 생성.
- 플러그인 자신의 폴더나 `generator/templates/` 안에 설치하지 말 것 (init.py가 막지만 시도도 금지).
- validate FAIL을 숨기거나 "대충 됐다"고 보고하지 말 것.
