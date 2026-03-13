# Kernel Audit Workflow (OMX + kaudit)

`kaudit` is a Codex-first kernel subsystem audit orchestrator for `linux-up`.
Current built-in target profiles are:

- `fs` (legacy default; existing paths unchanged)
- `net` (new target-specific namespace under `.omx/kernel-audit/`)
It keeps all campaign state under `.omx/kernel-audit/` and runs a bounded multi-stage pipeline:

1. OMX/team-aware preflight (`sync/build/status` prerequisites)
2. Codex discovery workers for target-specific root-cause hunting
3. Codex verifier workers for duplicate/root-cause triage
4. Codex repro planners for PoC, initramfs overlay, QEMU/KASAN execution
5. Codex disclosure writers for Markdown + `.eml` draft generation

The analysis authority is Codex. External sources are intake only.

## Pipeline Summary

### Stage 1: Preflight

`cycle` and `orchestrate` can start with team-aware preflight:

- `--dispatch auto|team|local`
- `auto`: use `omx team` when runtime is healthy, else fallback to local
- team preflight tasks:
  1. refresh knowledge (`syzbot`, `CVE`, OMX upstream metadata)
  2. ensure KASAN-ready baseline build exists
  3. verify build/status artifacts

This stage is short-lived. The team is started, preflight artifacts are produced, and the team is cleaned up.

### Stage 2: Discovery

Discovery is no longer just regex candidate mining.

`kaudit` now:
- shards the selected target path (`fs/` or `net/`) into auditable units
- prioritizes unvisited/older shards
- gathers lightweight static seeds (`copy_from_user`, allocator/free, lifetime hotspots)
- sends each shard to a target-specific Codex discovery worker prompt
- requires structured JSON output with:
  - path
  - function
  - vuln class
  - entry surface
  - attacker control
  - root-cause summary
  - proof outline
  - novelty analysis
  - repro feasibility
  - required config
  - confidence

Only candidates above the discovery confidence floor and below the uniqueness threshold are promoted to cases.

### Stage 3: Verification

Each discovered case is re-audited by a separate **Codex verifier worker**.

The verifier must answer:
- is the root cause technically coherent?
- is this a false positive cleanup/free site?
- is the attacker-controlled path real?
- is it distinct from known syzbot/CVE root causes?
- is there a self-contained trigger contract?

Verifier verdicts:
- `reject`
- `manual_only`
- `repro_ready`

Only `repro_ready` cases automatically move into the repro queue.
`manual_only` is intentionally excluded from the auto repro queue until an operator explicitly promotes it with a recorded reason.

### Stage 4: Repro

For `repro_ready` cases, `kaudit` automatically runs a **Codex repro worker** that produces:
- trigger command or PoC C source
- guest run script
- compile strategy
- required config fragment additions
- rootfs mode recommendation
- rationale for self-contained QEMU reproduction

Then `kaudit` performs:
- config accumulation
- `make -j$(nproc)` rebuild into the same build tree
- initramfs/rootfs preparation (`busybox`, `debian`, or `auto`)
- QEMU boot
- guest trigger execution
- KASAN log detection

A case becomes `confirmed` only when a KASAN signature is observed.

### Stage 5: Disclosure

For confirmed cases, `kaudit report` now produces two artifacts:
- Markdown analysis report: `.omx/kernel-audit/reports/<case-id>.md`
- kernel-security style email draft: `.omx/kernel-audit/reports/<case-id>.eml`

The disclosure worker must supply:
- subject
- recipient placeholders
- concise Markdown summary
- email body text consistent with the verified root cause and the observed KASAN output

## Case Lifecycle

Cases move through these stages:

- `discovered`
- `verified`
- `repro_queued`
- `repro_running`
- `confirmed`
- `reported`
- `manual_only`
- `rejected`
- `repro_failed`

Legacy `status` is retained for compatibility, but `stage` is the real state machine.

Each case stores:
- `analysis`
- `discovery`
- `verification`
- `repro_plan`
- `repro_attempts`
- `disclosure`
- trigger metadata
- similarity/novelty evidence
- generated worker artifacts under `artifacts/cases/<case-id>/workers/`

## Rootfs Modes

`repro` supports:
- `--rootfs-mode busybox`
- `--rootfs-mode debian`
- `--rootfs-mode auto`

`auto` tries Debian first and falls back to BusyBox.

Debian cache prep:

```bash
./.omx/kernel-audit/bin/kaudit rootfs prepare --mode auto
```

## OMX Lifecycle Management

`kaudit` can manage OMX itself:

- `kaudit omx status --refresh`
- `kaudit omx refresh`
- `kaudit omx update --dry-run`
- `kaudit omx update --force-setup`

