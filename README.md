# OMX Kernel Audit Overlay

`omx-kernel-audit-overlay` is a standalone overlay repository for running the `kaudit` Linux kernel subsystem audit workflow on top of an existing Linux kernel tree.
Current built-in target profiles are:

- `fs` (legacy default)
- `net` (additive target namespace; existing fs outputs stay unchanged)

It does **not** ship:
- Linux kernel source
- discovered cases
- QEMU logs
- reports
- rootfs/build outputs
- runtime state

It only ships the static workflow files needed to install the audit pipeline into a kernel checkout.

## What This Repo Installs

The installer copies only these namespaced custom files into the target kernel tree:

- `.omx/kernel-audit/`
- `.agents/skills/kernel-audit/SKILL.md`
- `.codex/prompts/kernel-fs-*.md`
- `.codex/prompts/kernel-net-*.md`

It does not overwrite unrelated OMX, Codex, or user files.

## Prerequisites

### Required

- A Linux kernel git checkout
- `bash`
- `git`
- `node >= 20`
- `oh-my-codex` installed and available as `omx`

### Strongly Recommended

- `tmux`
- `qemu-system-x86_64`
- `busybox`
- `gcc`
- `make`
- `cpio`
- `gzip`
- `jq`
- enough disk space for:
  - `.omx/kernel-audit/build/`
  - `.omx/kernel-audit/rootfs/`
  - `.omx/kernel-audit/artifacts/`

### Optional But Useful

- `mmdebstrap` or `debootstrap` for Debian rootfs mode
- `ripgrep`

## Supported Workflow Shape

This overlay assumes:

- a target kernel tree root containing:
  - `Makefile`
  - `MAINTAINERS`
  - `scripts/get_maintainer.pl`
- a project-scoped OMX install inside that tree
- mainline-style usage where the tree is updated with `kaudit sync-mainline`

## Installation

### 1. Clone a Linux kernel tree

Example:

```bash
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
```

### 2. Clone this overlay repo

```bash
git clone <overlay-repo-url> omx-kernel-audit-overlay
```

### 3. Install the overlay into the kernel tree

```bash
cd omx-kernel-audit-overlay
./install.sh ../linux
```

The installer:

1. verifies the target looks like a Linux kernel tree
2. runs `omx setup --scope project` if needed
3. copies the overlay files
4. appends runtime ignore rules to `.gitignore`

## Updating The Overlay In A Target Tree

One-command update:

```bash
cd omx-kernel-audit-overlay
./update-target.sh ../linux
```

What it does:

1. `git pull --ff-only` in the overlay repo when possible
2. reapplies the overlay into the target kernel tree

If you want to use the current checkout without pulling:

```bash
./update-target.sh ../linux --skip-pull
```

## Updating OMX Itself

Run this inside the target kernel tree:

```bash
cd ../linux
./.omx/kernel-audit/bin/kaudit omx status --refresh
./.omx/kernel-audit/bin/kaudit omx update --force-setup
```

This updates `oh-my-codex`, refreshes project setup, and reruns `omx doctor`.

## Mainline Sync

Run this inside the target kernel tree:

```bash
cd ../linux
./.omx/kernel-audit/bin/kaudit sync-mainline
```

This updates the tree with a fast-forward from `origin/master`.

Recommended after a sync:

```bash
./.omx/kernel-audit/bin/kaudit build init --jobs $(nproc)
```

## Recommended tmux Workflow

`tmux` is strongly recommended for long-running campaigns.

### Start a session

```bash
tmux new -s kaudit
cd ~/path/to/linux
```

### Common tmux commands

- split vertically: `Ctrl+b %`
- split horizontally: `Ctrl+b "`
- detach: `Ctrl+b d`
- reattach: `tmux attach -t kaudit`

### Recommended pane layout

Pane 1: main loop

Pane 2: `status`

Pane 3: `pipeline.json` watcher

Example:

```bash
watch -n 30 './.omx/kernel-audit/bin/kaudit status'
```

```bash
watch -n 30 "jq '.active_jobs, .completed_jobs[-5:]' .omx/kernel-audit/state/pipeline.json"
```

## File Structure

### Overlay repo structure

```text
omx-kernel-audit-overlay/
  README.md
  install.sh
  uninstall.sh
  sync-from-source.sh
  update-target.sh
  gitignore.fragment
  overlay/
    .agents/
    .codex/
    .omx/kernel-audit/
```

### Installed target tree structure

After installation, the target kernel tree contains:

