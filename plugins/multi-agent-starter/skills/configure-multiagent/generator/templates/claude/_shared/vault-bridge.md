# Vault Bridge — 하네스 산출물 → LLM Wiki 볼트 연결

하네스 task 산출물을 기존 LLM Wiki 볼트(knot 계열)에
**기록 → 분류 → 분석 → 연결** 하기 위한 단방향 브리지. (자동 설치됨 — 생성기 번들)

## 철학: 볼트 무수정, inbox만 사용

knot 계열 볼트의 데이터 흐름은 이미 외부 산출물을 받도록 설계돼 있다:

```
inbox → /inbox 트리아지 → raw → /ingest → wiki → graphify
 (기록)      (분류)             (분석·연결)
```

`inbox/`의 본질: *"캡처 마찰 0. 일단 던져 놓는 곳. frontmatter 강제 X."*

따라서 브리지는 **inbox에 capture 파일만 떨군다.** 볼트의 스킬·설정·지침 파일은
일절 건드리지 않는다. 분류/분석/연결은 볼트가 자기 페이스로 독립 수행한다.

| 요구 | 담당 | 수단 |
|---|---|---|
| 기록 | **하네스 브리지** | `export_to_vault.sh` → `inbox/notes/_misc/` |
| 분류 | 볼트 `/inbox` | 도메인 판정 (브리지는 `_misc`로 두고 위임) |
| 분석 | 볼트 `/ingest` | raw → wiki 페이지화 |
| 연결 | 볼트 wiki/graphify | 양방향 링크·그래프 |

## 사용법 (수동 트리거)

task가 `done`이 된 뒤 실행:

```bash
_shared/adapters/export_to_vault.sh <task>                 # 1건
_shared/adapters/export_to_vault.sh <task-a> <task-b>      # 여러 건
_shared/adapters/export_to_vault.sh --all                  # (a) tasks/ 전체 배치
_shared/adapters/export_to_vault.sh <task> --dry-run       # 미리보기(쓰지 않음)
_shared/adapters/export_to_vault.sh <task> --domain ai-computation
_shared/adapters/export_to_vault.sh <task> --media copy    # (b) 이미지·PDF 볼트로 복사
```

그 다음 **볼트에서** (별도 세션): `cd <vault> && claude` → `/inbox` → `/ingest`.

## 볼트 경로·목적지 설정

- **볼트 경로**: `--vault` > `KNOT_VAULT` > `_shared/vault.config`(`vault=`) > 기본값. `~`/`$HOME` 확장.
- **목적지 하위경로**(폴더별 분리): `--inbox-dir` > `_shared/vault.config`(`inbox_dir=`) > `inbox/notes/_misc`.
  - 볼트 `/inbox` 규약상 `inbox/{타입}/{도메인}` 구조 권장. 예: `inbox_dir=inbox/notes/co-work`
    → type=notes, domain=co-work 로 트리아지되어 기존 /inbox·/ingest 그대로 동작.
  - 절대경로·`..` 금지(볼트 밖 탈출 차단).

폴더마다 다른 볼트/목적지를 쓰려면 `_shared/vault.config`만 고치면 된다(update 시 보존됨).

## 떨어지는 파일

- 노트: `<vault>/inbox/notes/_misc/harness_<slug>.md` (날짜는 파일명이 아니라 frontmatter에)
  - 파일명이 안정적이라 **재export는 같은 노트를 in-place 갱신**(중복 파편화 없음).
  - **no-clobber**: 대상이 하네스 산출물이 아니면(=`source: harness` 없음) **거부**(사용자 파일 보호).
  - slug은 유니코드 보존(로케일 무관 — 한글 task명도 안전, `LC_ALL=C`에서도 충돌 없음).
- frontmatter: 볼트 note 규약(`type/date_created/domain/topics/tags/status/related`)
  + provenance(`source: harness`, `harness_task`, `harness_root`, `exported_at`)
- 본문: task Goal + 워커별 `result.md` 전문 + artifacts.
- 명시한 task가 없거나(`../` 등 잘못된 이름 포함) 실패하면 **비0 종료**(자동화에서 감지).

### (b) 아티팩트 미디어 처리 — `--media`

- `ref`(기본): 모든 아티팩트를 **절대경로 참조만**. 볼트로 blob 복사 없음(가장 안전).
- `copy`: 볼트 규약대로 분류 복사 + Obsidian 임베드·링크
  - **이미지**(png/jpg/svg…) → 노트와 같은 `inbox/notes/_misc/`에 복사, `![[..]]` 임베드
    - ⚠️ 이미지는 볼트 `.gitignore`에 보통 미포함 → git 추적될 수 있음. 추적 원치 않으면 기본 `ref` 사용 권장.
  - **PDF·오피스 문서**(pdf/docx/pptx/xlsx) → `inbox/papers/_misc/`에 복사(볼트 PDF 홈; git-ignored), `[[..]]` 링크
    - `papers/_misc`가 없으면 **볼트 폴더를 만들지 않고**(무수정) 경로 참조로 폴백.
  - **텍스트·기타**(md/csv/json…) → 복사하지 않고 경로 참조

## 경계 / 불변식

- **단방향**: 하네스 → 볼트 inbox. 역방향 쓰기 없음.
- **볼트 쓰기 범위**: `inbox/notes/_misc/`(+ `--media copy` 시 `inbox/papers/_misc/`)의 **신규 파일뿐**.
  기존 파일·다른 폴더·볼트 스킬/설정은 손대지 않음.
- **안전 실패**: 볼트/대상 폴더가 없으면 쓰지 않고 에러로 중단.
- **수동**: 자동 트리거 아님. 사용자/오케스트레이터가 명시적으로 호출(지침 Lifecycle 10번).