Upstream sources:
- GitHub releases
- npm registry
- docs summary (treated as laggable, informational)

Snapshot path:
- `.omx/kernel-audit/knowledge/omx-upstream.json`

## Command Reference

Run everything from `~/Linux_kernel/linux-up`.

### Initial Setup

```bash
./.omx/kernel-audit/bin/kaudit bootstrap
./.omx/kernel-audit/bin/kaudit omx status --refresh
./.omx/kernel-audit/bin/kaudit sync-mainline
./.omx/kernel-audit/bin/kaudit rootfs prepare --mode auto
```

### Single-Pass Full Pipeline

```bash
./.omx/kernel-audit/bin/kaudit orchestrate \
  --dispatch auto \
  --target fs \
  --jobs $(nproc) \
  --worker-reasoning-effort xhigh
```

Networking uses the same flow with a different target:

```bash
./.omx/kernel-audit/bin/kaudit orchestrate \
  --dispatch auto \
  --target net \
  --jobs $(nproc) \
  --worker-reasoning-effort xhigh
```

This runs:
- preflight
- one discovery cycle
- auto verify
- auto repro
- auto report

### Continuous Campaign

Inside `tmux`:

```bash
tmux new -s kaudit
cd ~/Linux_kernel/linux-up
./.omx/kernel-audit/bin/kaudit cycle --loop --dispatch team --target fs \
  --jobs $(nproc) \
  --team-reasoning-effort xhigh \
  --worker-reasoning-effort xhigh \
  --audit-workers 3 \
  --verify-workers 2 \
  --repro-workers 1 \
  --report-workers 1 \
  --interval 900
```

For networking:

```bash
./.omx/kernel-audit/bin/kaudit cycle --loop --dispatch team --target net \
  --jobs $(nproc) \
  --team-reasoning-effort xhigh \
  --worker-reasoning-effort xhigh \
  --audit-workers 3 \
  --verify-workers 2 \
  --repro-workers 1 \
  --report-workers 1 \
  --interval 900
```

Behavior:
- preflight uses OMX team if available
- each loop iteration runs discovery
- newly discovered cases are auto-verified
- verified repro-ready cases are auto-reproduced
- confirmed cases are auto-reported

### Manual Stage Control

Verify one case:

```bash
./.omx/kernel-audit/bin/kaudit verify <case-id> \
  --worker-reasoning-effort xhigh
```

Run repro for one case:

```bash
./.omx/kernel-audit/bin/kaudit repro <case-id> \
  --rootfs-mode auto \
  --jobs $(nproc) \
  --timeout 300
```

Generate report/email draft for one case:

```bash
./.omx/kernel-audit/bin/kaudit report <case-id> \
  --worker-reasoning-effort xhigh
```

Generate plain-text public mailing drafts for one case or all `reported` cases:

```bash
./.omx/kernel-audit/bin/kaudit public-report <case-id>
./.omx/kernel-audit/bin/kaudit public-report-batch --stages reported
```

Run the final duplicate check outside the loop, after a case is already `reported`:

```bash
./.omx/kernel-audit/bin/kaudit pre-disclose-check <case-id> --refresh
./.omx/kernel-audit/bin/kaudit pre-disclose-batch --stages reported --refresh
```

Inspect one case:

```bash
./.omx/kernel-audit/bin/kaudit case show <case-id>
./.omx/kernel-audit/bin/kaudit case show <case-id> --json
```

Add an operator note:

```bash
./.omx/kernel-audit/bin/kaudit case note <case-id> \
  --message "Manual review: needs handcrafted image metadata"
```

Promote a `manual_only` case into the repro queue only after operator review:

```bash
./.omx/kernel-audit/bin/kaudit case promote <case-id> \
  --to repro_queued \
  --reason "Operator-approved manual override after source review"
```

Backfill legacy cases that still only carry `status=candidate`:

```bash
./.omx/kernel-audit/bin/kaudit case backfill
```

Operational guidance:
- `manual_only` means the verifier did not trust automatic reproduction for that case.
- Do not blindly auto-promote `manual_only` cases in the main loop.
- If you override a `manual_only` case, use `case promote` so the reason is recorded in `case.json` and `notes.md`.
- `report` is intentionally non-blocking. DNS/live-search problems must not stop `.md`/`.eml` generation or the `reported` stage.
- `public-report` and `public-report-batch` generate plain-text public-list drafts under `.omx/kernel-audit/reports/public/`, plus companion `*.reproducer.c`, `*.console.txt`, `*.kasan-log.txt`, `*.kernel.config`, `*.config.txt`, `*.qemu.txt`, `*.patch.diff`, and `*.manifest.txt` files for public reproduction mail threads.
- Public mailing drafts use `[BUG] <fs>: ...` subjects and `get_maintainer.pl`-derived `To/Cc` recipients. Review the generated `.eml` before sending.
- Final duplicate review is a separate host-side workflow. Run `pre-disclose-check` or `pre-disclose-batch` after reports are generated and before you actually send them.

