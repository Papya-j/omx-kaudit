# OMX Kernel FS Audit Overlay

This repository is a standalone overlay for the Linux kernel audit workflow built on oh-my-codex.

It does not ship the Linux kernel source tree, discovered cases, QEMU logs, reports, build outputs, or any runtime state. It only ships the static files needed to install the kernel-audit workflow into an existing Linux kernel checkout.

## What It Installs

The installer copies only these namespaced custom files into a target Linux kernel tree:

- `.omx/kernel-audit/`
- `.agents/skills/kernel-audit/SKILL.md`
- `.codex/prompts/kernel-fs-*.md`

It does not overwrite unrelated OMX, Codex, or user files.

## Prerequisites

- Linux kernel source tree clone
- `omx` available in `PATH`
- `bash`

## Install

Clone the Linux kernel tree and this overlay repository, then install the overlay into the kernel tree.

```bash
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
git clone <overlay-repo-url> omx-kernel-audit-overlay

cd omx-kernel-audit-overlay
./install.sh ../linux
```

The installer:

1. Validates the target path looks like a Linux kernel tree
2. Runs `omx setup --scope project` when the target does not already have project-scoped OMX directories
3. Copies the kernel-audit overlay files
4. Appends a guarded `.gitignore` block for runtime artifacts

## First Run

After installation:

```bash
cd ../linux
./.omx/kernel-audit/bin/kaudit bootstrap
./.omx/kernel-audit/bin/kaudit sync-mainline
./.omx/kernel-audit/bin/kaudit cycle --loop --dispatch auto --target fs \
  --jobs $(nproc) \
  --worker-reasoning-effort xhigh \
  --rootfs-mode busybox \
  --interval 300
```

## Update Overlay In A Target Tree

```bash
cd omx-kernel-audit-overlay
git pull
./install.sh ../linux
```

One command update:

```bash
./update-target.sh ../linux
```

This performs `git pull --ff-only` in the overlay repository when possible and then reapplies the overlay into the target tree.

## Uninstall

Remove the overlay files but keep runtime artifacts:

```bash
./uninstall.sh ../linux
```

Remove the overlay files and all runtime state under `.omx/kernel-audit/`:

```bash
./uninstall.sh ../linux --purge-runtime
```

## What Changed In The Current Overlay

This overlay currently tracks the OMX 0.8.11 generation of the workflow.

Notable behavior included in the shipped `kaudit`:

- `kaudit omx update` no longer re-installs stale cached versions when live upstream information is newer
- `kaudit omx status` exposes event-query and monitor-snapshot team API capability flags
- team preflight uses OMX event-query APIs when available for lower-polling waits
- project refresh remains part of the update path through `omx setup --scope project --force`

## Sync This Overlay From A Development Tree

If you maintain the overlay from a working Linux tree that already contains the latest static files:

```bash
./sync-from-source.sh /path/to/linux-tree
```

This refreshes the shipped overlay content from:

- `.omx/kernel-audit/bin/kaudit`
- `.omx/kernel-audit/config/fragments/{base-kasan,fs-broad,repro-stable}.config`
- `.omx/kernel-audit/templates/*`
- `.omx/kernel-audit/README.md`
- `.agents/skills/kernel-audit/SKILL.md`
- `.codex/prompts/kernel-fs-*.md`

It intentionally excludes runtime outputs, per-case config fragments, discovered cases, reports, logs, rootfs contents, and build state.

## Runtime Paths That Stay Out Of Git

The installer appends ignore rules for:

- `.omx/kernel-audit/artifacts/`
- `.omx/kernel-audit/build/`
- `.omx/kernel-audit/knowledge/`
- `.omx/kernel-audit/logs/`
- `.omx/kernel-audit/reports/`
- `.omx/kernel-audit/rootfs/`
- `.omx/kernel-audit/state/`
- `.omx/state/`
- `.omx/plans/`
- `.omx/notepad.md`
- `.omx/project-memory.json`

## Publish As Its Own GitHub Repository

This directory is self-contained. To publish it as a separate repository:

```bash
cd omx-kernel-audit-overlay
git init
git add .
git commit -m "Initial OMX kernel audit overlay"
git remote add origin <your-github-repo-url>
git push -u origin main
```
