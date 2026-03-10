---
name: kernel-audit
description: Linux kernel auditing workflow for bootstrap, multi-stage Codex triage, repro, and disclosure generation
---

<Purpose>
Run a practical, repeatable Linux kernel filesystem vulnerability pipeline with Codex as the analysis authority.
</Purpose>

<Policy>
- Core analysis is Codex-only. Do not use external models for root-cause analysis, exploitability reasoning, PoC design, or disclosure writing.
- External sources are allowed only for intake and grounding of known bugs (`syzbot`, public `CVE` data, official OMX release info).
- Prefer team-first orchestration for preflight. Use direct Codex workers for the deep discovery/verify/repro/report stages.
- A candidate is not a vulnerability until the verifier accepts the root cause and QEMU repro yields KASAN evidence.
</Policy>

<Workflow>
1. `bootstrap`: initialize local state, directories, fragments, and campaign metadata.
2. `omx status|refresh|update`: track installed OMX vs upstream, explain new useful OMX features, and update the project-scoped setup.
3. `sync-mainline`: move `linux-up` to current mainline.
4. `cycle`: run the bounded multi-stage audit scheduler.
5. `rootfs prepare`: prebuild BusyBox/Debian rootfs prerequisites.
6. `verify <case>`: re-audit a discovered case with a dedicated verifier worker.
7. `repro <case>`: generate trigger assets if needed, boot QEMU, run PoC, and check KASAN.
8. `report <case>`: generate Markdown report and kernel-security style `.eml` draft.
9. `pre-disclose-check|pre-disclose-batch`: run final duplicate review outside the loop against refreshed knowledge, live syzbot, git history, and local reported cases.
10. `case show|note|promote|backfill`: inspect cases, record operator notes, override `manual_only` with an explicit reason, and normalize legacy case metadata.
11. `status`: summarize campaign, queues, and stage distribution.
</Workflow>

<Stage_Model>
The real pipeline is:
1. preflight
2. discovery
3. verification
4. repro
5. disclosure

Details:
- preflight: refresh/build/status; can run through `omx team`
- discovery: professional kernel-fs Codex worker over `fs/` shards, not just regex hits
- verification: separate Codex worker that validates root cause, reachability, novelty, and trigger contract
- repro: Codex worker synthesizes PoC/run plan, then `kaudit` executes build + rootfs + QEMU + KASAN capture
- disclosure: Codex worker drafts report/email from verified facts and actual logs
</Stage_Model>

<Commands>
- `./.omx/kernel-audit/bin/kaudit bootstrap`
- `./.omx/kernel-audit/bin/kaudit omx status --refresh`
- `./.omx/kernel-audit/bin/kaudit omx update --dry-run`
- `./.omx/kernel-audit/bin/kaudit omx update --force-setup`
- `./.omx/kernel-audit/bin/kaudit sync-mainline`
- `./.omx/kernel-audit/bin/kaudit orchestrate --dispatch auto --target fs`
- `./.omx/kernel-audit/bin/kaudit cycle --once --dispatch auto --target fs`
- `./.omx/kernel-audit/bin/kaudit cycle --loop --dispatch team --target fs`
- `./.omx/kernel-audit/bin/kaudit verify <case-id>`
- `./.omx/kernel-audit/bin/kaudit rootfs prepare --mode auto`
- `./.omx/kernel-audit/bin/kaudit repro <case-id> --rootfs-mode auto`
- `./.omx/kernel-audit/bin/kaudit report <case-id>`
- `./.omx/kernel-audit/bin/kaudit pre-disclose-check <case-id> --refresh`
- `./.omx/kernel-audit/bin/kaudit pre-disclose-batch --stages reported --refresh`
- `./.omx/kernel-audit/bin/kaudit status`
- `./.omx/kernel-audit/bin/kaudit case show <case-id>`
- `./.omx/kernel-audit/bin/kaudit case note <case-id> "operator context"`
- `./.omx/kernel-audit/bin/kaudit case promote <case-id> --to repro_queued`
- `./.omx/kernel-audit/bin/kaudit case backfill`
</Commands>

<Team_Orchestration>
`cycle` and `orchestrate` use team-aware preflight:
- `--dispatch auto`: use `omx team` when healthy, else local fallback
- `--dispatch team`: require tmux/team runtime
- `--dispatch local`: always local preflight

Preflight task mix:
1. refresh knowledge
2. ensure kernel build
3. verify status/build artifacts

Important:
- `omx team` is currently the preflight accelerator, not the entire audit engine
- deep discovery/verify/repro/report workers are run via direct Codex invocations with strict JSON output contracts
- stale team state must be cleaned on interrupt/timeout
- shell prompt injection should stay disabled for shell-driven preflight
</Team_Orchestration>

<Worker_Prompts>
Use the dedicated worker prompts for stage-specific reasoning:
- `.codex/prompts/kernel-fs-discovery-worker.md`
- `.codex/prompts/kernel-fs-verifier-worker.md`
- `.codex/prompts/kernel-fs-repro-worker.md`
- `.codex/prompts/kernel-fs-disclosure-writer.md`

Each worker must emit schema-conformant JSON and must avoid hand-wavy vulnerability claims.
</Worker_Prompts>

<Case_Stages>
Normalized stages:
- `discovered`
- `verified`
- `repro_queued`
- `repro_running`
- `confirmed`
- `reported`
- `manual_only`
- `rejected`
- `repro_failed`

Compatibility note:
- `status` remains for older consumers, but `stage` is authoritative.
- `manual_only` stays out of the automatic repro queue unless an operator explicitly promotes it with `kaudit case promote`.
- Duplicate review is intentionally out-of-band. `report` and the loop keep moving; use `pre-disclose-check` or `pre-disclose-batch` from host WSL before actual submission.

Case-management guidance:
- `case show` is the first operator check for current stage, notes, and promotion blockers.
- `case note` records durable operator context; use it before hand-offs or manual overrides.
- `case promote` is for explicit operator-approved stage transitions only.
- `case backfill` is for importing or normalizing legacy/manual case data into the current store.
- If a case is `manual_only`, do not auto-advance it. Review with `case show`, record the rationale with
  `case note`, then use `case promote` only after operator approval.
</Case_Stages>

<OMX_Lifecycle>
- Run `kaudit omx status --refresh` at the start of a new campaign.
- GitHub releases + npm registry are authoritative for latest OMX version; docs may lag.
- If `update_available` is true:
  - inspect reflected release changes
  - apply `kaudit omx update --dry-run`
  - then `kaudit omx update --force-setup`
- Useful team-facing OMX features exposed through `kaudit`:
  - `--team-reasoning-effort xhigh`
  - `--team-worker-launch-args '...'`
  - `--team-omx-global-args '--notify-temp --slack|--discord|--telegram'`
  - `--team-omx-global-args '--spark'`
  - `--team-scaling`
</OMX_Lifecycle>

<Report_Required_Fields>
Every final report/email draft must include:
- kernel version
- root cause
- KASAN log
- impact
- attack scenario
- required config
- repro steps
</Report_Required_Fields>

<Execution_Notes>
- Treat low-confidence discovery output as triage input, not as a confirmed bug.
- Prefer `xhigh` worker reasoning for kernel-fs analysis.
- If auto repro cannot be self-contained in QEMU, mark the case `manual_only` and record why.
- If a human chooses to override `manual_only`, require an explicit recorded reason via `kaudit case promote <case-id> --to repro_queued --reason ...`.
- If KASAN does not fire, do not mark the case `confirmed`.
</Execution_Notes>