Check status:

```bash
./.omx/kernel-audit/bin/kaudit status
./.omx/kernel-audit/bin/kaudit status --target net
```

## Important Flags

### Team / Preflight

- `--dispatch auto|team|local`
- `--team-reasoning-effort xhigh`
- `--team-worker-launch-args '...'`
- `--team-omx-global-args '--notify-temp --slack'`
- `--team-scaling`

### Codex Worker Stages

- `--worker-model <model>`
- `--worker-reasoning-effort low|medium|high|xhigh`
- `--worker-timeout <seconds>`
- `--audit-workers <n>`
- `--verify-workers <n>`
- `--repro-workers <n>`
- `--report-workers <n>`
- `--auto-verify | --no-auto-verify`
- `--auto-repro | --no-auto-repro`
- `--auto-report | --no-auto-report`
- `--repro-attempts <n>`

### Final Duplicate Review

- `pre-disclose-check` is a manual, out-of-band command. It is not part of `cycle --loop`.
- It compares a `confirmed` or `reported` case against:
  - refreshed local `syzbot`/`CVE` knowledge
  - live syzbot search results
  - recent linux git history under the relevant `fs/` scope
  - locally confirmed/reported cases
- It writes the latest result into `case.json` and also saves a point-in-time JSON snapshot under the case directory.
- `pre-disclose-batch` is the recommended host WSL command before you actually submit reports. It scans all matching `reported` cases and writes batch snapshots under `.omx/kernel-audit/logs/`.

Recommended host-side flow:

```bash
cd ~/Linux_kernel/linux-up
./.omx/kernel-audit/bin/kaudit pre-disclose-batch --stages reported --refresh
```

Useful variants:

```bash
./.omx/kernel-audit/bin/kaudit pre-disclose-check <case-id> --refresh
./.omx/kernel-audit/bin/kaudit pre-disclose-check <case-id> --no-live-syzbot --no-refresh
./.omx/kernel-audit/bin/kaudit pre-disclose-batch --stages reported,confirmed --refresh --json
```

## Status Interpretation

`kaudit status` now reports both campaign state and pipeline state.

Important fields:
- `last_cycle_at`: last case-discovery activity
- `case_counts`: counts by normalized stage
- `pipeline.iteration`: loop iteration count
- `pipeline.audit_queue`
- `pipeline.verify_queue`
- `pipeline.repro_queue`
- `pipeline.report_queue`
- `pipeline.last_successful_kasan_at`

Meaning:
- `verify_queue > 0`: discovered cases still need deep root-cause verification
- `repro_queue > 0`: verified cases await PoC/QEMU/KASAN execution
- `report_queue > 0`: confirmed cases await disclosure artifacts

## Output Paths

- campaign state: `.omx/kernel-audit/state/campaign.json`
- pipeline state: `.omx/kernel-audit/state/pipeline.json`
- shard state: `.omx/kernel-audit/state/shards.json`
- build state: `.omx/kernel-audit/state/build.json`
- knowledge cache:
  - `.omx/kernel-audit/knowledge/syzbot-fs.json`
  - `.omx/kernel-audit/knowledge/cve-fs.json`
  - `.omx/kernel-audit/knowledge/knowledge-snapshot.json`
  - `.omx/kernel-audit/knowledge/omx-upstream.json`
- per-case artifacts: `.omx/kernel-audit/artifacts/cases/<case-id>/`
- per-case worker artifacts: `.omx/kernel-audit/artifacts/cases/<case-id>/workers/`
- reports: `.omx/kernel-audit/reports/<case-id>.md`
- email drafts: `.omx/kernel-audit/reports/<case-id>.eml`
- rootfs/build outputs: `.omx/kernel-audit/rootfs/`
- logs: `.omx/kernel-audit/logs/`

## Required Report Fields

Every confirmed report must include:
- kernel version
- root cause
- KASAN log
- impact
- attack scenario
- required config
- repro steps

## Operational Notes

- `cycle --loop --dispatch team` must be started inside `tmux`.
- `status`, `verify`, `repro`, and `report` can run inside or outside `tmux`.
- Do not type commands into the same pane that is running the long-lived campaign loop.
- Auto repro is limited to self-contained guest-executable scenarios. Cases requiring external infrastructure can be marked `manual_only`.
- A case is not a confirmed vulnerability until the verifier accepts the root cause and QEMU repro yields a KASAN hit.
