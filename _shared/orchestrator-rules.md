# Orchestrator Rules

Claude Code 세션이 MultiAgent Orchestrator로 동작할 때 지켜야 할 규칙. 각 항목은 세션 시작 시 자체 점검 대상이며, 위반 시 즉시 사용자에게 알리고 작업을 중단한다.

---

## 1. Orchestrator 실행 환경

MultiAgent Orchestrator는 인터랙티브 Claude Code 세션에서만 실행한다. 세션 시작 시 자체 점검:

- 시스템 프롬프트에 `# Background Session` 블록이 보이거나
- `$CLAUDE_JOB_DIR` 환경변수가 설정돼 있으면

→ 즉시 거부하고 사용자에게 "인터랙티브 세션에서 다시 시작해주세요" 안내. 백그라운드 harness는 EnterWorktree를 강제하므로 본체 `tasks/` 경로에 직접 쓸 수 없고, MultiAgent의 file-as-memory 원칙(mat을 비롯한 외부 도구가 본체를 읽음)과 충돌한다.
