# Changelog

이 파일은 MultiAgent orchestration 시스템의 주요 변경을 기록한다.
형식은 [Keep a Changelog](https://keepachangelog.com/), 버전은 [Semantic Versioning](https://semver.org/lang/ko/)을 따른다.

## [1.0.0] - 2026-06-01

첫 버전 태깅. 기존 실사용 시스템을 1.0.0 기준선으로 고정하고, harness(revfactory) 참고 버전 업그레이드를 함께 반영한다.

### Added
- **작업 재진입 프로토콜** (`_shared/orchestrator-rules.md` §3): 콜드세션이 끝난 작업에 다시 들어갈 때 재정박(re-anchor) → 6분기 판단 → 에러 후 진행. `status↔log 불일치`는 다른 분기보다 먼저 적용하는 정규화 단계로 명시.
- **토폴로지 4패턴표** (`_shared/routing.md`): Pipeline / Fan-out·Fan-in / Expert Pool / Producer-Reviewer + Fan-in 규칙.
- **CLAUDE.md** Task Lifecycle에 재진입 프로토콜 포인터.
- **불변식 INV11** (`_shared/system-invariants.md`): 재진입·토폴로지 규정 자동 자가점검(11a/b/c).
- **design-basis D6**: 4패턴 채택 + Supervisor·Hierarchical Delegation 배제 근거.

### Excluded (설계 결정)
- Supervisor·Hierarchical Delegation 패턴: 단일 orchestrator·worker간 무통신·file-as-memory와 충돌하여 미채택 (근거 D6).

### Baseline (1.0.0 시점 핵심 구조)
- 고정 4-worker pool (claude-main / codex-main / codex-critic / gemini), Claude Code 세션 = orchestrator.
- file-as-memory (런타임 상태 0): task / context / log / brief / result.
- 승인 게이트(`workers_approved`), 외부 쓰기 4조건, progressive disclosure(게이트 로드), 권위 우선순위(CLAUDE.md > routing/approval/orchestrator-rules > 매뉴얼).

### Verification
- 배선(INV11a/b/c) PASS · 회귀 없음, 탁상 분기 커버리지, 실전 콜드세션 3/3 PASS, codex-critic adversarial 리뷰 5 ISSUE 반영.

[1.0.0]: https://github.com/netwaif/multi-agent-starter/releases/tag/v1.0.0
