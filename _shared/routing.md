# Worker Routing Rules

## Decision Tree

```
작업 성격 파악
│
├── 코드 작성 / 수정 / 테스트 / 이미지 생성?
│   └── codex-main
│
├── claude-main 산출물 검증 / 비판적 리뷰?
│   └── codex-critic
│
├── 이미지 · 스크린샷 분석 / 50페이지+ 문서 / 독립 검토?
│   └── gemini
│
├── 기획 · 설계 · 요구사항 · 전략 · 문서화?
│   └── claude-main
│
└── 판단 어려움?
    └── claude-main으로 시작 후 필요 시 추가
```

## 복합 작업 우선순위

한 작업이 여러 분기에 해당할 때:

1. **선행 의존성 우선**: codex-critic은 claude-main 결과 필요 → 항상 후행
2. **Orchestrator 내부 추론 우선**: 별도 worker 호출 전에 orchestrator 자체 추론으로 해결 가능한지 먼저 판단. 그래도 부족할 때만 claude-main 호출 (claude-main도 비용·쿼터 대상)
3. **검증은 한 번만**: codex-critic은 작업당 1회 원칙. 재호출은 검증 실패 시만
4. **gemini는 명시적 트리거 시만**: 멀티모달 또는 "독립 검토 필요" 명시 없으면 호출 금지

## 병렬 / 순차 정책

| 패턴 | 적용 |
|------|------|
| 순차 (Pipeline) | 기본. claude-main → codex-critic → codex-main 처럼 결과 인계 |
| 병렬 (Parallel) | 서로 독립된 산출물일 때만. 예: codex-main(코드) + gemini(이미지 분석) |
| 금지 | 같은 입력에 같은 종류 worker 동시 호출 (예: codex-main 2개) |

병렬 호출 시: 각 worker `brief.md`에 다른 worker 결과를 참조하지 않음을 명시.

## Worker 역할 상세

### claude-main
- **용도**: 기획, 요구사항 정의, 설계 문서, 사용자 스토리, 아키텍처, 전략 수립
- **결과물**: Markdown 문서, 구조도, 의사결정 근거
- **호출 명령** (예시 — 환경에 맞게 조정):
  ```bash
  claude --print "$(cat tasks/<task>/workers/claude-main/brief.md)" \
    > tasks/<task>/workers/claude-main/result.md
  ```
- **비용**: 있음 (별도 Claude 호출). Claude API/구독 쿼터 차감 → 승인 필요
- **파일 쓰기**: ❌ 직접 X. Orchestrator가 응답을 받아 `result.md`에 기록
- ※ Orchestrator의 내부 추론과 다름.

### codex-main
- **용도**: 코드베이스 분석, 구현, 리팩토링, 테스트 작성, diff 생성, 로컬 CLI 검증, 이미지 생성 (Codex 내장 `image_gen` 도구)
- **결과물**: 코드, diff, 테스트 결과, CLI 출력, PNG/SVG 이미지
- **호출 명령**: `mcp__codex__codex` MCP 도구
  - `prompt`: brief.md 내용 그대로 전달
  - `cwd`: brief.md의 `target_repo` 값 (없으면 `tasks/<task>/`)
  - `sandbox`: `workspace-write` (외부 쓰기 승인 시) / `read-only` (기본)
  - `approval-policy`: `on-failure` 권장
- **brief 필수 필드**:
  ```yaml
  target_repo: /absolute/path/to/repo    # 작업 대상 절대 경로
  write_scope: src/** | tests/** | none  # 쓰기 허용 패턴 또는 'none'
  ```
- **비용**: 있음 (Codex 호출 쿼터) → 승인 필요
- **파일 쓰기**:
  - 기본: `tasks/<task>/` 내부 산출물·diff만 작성
  - `target_repo`/`write_scope` + 사용자 승인 시: 해당 scope 내 직접 쓰기 허용
  - 4가지 조건 (CLAUDE.md "Worker 파일 쓰기 정책" 참조) 충족 필수
- **참고**: `codex` CLI (`codex exec ...`)는 anti-api 프록시(:8964)를 거쳐 Claude/Gemini로 라우팅되므로 진짜 Codex 능력(이미지 생성 등) 안 씀. 반드시 MCP 호출 사용.

### codex-critic
- **용도**: claude-main 산출물을 실제 repo/파일/CLI 관점에서 비평. 실현 가능성, 비용, 테스트 커버리지, 사이드 이펙트 검토
- **선행 조건**: claude-main `result.md` 존재 필수
- **결과물**: 비평 리스트, 수정 제안
- **호출 명령**: codex-main과 동일 (`mcp__codex__codex` MCP). 단 다음 강제:
  - `sandbox`: `read-only` 고정 (쓰기 금지)
  - brief에 "비평 모드" 명시
  - brief의 `target_repo` 명시 (비평 대상 repo 컨텍스트), `write_scope: none`
- **비용**: 있음 → 승인 필요
- **파일 쓰기**: ❌ 직접 X. Orchestrator 경유

### gemini
- **용도**: 이미지/스크린샷/다이어그램 분석, 50페이지+ 문서 스캔, 독립 second opinion
- **결과물**: 분석 텍스트, 요약
- **호출 명령** (예시 — MCP):
  ```
  mcp__gemini__gemini_prompt           # Flash, 일반
  mcp__gemini__gemini_vision           # Flash, 이미지
  mcp__gemini-pro__gemini_pro_prompt   # Pro, 복잡 분석
  mcp__gemini-pro__gemini_pro_vision   # Pro, 정밀 이미지
  ```
- **비용**: Flash 낮음 / Pro 중간-높음 → 승인 필요
- **파일 쓰기**: ❌ MCP 응답을 Orchestrator가 받아 기록

## 최소 Worker Set 원칙

| 작업 유형 | 권장 최소 set |
|----------|------------|
| 문서/기획만 | claude-main |
| 코드 구현 | codex-main |
| 설계 후 구현 | claude-main → codex-main |
| 설계 검증 포함 | claude-main → codex-critic → codex-main |
| 대용량 문서 처리 | gemini |
| 전체 검토 | claude-main → codex-critic |

모든 worker를 기본 호출하지 말 것. 필요한 worker만 선택.

## Worker 추가 조건

- 이미 있는 worker 결과로 해결 가능하면 추가 호출 금지
- 이전 결과가 검증 미통과 시에만 동일 worker 재호출 가능
- gemini는 "독립 검토"가 명시적으로 필요할 때만
