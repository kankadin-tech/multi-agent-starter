# Codex MultiAgent Orchestration — Operating Rules

## External/Paid Model Approval

- Do not run external or paid model CLIs, MCPs, or agent bridges without explicit user approval for that specific task.
- This includes, but is not limited to, `claude`, `gemini`, `openai`, `llm`, Claude Code MCP, Gemini MCP, and similar tools.
- A request to translate, summarize, review, research, or process a large file does not imply approval to use external paid models.
- Before using an external paid model, state the exact tool/model, why it is needed, and that it may consume tokens, quota, or money. Wait for explicit approval.
- Local shell commands, file parsing, format validation, current Codex reasoning, and edits inside this workspace are allowed unless the user says otherwise.

## Architecture

```
Orchestrator (Codex session, internal reasoning)
└── Worker Pool (separate worker/model calls — approval required)
    ├── codex-main      bounded implementation · analysis · tests · local verification · image generation
    ├── claude-critic   Codex output review · adversarial critique
    └── gemini          multimodal · long document · third-party perspective
```

**Important**: Codex Orchestrator's internal reasoning is not a worker. A separate `codex-main`, `claude-critic`, or `gemini` call is a worker/model call and must pass the approval gate for the task.

## Task Lifecycle

1. Create `tasks/<task-name>/task.md` (`status: pending`).
2. Read `_shared/routing.md` and choose the minimum worker set.
3. Confirm **target_repo** when the task will produce external files:
   - If `codex-main` is planned, or the task creates code, docs, or images for another repo, ask for `target_repo` before filling `task.md`.
   - If the user says there is no external target, or the task is analysis/review/planning only, keep outputs under `tasks/<task>/artifacts/`.
   - If the user already provided a path, do not ask again.
4. Record explicit worker approvals in `task.md` before any worker call.
5. Write each worker's brief **exactly at `tasks/<task>/workers/<role>/brief.md`** (Korean <= 1200 chars / English <= 240 words). Use a per-worker folder — do NOT flatten to `<role>_brief.md`.
6. Run the approved worker and save the original response **at `tasks/<task>/workers/<role>/result.md`** (same per-worker folder).
7. Execute the `result.md` Verification Checklist.
8. Append verification results to `log.md` with `[VERIFICATION]`. When the task is finished, update `status` in `task.md` to `done`.
9. On completion, append reusable lessons only when they are genuinely reusable:
   - System-level lessons: `_shared/learnings.md`
   - Project-specific lessons: `_local/learnings.md` (not loaded unless explicitly requested)

> When resuming an existing task, start with `_shared/orchestrator-rules.md` section 3 re-entry protocol, not step 1.

## Context Rules

| File | Limit | Purpose |
|------|-------|---------|
| `context.md` | Korean <= 1500 chars / English <= 300 words | Current snapshot only, not history |
| `brief.md` | Korean <= 1200 chars / English <= 240 words | Only what the worker needs |
| `sources/` | Unlimited | Source material, referenced by path |
| `artifacts/` | Unlimited | Raw outputs and generated files |

Measurement:

```bash
wc -m tasks/<task>/context.md
wc -w tasks/<task>/context.md
```

If `context.md` exceeds the limit, append history to `log.md`, then keep only the current snapshot. Never inline long source files into `context.md` or `brief.md`; pass paths.

## Approval Gate

- Never call a worker that is missing from `workers_approved`.
- Worker approval is task-specific and includes purpose and any external write scope.
- Codex Orchestrator internal reasoning does not require approval.
- External paid model tools still require explicit user approval even if the task is already created.

## Verification

Before accepting a worker result, execute the `result.md` Verification Checklist and append the result to `log.md`.

Default checks:
- [ ] output matches `brief.md` `Output Format`
- [ ] referenced paths exist
- [ ] `task.md` constraints are satisfied
- [ ] `Do NOT` items are not violated

## log.md Rules

- Append-only. Do not edit or delete prior log entries.
- Format: `[YYYY-MM-DD HH:MM] [TAG] content`
- Allowed tags: `DECISION | WORKER_CALL | VERIFICATION | ERROR | APPROVAL | COMPLETE`

## Worker File Write Policy

| Worker | Default write permission | External repo write |
|--------|--------------------------|---------------------|
| codex-main | `tasks/<task>/` outputs/diffs | Conditional |
| claude-critic | None; Orchestrator records response | Never |
| gemini | None; Orchestrator records response | Never |

### `write_scope` Values

- `none` — no writes
- `tasks-only` — write only inside `tasks/<task>/`
- `"src/**, tests/**"` style patterns — external repo paths allowed only when all 4 conditions below are met

### codex-main External Repo Write Conditions

All 4 are required:

1. `brief.md` includes `target_repo: <absolute path>`.
2. `brief.md` includes `write_scope: <allowed path pattern>`.
3. `task.md` `workers_approved` includes `codex-main` and the approved `write_scope`.
4. `log.md` has a separate `[APPROVAL]` entry for external write approval.

If any condition is missing, `codex-main` writes only inside `tasks/<task>/`, preferably as a diff or patch for user/orchestrator application.

Workers must never edit `_shared/`, `_templates/`, or another task folder unless the current task is explicitly a system maintenance task.

## AGENTS.md Scope

These rules apply when Codex is working in `<설치한-폴더>` or its subdirectories. Do not copy this orchestration policy into unrelated projects.