```text
<linux-tree>/
  .agents/skills/kernel-audit/
  .codex/prompts/kernel-fs-*.md
  .omx/kernel-audit/
    bin/kaudit
    config/fragments/
    templates/
    artifacts/
    build/
    knowledge/
    logs/
    reports/
    rootfs/
    state/
```

### Important runtime directories

- `.omx/kernel-audit/artifacts/cases/`
  - case JSON
  - per-case worker outputs
  - per-case PoC assets
- `.omx/kernel-audit/build/`
  - shared `bzImage` build tree
- `.omx/kernel-audit/rootfs/`
  - per-case initramfs/rootfs assets
- `.omx/kernel-audit/reports/`
  - internal report `.md/.eml`
- `.omx/kernel-audit/reports/public/`
  - public mailing drafts and companion artifacts
- `.omx/kernel-audit/state/`
  - campaign and pipeline state

## First-Time Bootstrap

Inside the target kernel tree:

```bash
./.omx/kernel-audit/bin/kaudit bootstrap
./.omx/kernel-audit/bin/kaudit omx status --refresh
./.omx/kernel-audit/bin/kaudit sync-mainline
./.omx/kernel-audit/bin/kaudit rootfs prepare --mode auto
./.omx/kernel-audit/bin/kaudit build init --jobs $(nproc)
```

## Core Usage

## 1. Full discovery loop

This is the standard long-running campaign loop.

```bash
./.omx/kernel-audit/bin/kaudit cycle --loop --dispatch auto --target fs \
  --jobs $(nproc) \
  --team-reasoning-effort xhigh \
  --worker-reasoning-effort xhigh \
  --worker-timeout 900 \
  --audit-workers 3 \
  --verify-workers 2 \
  --repro-workers 1 \
  --report-workers 1 \
  --rootfs-mode busybox \
  --interval 300
```

What each option means:

- `--dispatch auto`
  - try OMX team preflight, fallback to local if needed
- `--target fs`
  - audit `fs/`
- `--team-reasoning-effort xhigh`
  - stronger preflight worker reasoning
- `--worker-reasoning-effort xhigh`
  - stronger discovery/verify/repro/report reasoning
- `--audit-workers 3`
  - discovery shard parallelism
- `--verify-workers 2`
  - verify parallelism
- `--repro-workers 1`
  - repro parallelism
- `--report-workers 1`
  - report batch size
- `--rootfs-mode busybox`
  - use busybox-based initramfs
- `--interval 300`
  - sleep between iterations

## 2. Backlog-only verify

Use this when you want to stop discovering new cases and classify existing `discovered` cases first.

```bash
./.omx/kernel-audit/bin/kaudit cycle --loop --dispatch local --no-preflight \
  --backlog-only --oldest-first --target fs \
  --worker-reasoning-effort xhigh \
  --worker-timeout 900 \
  --verify-workers 2 \
  --no-auto-repro \
  --no-auto-report \
  --interval 60
```

This mode:

- skips discovery
- processes `discovered` oldest-first
- moves cases into:
  - `rejected`
  - `manual_only`
  - `repro_queued`

## 3. Backlog-only repro/report

Use this after verify backlog is already populated.

```bash
./.omx/kernel-audit/bin/kaudit cycle --loop --dispatch local --no-preflight \
  --backlog-only --oldest-first --target fs \
  --worker-reasoning-effort xhigh \
  --worker-timeout 900 \
  --no-auto-verify \
  --repro-workers 1 \
  --report-workers 1 \
  --rootfs-mode busybox \
  --interval 30
```

## 4. Parallel repro

Parallel repro is now supported, but only safely when you skip rebuilds.

**Important:** use `--repro-skip-build` for parallel repro. Shared build-tree rebuilds are not safe in parallel.

### Step 1: merge all needed backlog configs and build once

```bash
./.omx/kernel-audit/bin/kaudit build repro-backlog \
  --stages repro_queued \
  --jobs $(nproc) \
  --oldest-first
```

This command:

- scans selected case stages
- merges all `required_config`
- applies missing config only by default
- rebuilds one shared `bzImage`

### Step 2: run parallel repro using that shared `bzImage`

```bash
./.omx/kernel-audit/bin/kaudit cycle --loop --dispatch local --no-preflight \
  --backlog-only --oldest-first --target fs \
  --worker-reasoning-effort xhigh \
  --worker-timeout 900 \
  --no-auto-verify \
  --repro-workers 2 \
  --report-workers 1 \
  --repro-skip-build \
  --rootfs-mode busybox \
  --interval 30
```

You can increase to `--repro-workers 3`, but start with `2`.

Why:

- each QEMU repro uses memory
- case initramfs/logs are isolated
- build output is shared

