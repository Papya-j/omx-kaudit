#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_DIR="$SCRIPT_DIR"
TARGET_OVERLAY="$REPO_DIR/overlay"

usage() {
  cat <<'EOF'
Usage:
  ./sync-from-source.sh <linux-tree>

Refresh the shipped overlay files from a development Linux kernel tree.
EOF
}

die() {
  printf 'sync-from-source.sh: %s\n' "$*" >&2
  exit 1
}

SOURCE_DIR=${1:-}
[[ -n "$SOURCE_DIR" ]] || {
  usage
  exit 1
}

SOURCE_DIR=$(cd -- "$SOURCE_DIR" && pwd)
[[ -f "$SOURCE_DIR/Makefile" ]] || die "source is missing Makefile: $SOURCE_DIR"

rm -rf "$TARGET_OVERLAY/.agents" "$TARGET_OVERLAY/.codex" "$TARGET_OVERLAY/.omx"
mkdir -p "$TARGET_OVERLAY/.agents/skills/kernel-audit" \
         "$TARGET_OVERLAY/.codex/prompts" \
         "$TARGET_OVERLAY/.omx/kernel-audit/bin" \
         "$TARGET_OVERLAY/.omx/kernel-audit/config/fragments" \
         "$TARGET_OVERLAY/.omx/kernel-audit/templates"

cp "$SOURCE_DIR/.agents/skills/kernel-audit/SKILL.md" \
   "$TARGET_OVERLAY/.agents/skills/kernel-audit/SKILL.md"
cp "$SOURCE_DIR/.codex/prompts/kernel-fs-"*.md \
   "$TARGET_OVERLAY/.codex/prompts/"
cp "$SOURCE_DIR/.omx/kernel-audit/bin/kaudit" \
   "$TARGET_OVERLAY/.omx/kernel-audit/bin/kaudit"
cp "$SOURCE_DIR/.omx/kernel-audit/README.md" \
   "$TARGET_OVERLAY/.omx/kernel-audit/README.md"
cp "$SOURCE_DIR/.omx/kernel-audit/templates/"* \
   "$TARGET_OVERLAY/.omx/kernel-audit/templates/"
cp "$SOURCE_DIR/.omx/kernel-audit/config/fragments/base-kasan.config" \
   "$TARGET_OVERLAY/.omx/kernel-audit/config/fragments/"
cp "$SOURCE_DIR/.omx/kernel-audit/config/fragments/fs-broad.config" \
   "$TARGET_OVERLAY/.omx/kernel-audit/config/fragments/"
cp "$SOURCE_DIR/.omx/kernel-audit/config/fragments/repro-stable.config" \
   "$TARGET_OVERLAY/.omx/kernel-audit/config/fragments/"

chmod +x "$TARGET_OVERLAY/.omx/kernel-audit/bin/kaudit"

printf 'Overlay content refreshed from %s\n' "$SOURCE_DIR"
