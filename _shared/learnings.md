# Shared Learnings

작업 완료 후 재사용 가능한 교훈만 추가. append-only.  
중복·일회성·작업 특화 내용은 기록하지 말 것.

## 형식

```
## [YYYY-MM-DD] [작업명]
**교훈**: 한 문장. 다음 작업에 그대로 적용 가능한 형태로.
**근거**: 왜 그런지, 어떤 작업에서 발견했는지.
**worker**: [관련 worker명]
```

---

<!-- 이 아래부터 교훈 추가 -->

## [2026-05-13] [mat-mvp]
**교훈**: TUI/대시보드 류 모니터링 도구는 MVP라도 자동 새로고침(폴링)을 기본 포함. fsnotify는 빼더라도 `tea.Tick` 같은 폴링은 spec에서 절대 제외하지 말 것.
**근거**: 초기 DESIGN.md가 "실시간 watch"를 통째로 제외해서 `r` 키 수동 새로고침만 남았는데, 모니터링 도구로서 부자연스러웠다. fsnotify(OS별 차이·임시파일 노이즈)와 폴링은 다른 문제다.
**worker**: claude-main (설계 + 구현)

## [2026-05-13] [mat-mvp]
**교훈**: orchestrator-cwd가 git이 아니면 Task tool sub-agent 호출에서 worktree 격리가 실패할 수 있다. 다른 git repo를 다룰 때는 그 repo로 `cd` 후 claude를 시작하거나, worktree를 요구하지 않는 일반 에이전트로 폴백.
**근거**: claude-test(비-git) cwd에서 `subagent_type: claude` 호출 시 "Cannot create agent worktree" 에러. `general-purpose`로 재시도하니 격리 없이 성공.
**worker**: claude-main 호출 경로

## [2026-05-14] [mat-mvp]
**교훈**: `task.md`는 ` ```yaml ` 블록을 2개 갖는 게 표준 패턴(메타 + Worker Plan)이다. 어떤 키든 첫 yaml fence만 보는 파서는 깨진다 — 문서 전체의 모든 yaml block을 스캔하도록 작성할 것.
**근거**: mat의 `readPlannedWorkers`가 첫 fence 닫는 ``` 에서 return하는 바람에 `planned_workers`(두 번째 블록)를 못 봤다. codex-critic이 MAJOR로 잡고 fix iter로 수정.
**worker**: codex-critic (지적), claude-main (수정)

## [2026-05-14] [mat-mvp]
**교훈**: 같은 worker의 재호출(fix iter)은 별도 폴더 만들지 말고 같은 worker 폴더 안에서 `brief-fix.md` / `result-fix.md` 명명으로 진행. 1차 산출물·승인 기록을 보존하면서 변경 이력이 시각적으로 드러난다.
**근거**: codex-critic 리뷰 후 claude-main에 MAJOR 2건 패치 재호출 시 적용. `workers_approved`는 그대로 두고 brief/result 한 쌍을 추가하는 것만으로 충분했고 깔끔했다.
**worker**: claude-main (fix iter)

## [2026-05-14] [yt-thumbnail-multiagent]
**교훈**: MultiAgent 작업은 worktree 진입 금지. orchestration 산출물(`tasks/<task>/`)은 gitignore라 worktree에 만들어도 본체로 옮기려면 수동 복사 사족이 생긴다. `_shared/learnings.md` 같은 tracked 파일도 단순 append에 worktree+commit+merge는 과한 오버헤드.
**근거**: 배경 세션 harness가 자동으로 EnterWorktree를 강제해 task 폴더와 learnings.md 수정 양쪽에서 `cp -R` 또는 머지 사족이 발생했다. 외부 `target_repo` 쓰기는 codex-main의 cwd로 따로 격리되므로 MultiAgent repo 자체에 워크트리는 불필요. 인터랙티브 세션에서는 EnterWorktree를 자발적으로 호출하지 말 것.
**worker**: orchestrator (세션 초기화 시 EnterWorktree 호출 안 함)

