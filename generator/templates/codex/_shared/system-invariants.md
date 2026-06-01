# System Invariants — 시스템 수정 후 자가 점검

> **로드 정책**: 평소 미로드. 시스템 파일 수정·검증 작업일 때만 사용한다.

## 불변식 목록

| ID | 불변식 |
|----|--------|
| INV1 | `write_scope` 값 집합이 `AGENTS.md`, `routing.md`, `worker-brief.md`, `task-folder.md`에서 동일 |
| INV2 | `codex-critic`이 실행 규칙·템플릿의 활성 worker로 남아 있지 않음 |
| INV3 | `claude-critic` 선행조건이 특정 worker 결과에만 묶이지 않고 일반화되어 있음 |
| INV4 | log 태그가 정확히 `DECISION | WORKER_CALL | VERIFICATION | ERROR | APPROVAL | COMPLETE` 6종 |
| INV5 | context 한도 1500자, brief 한도 1200자가 정본 문서와 템플릿에서 일치 |
| INV6 | 권위 우선순위가 `AGENTS.md` 기준으로 기록됨 |
| INV7 | 재진입 프로토콜이 `orchestrator-rules.md`와 `AGENTS.md` 포인터에 모두 존재 |
| INV8 | 토폴로지 4패턴(Pipeline, Fan-out/Fan-in, Expert Pool, Producer-Reviewer)이 routing에 존재 |
| INV9 | Gemini 기본 모델은 `gemini-3.1-pro-low`, `pro-high`는 기본·폴백 경로가 아님 |

## 자가 점검 스크립트

`~/VSCodeWorkspace/CodexMultiAgent`에서 실행한다.

```bash
ROOT=~/VSCodeWorkspace/CodexMultiAgent

echo "INV1 tasks-only 분포"
grep -l 'tasks-only' "$ROOT/AGENTS.md" "$ROOT/_shared/routing.md" \
  "$ROOT/_templates/worker-brief.md" "$ROOT/_templates/task-folder.md"

echo "INV2 codex-critic 활성 참조 (출력 없어야 PASS)"
grep -rn 'codex-critic' "$ROOT/AGENTS.md" "$ROOT/README.md" \
  "$ROOT/_shared/routing.md" "$ROOT/_shared/approval-policy.md" \
  "$ROOT/_shared/orchestrator-rules.md" "$ROOT/_templates"

echo "INV3 claude-critic 존재"
grep -rn 'claude-critic' "$ROOT/AGENTS.md" "$ROOT/_shared/routing.md" "$ROOT/_templates"

echo "INV4 log 태그"
grep -n 'DECISION | WORKER_CALL | VERIFICATION | ERROR | APPROVAL | COMPLETE' "$ROOT/_templates/log.md" "$ROOT/AGENTS.md"

echo "INV5 한도 수치"
grep -rn '1500자\|1200자\|1500 chars\|1200 chars' "$ROOT/AGENTS.md" "$ROOT/_templates/context.md" "$ROOT/_templates/worker-brief.md"

echo "INV6 권위 우선순위"
grep -rn 'AGENTS.md.*routing.md' "$ROOT/_shared/design-basis.md" "$ROOT/_shared/orchestrator-rules.md"

echo "INV7 재진입"
grep -q '재진입 프로토콜' "$ROOT/_shared/orchestrator-rules.md" && echo " orchestrator-rules PASS" || echo " orchestrator-rules FAIL"
grep -q 're-entry protocol\|재진입 프로토콜' "$ROOT/AGENTS.md" && echo " AGENTS.md PASS" || echo " AGENTS.md FAIL"

echo "INV8 토폴로지 4패턴"
for p in 'Pipeline' 'Fan-out/Fan-in' 'Expert Pool' 'Producer-Reviewer'; do
  grep -q "$p" "$ROOT/_shared/routing.md" && echo " $p PASS" || echo " $p FAIL"
done

echo "INV9 gemini 모델"
grep -n 'gemini-3.1-pro-low' "$ROOT/_shared/routing.md" "$ROOT/_shared/design-basis.md"
grep -n 'pro-high' "$ROOT/_shared/routing.md" "$ROOT/_shared/design-basis.md"
```

## 전면 재감사가 필요한 경우

- 새 외부 개념·레퍼런스를 시스템에 도입할 때
- worker pool 구성·역할이 바뀔 때
- 위 불변식으로 표현 불가한 구조 변경이 생길 때
