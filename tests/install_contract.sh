#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP_DIR=$(mktemp -d)

cleanup() {
  if [[ -n "${TMP_DIR:-}" && "$TMP_DIR" == /tmp/* && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

kernel="$TMP_DIR/linux"
mkdir -p "$kernel/scripts"
touch "$kernel/Makefile" "$kernel/MAINTAINERS" "$kernel/scripts/get_maintainer.pl"

"$ROOT_DIR/install.sh" "$kernel" --skip-setup
test -x "$kernel/.omx/kernel-audit/bin/kaudit"
test -f "$kernel/.agents/skills/kernel-audit/SKILL.md"
test -f "$kernel/.codex/prompts/kernel-fs-discovery-worker.md"
test -f "$kernel/.codex/prompts/kernel-net-discovery-worker.md"
test -f "$kernel/.codex/prompts/kernel-kctf-discovery-worker.md"
"$kernel/.omx/kernel-audit/bin/kaudit" --help >/dev/null

"$ROOT_DIR/install.sh" "$kernel" --skip-setup
gitignore_blocks=$(grep -c '^# BEGIN OMX KERNEL AUDIT$' "$kernel/.gitignore")
[[ "$gitignore_blocks" == "1" ]]

"$ROOT_DIR/uninstall.sh" "$kernel"
test ! -e "$kernel/.agents/skills/kernel-audit/SKILL.md"
test ! -e "$kernel/.codex/prompts/kernel-fs-discovery-worker.md"
test ! -e "$kernel/.omx/kernel-audit/bin"
! grep -q '^# BEGIN OMX KERNEL AUDIT$' "$kernel/.gitignore"

"$ROOT_DIR/install.sh" "$kernel" --skip-setup
mkdir -p "$kernel/.omx/kernel-audit/state"
"$ROOT_DIR/uninstall.sh" "$kernel" --purge-runtime
test ! -e "$kernel/.omx/kernel-audit"