## [2026-05-14] [yt-thumbnail-spring]
**교훈**: log.md는 표준 형식 엄수 — (a) 태그는 정해진 6종(`DECISION | WORKER_CALL | VERIFICATION | ERROR | APPROVAL | COMPLETE`)만 사용, (b) 타임스탬프 `[YYYY-MM-DD HH:MM]`까지 기록, (c) 작업 완료 시 마지막 줄에 `[COMPLETE]` 엔트리 필수.
**근거**: yt-thumbnail-spring log에서 `INIT/BRIEF/CALL/RESULT` 새 태그 사용, HH:MM 누락, [COMPLETE] 부재. mat 같은 도구가 표준 형식 가정하고 파싱하면 일관성 깨짐.
**worker**: orchestrator (로그 작성 규율)

## [2026-05-14] [mat-log-improve]
**교훈**: 한글이 들어갈 가능성이 있는 TUI 텍스트 자르기는 rune 카운트가 아니라 `lipgloss.Width` 같은 시각 폭(cell width) 기반이어야 한다. wide char가 들어가면 rune 카운트 truncate는 실제 폭이 2배가 되어 wrap을 유발하고, 풀스크린 모달에서는 모달 자체가 깨지며 `maxLogScroll=0` 같은 2차 증상까지 연쇄된다.
**근거**: `truncate(s, n int)`이 `len([]rune(s)) <= n` 기준이라 한글 라인이 `inner-2` rune 통과 후 시각 폭은 2*(inner-2)로 wrap → 모달이 height 초과로 잘림. critic 정적 리뷰로는 못 잡고 사용자 인터랙티브 검증에서 발견.
**worker**: claude-main (구현), 사용자 (인터랙티브 검증)

## [2026-05-14] [mat-log-improve]
**교훈**: lipgloss 박스/모달의 chrome 행 수를 셀 때 `"\n\n"` 사이 빈 줄을 빠뜨리기 쉽다 — `"a\n\nb"`는 3행(a, ``, b). 본문 행 수 계산에서 매 separator마다 +1, 박스 사이 separator도 별도 +1로 명시할 것.
**근거**: `logModalBodyHeight chrome = 6`이 실제 7이어야 했고(`title \n\n body \n\n indicator + borders 2`), `renderMain`에서도 logBox→footer 사이 `\n` 1줄을 빠뜨려 큰 터미널에서 화면 +1행. critic이 두 건 다 잡음.
**worker**: codex-critic (지적), claude-main (수정)

## [2026-05-14] [mat-log-improve]
**교훈**: TUI 스크롤 검증용 fixture는 본문이 모달 body의 최소 2~3배 이상이어야 한다. body에 다 들어가는 fixture는 `maxLogScroll=0`이 되어 j/k/g/G가 동작해도 화면 변화 없음 → 키 핸들러 버그와 구분 불가.
**근거**: 1차 stress fixture 36줄로는 사용자 터미널 body에 다 들어가 스크롤이 "안 먹는" 것처럼 보였다(실제로는 max=0이라 정상). 200줄로 늘리니 스크롤·점프 모두 검증 가능.
**worker**: orchestrator (검증 fixture 설계)

## [2026-05-15] [hwpx-math-poc]
**교훈**: PDF 수식을 hwpx에 넣을 때 LaTeX를 거치지 말고 vision 모델이 HML 문법(`{a} over {b}`, `sum _{k=1}^{n}`, `a_k`, `sqrt{x}` 등)으로 바로 출력하게 하라. 텍스트·수식 혼재 본문은 JSON 토큰 배열 `[{"type":"text"|"math","value":"..."}]` 구조로 받으면 후처리 분기가 명확해진다.
**근거**: `hml-equation-parser`는 HML→LaTeX 단방향이라 LaTeX 출력은 수동 매핑 사족을 만든다. gemini-3.1-pro-low에 HML 문법 + JSON 토큰 출력 규칙을 명시했더니 `{a_n}`, `a_6 = 4` 같은 짧은 식까지 math 토큰으로 정확히 분류되어 codex 단계에서 그대로 `hp:equation`에 박을 수 있었다.
**worker**: gemini-pro-low (추출), codex (hwpx 삽입)

## [2026-05-15] [hwpx-math-poc]
**교훈**: 한글 hwpx 수식은 등호/부등호를 포함한 식 전체가 하나의 math 토큰 단위다. `a_6 = 4`를 `a_6` / `= 4`로 split하면 안 됨 — 한글 편집기에서 수식 작업할 때의 일반 규칙. vision 추출 프롬프트에 "등호·부등호는 양쪽 식을 묶어 하나의 math 토큰"을 명시할 것.
**근거**: 1차 추출에서 짧은 식이 plain text로 흘렀고, 등호 기준 split도 후보로 떠올랐지만 실제로는 한 덩어리가 맞았다. 토큰 경계 규칙을 프롬프트에 박은 v2에서 정확히 분류됨.
**worker**: gemini-pro-low (vision 프롬프트 설계)

