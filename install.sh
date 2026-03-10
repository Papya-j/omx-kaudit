#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OVERLAY_DIR="$SCRIPT_DIR/overlay"
GITIGNORE_FRAGMENT="$SCRIPT_DIR/gitignore.fragment"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh <linux-tree> [--skip-setup] [--force-setup]

Installs the OMX kernel-audit overlay into an existing Linux kernel tree.
EOF
}

die() {
  printf 'install.sh: %s\n' "$*" >&2
  exit 1
}

require_kernel_tree() {
  local target=$1
  [[ -f "$target/Makefile" ]] || die "target is missing Makefile: $target"
  [[ -f "$target/MAINTAINERS" ]] || die "target is missing MAINTAINERS: $target"
  [[ -f "$target/scripts/get_maintainer.pl" ]] || die "target is missing scripts/get_maintainer.pl: $target"
}

append_gitignore_block() {
  local target=$1
  local gitignore="$target/.gitignore"
  touch "$gitignore"
  if grep -Fq '# BEGIN OMX KERNEL AUDIT' "$gitignore"; then
    return 0
  fi
  {
    printf '\n'
    cat "$GITIGNORE_FRAGMENT"
    printf '\n'
  } >>"$gitignore"
}

copy_overlay_tree() {
  local target=$1
  local src_root=$2
  local file rel dest
  while IFS= read -r -d '' file; do
    rel=${file#"$src_root"/}
    dest="$target/$rel"
    mkdir -p "$(dirname "$dest")"
    cp -a "$file" "$dest"
  done < <(find "$src_root" -type f -print0)
}

TARGET_DIR=
SKIP_SETUP=0
FORCE_SETUP=0

while (($#)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --skip-setup)
      SKIP_SETUP=1
      shift
      ;;
    --force-setup)
      FORCE_SETUP=1
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
require_kernel_tree "$TARGET_DIR"

if [[ $SKIP_SETUP -eq 0 ]]; then
  command -v omx >/dev/null 2>&1 || die "omx not found in PATH"
  if [[ $FORCE_SETUP -eq 1 || ! -d "$TARGET_DIR/.omx" || ! -d "$TARGET_DIR/.agents" || ! -d "$TARGET_DIR/.codex" ]]; then
    (cd "$TARGET_DIR" && omx setup --scope project)
  fi
fi

copy_overlay_tree "$TARGET_DIR" "$OVERLAY_DIR"
chmod +x "$TARGET_DIR/.omx/kernel-audit/bin/kaudit"
append_gitignore_block "$TARGET_DIR"

printf 'Installed OMX kernel-audit overlay into %s\n' "$TARGET_DIR"
printf 'Static files updated under .omx/kernel-audit, .agents/skills/kernel-audit, and .codex/prompts.\n'
