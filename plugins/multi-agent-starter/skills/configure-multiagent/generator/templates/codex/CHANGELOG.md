# Changelog

이 파일은 multi-agent-starter (Codex flavor) orchestration 시스템의 주요 변경을 기록한다.

## [0.1.0] - 2026-06-01

multi-agent-starter를 기반으로 Codex Orchestrator 버전을 생성했다.

### Added

- `AGENTS.md`: Codex 세션용 운영 규칙 정본.
- `_shared/routing.md`: `codex-main`, `claude-critic`, `gemini` 기준 worker routing.
- `_shared/approval-policy.md`: worker 승인과 외부/유료 모델 승인 게이트.
- `_shared/orchestrator-rules.md`: Codex 세션 환경 점검, 시스템 수정·검증, 작업 재진입 프로토콜.
- `_shared/design-basis.md`: Codex fork의 결정 기록.
- `_shared/system-invariants.md`: Codex 버전 자가 점검 스크립트.
- `_templates/*`: Codex worker pool 기준 task/context/log/brief/result/task-folder 템플릿.

### Changed

- Orchestrator를 Claude Code 세션에서 Codex 세션으로 변경.
- 리뷰 worker를 Codex 자기검수 구조에서 `claude-critic` 독립 검수 구조로 변경.

### Excluded

- 원본 `.claude/agents/`
- 원본 `_local/learnings.md`
- 원본의 기존 작업 이력 산출물