## [2026-05-15] [hwpx-math-poc]
**교훈**: hwpx에서 별도 줄(객관식 보기 ①②③ 등)은 `hp:lineBreak`이 아니라 `hp:p`(paragraph)로 끊어야 원본과 동일하게 렌더된다. `\n\n` 같은 토큰을 `hp:lineBreak` 두 개로 풀면 한글에서 줄 간격·정렬이 어긋난다.
**근거**: v2에서 `\n\n`을 `hp:lineBreak`로 변환했더니 객관식 보기가 한 단락 안에서 어색하게 줄바꿈만 됨. v3에서 `hp:p`로 분리하니 "원본과 거의 동일" 수준으로 일치.
**worker**: codex (hwpx 생성)

## [2026-05-15] [hwpx-math-poc]
**교훈**: vision 모델이 뽑은 HML 수식은 `hp:equation`에 넣기 전에 canonical HML normalizer를 한 번 통과시켜야 한다. 특히 `x{P(x)}^2`처럼 원본 의미가 "x 곱하기 P(x)의 제곱"인 식을 `xP(x)^2`처럼 괄호 의미가 사라지는 형태로 단순화하면 렌더는 그럴듯해도 원본과 다른 수식이 된다.
**근거**: 한글 수식 편집기에서 `P(x)=3x ^{3+ax ^{2+bx-1}}`, `(x ^{2+ax+b})(x ^{2+2x+a})` 같은 raw HML은 위첨자 결합 범위가 과도하게 잡혔다. 정상 렌더를 위해 `x^{3}+ax^{2}+bx-1`, `(x^{2}+ax+b)(x^{2}+2x+a)`처럼 의미 단위별 canonical HML로 보정해야 했고, 반대로 곱셈 뒤 복합식 제곱은 `{P(x)}^2` 같은 그룹을 유지해야 원본과 일치했다.
**worker**: codex (HML normalizer), 사용자 (한글 수식 편집기 렌더 검증)

## [2026-05-15] [hwpx-math-final]
**교훈**: hwpx-mcp `create_blank`는 hang 위험(>6분 무응답). HWPX 생성은 seed HWPX 복사 + `Contents/section0.xml` zip/XML 직접 조작을 brief에 primary로 명시. PoC에서 이미 검증된 패턴이 있으면 fallback이 아니라 1순위로 못박을 것.
**근거**: 1차 codex MCP 호출에서 `create_blank` function_call이 399초 hang 후 사용자 abort. 한컴 hwpx 패키지 빌드를 hwpx-mcp가 처음 시작할 때 의존성 빌드 또는 lock 대기로 추정. v3 brief에서 hwpx-mcp 호출 금지 + seed 기반 zip/XML 직접 조작 명시로 1회 호출에 성공.
**worker**: codex-main (brief 설계)

## [2026-05-15] [hwpx-math-final]
**교훈**: codex MCP 호출이 비정상적으로 길어질 때(>2-3분) 첫 의심은 외부 MCP 도구 hang이지 모델·reasoning이 아니다. `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`의 event timestamp gap을 보면 어느 function_call에서 막혔는지 즉시 식별 가능.
**근거**: 표면 원인(reasoning=high, brief 길이, AGENTS preamble)으로 잘못 짚었다가 사용자 재질문 후 turn timing 분석으로 진단. 탐색·normalize는 50초, `create_blank` function_call→output 사이가 399초로 명확. session jsonl이 정답지.
**worker**: orchestrator (디버깅 절차)

## [2026-05-15] [hwpx-math-final]
**교훈**: `mcp__codex__codex`의 reject 응답이 codex backend 작업을 중단시키지 않는다. 사용자 거부 후에도 backend는 끝까지 실행되어 파일·부수 효과가 남을 수 있음. 거부한 호출 직후엔 대상 디렉토리 상태를 반드시 확인.
**근거**: reject된 codex MCP 호출 두 건이 backend에서 작업을 계속해 cwd에 `tokens.normalized.json`·`hml-normalize-report.md` 생성. orchestrator는 처음에 그 파일들이 어디서 왔는지 추적 못 함. `~/.codex/sessions/` 세션 jsonl로 확인 가능.
**worker**: orchestrator (MCP reject 의미 이해)

