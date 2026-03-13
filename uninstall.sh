#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./uninstall.sh <linux-tree> [--purge-runtime]

Removes the installed OMX kernel-audit overlay from a Linux kernel tree.
EOF
}

die() {
  printf 'uninstall.sh: %s\n' "$*" >&2
  exit 1
}

remove_gitignore_block() {
  local target=$1
  local gitignore="$target/.gitignore"
  [[ -f "$gitignore" ]] || return 0
  local tmp
  tmp=$(mktemp)
  awk '
    /^# BEGIN OMX KERNEL AUDIT$/ { skip=1; next }
    /^# END OMX KERNEL AUDIT$/ { skip=0; next }
    skip != 1 { print }
  ' "$gitignore" >"$tmp"
  mv "$tmp" "$gitignore"
}

TARGET_DIR=
PURGE_RUNTIME=0

while (($#)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --purge-runtime)
      PURGE_RUNTIME=1
      shift
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      if [[ -n "${TARGET_DIR:-}" ]]; then
        die "target already provided: $TARGET_DIR"
      fi
      TARGET_DIR=$1
      shift
      ;;
  esac
done

[[ -n "${TARGET_DIR:-}" ]] || {
  usage
  exit 1
}

TARGET_DIR=$(cd -- "$TARGET_DIR" && pwd)

rm -f "$TARGET_DIR/.agents/skills/kernel-audit/SKILL.md"
for prompt in \
  kernel-fs-auditor.md \
  kernel-fs-disclosure-writer.md \
  kernel-fs-discovery-worker.md \
  kernel-fs-repro-worker.md \
  kernel-fs-verifier-worker.md \
  kernel-net-disclosure-writer.md \
  kernel-net-discovery-worker.md \
  kernel-net-repro-worker.md \
  kernel-net-verifier-worker.md \
  kernel-kctf-disclosure-writer.md \
  kernel-kctf-discovery-worker.md \
  kernel-kctf-repro-worker.md \
  kernel-kctf-verifier-worker.md; do
  rm -f "$TARGET_DIR/.codex/prompts/$prompt"
done
rm -f "$TARGET_DIR/.omx/kernel-audit/README.md"
rm -rf "$TARGET_DIR/.omx/kernel-audit/bin"
rm -rf "$TARGET_DIR/.omx/kernel-audit/config"
rm -rf "$TARGET_DIR/.omx/kernel-audit/templates"

if [[ $PURGE_RUNTIME -eq 1 ]]; then
  rm -rf "$TARGET_DIR/.omx/kernel-audit"
fi

remove_gitignore_block "$TARGET_DIR"

printf 'Removed OMX kernel-audit overlay from %s\n' "$TARGET_DIR"
if [[ $PURGE_RUNTIME -eq 1 ]]; then
  printf 'Runtime state under .omx/kernel-audit was also removed.\n'
else
  printf 'Runtime state under .omx/kernel-audit was preserved.\n'
fi