### Deferred config handling

If you run with `--repro-skip-build` and a case requires kernel config that is still missing from the current `.config`, it is **deferred**, not marked `repro_failed`.

## 5. Manual stage control

Verify one case:

```bash
./.omx/kernel-audit/bin/kaudit verify <case-id> --worker-reasoning-effort xhigh
```

Run repro for one case:

```bash
./.omx/kernel-audit/bin/kaudit repro <case-id> \
  --rootfs-mode busybox \
  --skip-build \
  --timeout 300 \
  --worker-reasoning-effort xhigh
```

Generate internal report:

```bash
./.omx/kernel-audit/bin/kaudit report <case-id> --worker-reasoning-effort xhigh
```

Generate public mailing artifacts for one case:

```bash
./.omx/kernel-audit/bin/kaudit public-report <case-id>
```

Generate public mailing artifacts for all `reported` cases:

```bash
./.omx/kernel-audit/bin/kaudit public-report-batch --stages reported
```

## 6. Manual_Only

`manual_only` does **not** mean “false positive”.

It means:

- root cause is worth keeping
- but current automatic repro/oracle is not appropriate

Typical reasons:

- external service needed
  - Ceph / NFS / OrangeFS / AFS
- special hardware/platform needed
  - UML / devdax / resctrl / VirtualBox shared folders
- KASAN is the wrong oracle
  - info leak
  - KMSAN-needed bugs
  - functional policy bypass
- special crafted image tooling is required

Inspect a case:

```bash
./.omx/kernel-audit/bin/kaudit case show <case-id>
```

Add operator note:

```bash
./.omx/kernel-audit/bin/kaudit case note <case-id> --message "manual lab required"
```

Promote a case manually:

```bash
./.omx/kernel-audit/bin/kaudit case promote <case-id> \
  --to repro_queued \
  --reason "operator approved manual promotion"
```

## 7. Public mailing flow

Internal report and public mailing are different things.

### Internal report

Generated automatically after confirmed repro:

- `.omx/kernel-audit/reports/<case-id>.md`
- `.omx/kernel-audit/reports/<case-id>.eml`

### Public mailing artifacts

Now generated automatically after report unless disabled with `--no-auto-public-report`.

Generated under:

- `.omx/kernel-audit/reports/public/<case-id>.txt`
- `.omx/kernel-audit/reports/public/<case-id>.eml`
- companion artifacts:
  - `.console.txt`
  - `.kasan-log.txt`
  - `.kernel.config`
  - `.config.txt`
  - `.qemu.txt`
  - `.patch.diff`
  - `.manifest.txt`
  - `.reproducer.c` when publishable

### Duplicate check before disclosure

Run this outside the main loop:

```bash
./.omx/kernel-audit/bin/kaudit pre-disclose-check <case-id> --refresh
./.omx/kernel-audit/bin/kaudit pre-disclose-batch --stages reported --refresh
```

## 8. Mainline update workflow

When you want to move to a newer mainline tree:

```bash
./.omx/kernel-audit/bin/kaudit sync-mainline
./.omx/kernel-audit/bin/kaudit build init --jobs $(nproc)
```

If you are going to run parallel backlog repro after the update:

```bash
./.omx/kernel-audit/bin/kaudit build repro-backlog \
  --stages repro_queued \
  --jobs $(nproc) \
  --oldest-first
```

Then restart the backlog repro loop with `--repro-skip-build`.

## 9. Status / Monitoring

Main status:

```bash
./.omx/kernel-audit/bin/kaudit status
```

Pipeline details:

```bash
jq '.active_jobs, .completed_jobs[-5:]' .omx/kernel-audit/state/pipeline.json
```

## 10. Uninstall

Remove the overlay files but keep runtime state:

```bash
./uninstall.sh ../linux
```

Remove overlay files and runtime state:

```bash
./uninstall.sh ../linux --purge-runtime
```

## Sync This Overlay From A Development Tree

If you maintain this overlay from a working Linux tree:

```bash
./sync-from-source.sh /path/to/linux-tree
```

It refreshes:

- `.omx/kernel-audit/bin/kaudit`
- `.omx/kernel-audit/config/fragments/*`
- `.omx/kernel-audit/templates/*`
- `.omx/kernel-audit/README.md`
- `.agents/skills/kernel-audit/SKILL.md`
- `.codex/prompts/kernel-fs-*.md`

It intentionally excludes runtime outputs and discovered cases.

## Publish

This directory is self-contained and can be pushed as its own repository:

```bash
cd omx-kernel-audit-overlay
git add .
git commit -m "Update kernel audit overlay"
git push
```