## [2026-05-15] [hwpx-math-final-v2]
**교훈**: vision 단계 프롬프트(한컴 HML 문법 + JSON 토큰 + 등호 단일 토큰 + 그룹 보존)를 충분히 명시하면, 후속 hml-normalizer가 무변경(no-op)으로 통과할 수 있다. normalizer는 안전망일 뿐, 핵심은 vision 추출 품질. 50개 math 토큰 전부 normalizer 패스했고 변경 사항 0.
**근거**: hml-normalize-report.md = "No changes or review flags." gemini-3.1-pro-low가 `x{P(x)}^{2}`, `{P(x)}^{3}-{Q(x)}^{3}`, `P(2)=P(1)=P(-1)=3` 같은 까다로운 케이스를 모두 canonical HML로 직출력. 다른 작업에서도 vision 프롬프트 보강에 비용 투자할 가치가 normalizer 튜닝보다 큼.
**worker**: gemini-pro-low (vision 프롬프트), codex (normalizer는 안전망)

## [2026-05-15] [hwpx-math-final-v2]
**교훈**: codex-critic 없이도 codex-main이 검증·report를 일임하면 충분히 안정적이다. 자동화 가능한 검증(unzip 무결성, XML parse, 노드 수 일치, 본문 1:1 매칭)은 critic 대신 코드로 셀프 체크하고 결과를 report에 기록하면 된다. critic 호출 1건 절약. 단 한글 렌더 시각 검수는 어차피 사람 몫.
**근거**: v1은 critic까지 거쳤지만 v2는 gemini → codex-main 2-worker 파이프라인으로 동일한 수준의 검증 결과 도달(unzip OK, XML parse OK, 50=50 1:1). critic 항목 중 한글 렌더만 사람 검수로 남는 건 v1도 동일했다. 자동화 가능한 검증은 worker 본인이 셀프 보고로 끝낼 수 있다.
**worker**: codex-main (자체 검증), orchestrator (워커 set 단축 판단)

## [2026-05-15] [hwpx-math-final-v2]
**교훈**: codex-main이 산출 파일을 먼저 쓰고 최종 응답 반환이 늦어질 수 있다. 몇 분 지연될 때 즉시 abort하지 말고 target_repo의 산출물(`output-sample.hwpx`, `tokens.normalized.json`, `hml-normalize-report.md` 등)과 task log를 먼저 확인해 "실제 hang"인지 "마무리 응답 대기"인지 분리할 것.
**근거**: v2에서 codex-main 호출 후 몇 분 동안 응답이 없어 hang처럼 보였지만, 중간 확인 시 `output-sample.hwpx`와 normalized token 파일은 이미 생성되어 있었고 unzip/XML/equation count 검증도 통과했다. 기다리니 최종 report까지 작성되어 성공했다. 촬영 중에는 파일 생성 여부가 진행 상태 판단의 핵심 신호다.
**worker**: codex-main (파일 생성), orchestrator (진행 상태 판정)

## [2026-05-15] [hwpx-math-final-v3]
**교훈**: gemini-3.1-pro-low vision이 JSON 토큰 배열을 출력할 때 페이지 후반 토큰이 잘릴 수 있다(이번엔 12번 문제 중간). timeout이 아니라 응답 길이 한계. 잘리면 같은 페이지 전체 이미지로 "X번 문제만 같은 형식으로" 부분 재요청하고 orchestrator에서 `\n\n` 토큰으로 이어붙이면 된다. crop 금지 규칙은 입력 이미지에 대한 것이지, 출력 분할 호출은 위배 아님.
**근거**: 1차 호출에서 05~11 정상 + 12번 "두 정수 a" 토큰까지만 받고 끊김. 12번 단독 재호출(동일 페이지 전체 PNG, 출력 범위만 "12번 본문") 후 join하니 99개 토큰(text 57 / math 42)로 완성. 이후 hml-normalize는 "No changes" — vision 출력이 이미 canonical HML.
**worker**: gemini-pro-low (응답 잘림), orchestrator (분할 재요청 + 토큰 머지)
