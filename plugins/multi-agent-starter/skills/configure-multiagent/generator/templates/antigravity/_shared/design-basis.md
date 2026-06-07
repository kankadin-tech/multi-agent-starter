# Design Basis — 왜 이 시스템이 이렇게 생겼나

> **로드 정책**: 이 파일은 평소 작업에서 읽지 않는다. 시스템 파일(`AGENTS.md`, `_shared/*`, `_templates/*`)을 수정·검증할 때만 읽는다.

## 0. 출처

- 원본 starter: multi-agent-starter
- Antigravity flavor: multi-agent-starter의 Antigravity(Gemini) orchestrator 파생본
- 사용자 결정: Antigravity(agy/IDE, Gemini 3.1 Pro High)가 메인 오케스트레이터가 되며, 산출물 비평은 자기벤더(gemini) 자기검수가 아니라 교차벤더 독립성 있는 `codex-critic`이 맡는다. 메인 코딩은 `claude-main`.

## 1. 핵심 개념 → 시스템 규칙 매핑

| 개념 | 시스템 규칙 | 주의 |
|------|-------------|------|
| 컨텍스트 = 유한 attention budget | context.md <= 1500자, brief <= 1200자 | 한도 변경 시 불변식 갱신 |
| Progressive disclosure | sources/ 경로 참조, brief 최소화 | 긴 자료 inline 금지 |
| Filesystem = memory | task/context/log/brief/result | 런타임 상태에 의존하지 않음 |
| Append-only + provenance | log.md append-only, 태그 6종 | 로그 삭제·수정 금지 |
| Never trust upstream | worker result 검증 후 채택 | 모든 worker(claude-main/codex-main/codex-critic) 출력 사실검증 |
| Adversarial review | `codex-critic` | Gemini(오케스트레이터) 자기검수로 대체 금지 |
| 최소 worker set | routing.md decision tree | 모든 worker 기본 호출 금지 |
| Fan-in 충돌 해소 | 출처 병기, 사실검증, `[DECISION]` | 다수결 금지 |

## 2. 권위 우선순위

`AGENTS.md` > `_shared/routing.md`·`approval-policy.md`·`orchestrator-rules.md` > `_templates/*`.

충돌 발견 시 낮은 쪽을 높은 쪽에 맞추고, 작업 중인 task의 `log.md`에 `[DECISION]`으로 남긴다.

## 3. 결정 기록

- **D1 write_scope 값 집합** = `none | tasks-only | "패턴"`. `tasks-only`는 `tasks/<task>/` 내부만 쓰는 기본값이다.
- **D2 critic 역할** = Antigravity 버전에서 산출물 리뷰 worker는 `codex-critic`(교차벤더)다. 오케스트레이터가 Gemini라 gemini 자기검수(gemini-critic)는 독립성이 없어 사용하지 않는다.
- **D3 codex-critic 선행조건** = 리뷰 대상 산출물 경로가 존재해야 한다. 대상은 `claude-main`/`codex-main result.md`, Orchestrator 산출물, 기존 코드·문서·소스도 가능하다.
- **D4 gemini 정책** = gemini는 **워커가 아니라 오케스트레이터**(Antigravity agy/IDE, 전역 모델 `gemini-3.1-pro-high`). 멀티모달·긴 문서는 오케스트레이터가 직접 처리하고 **별도 gemini 워커는 두지 않는다**(같은 벤더라 독립성 이득 없음). agy 모델은 전역·계정단위(`/model`)라 gemini 전용 전역을 pro-high로 운용.
- **D5 Orchestrator** = Antigravity(agy/IDE, Gemini 3.1 Pro High) 현재 세션이 단일 Orchestrator다. 별도 long-lived supervisor worker나 worker 재귀 위임 계층은 쓰지 않는다.
- **D6 모델 식별자 표기** = 워커(claude-main/codex-main/codex-critic)는 환경 설정/별칭을 따르고 repo에 버전 문자열을 핀하지 않는다. 오케스트레이터 Gemini는 agy 전역 모델 = `gemini-3.1-pro-high`(전역·계정단위라 per-call 핀 불가).

## 4. 불변식

구체 항목과 점검 명령은 `_shared/system-invariants.md`에 둔다.
