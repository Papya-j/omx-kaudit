#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

usage() {
  cat <<'EOF'
Usage:
  ./update-target.sh <linux-tree> [--skip-pull] [--skip-setup] [--force-setup]

Pull the latest overlay repository state when possible, then reinstall the
overlay into the target Linux kernel tree.
EOF
}

die() {
  printf 'update-target.sh: %s\n' "$*" >&2
  exit 1
}

TARGET_DIR=
SKIP_PULL=0
PASSTHRU=()

while (($#)); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --skip-pull)
      SKIP_PULL=1
      shift
      ;;
    --skip-setup|--force-setup)
      PASSTHRU+=("$1")
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

if [[ $SKIP_PULL -eq 0 ]]; then
  if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$SCRIPT_DIR" remote get-url origin >/dev/null 2>&1; then
      git -C "$SCRIPT_DIR" pull --ff-only
    else
      printf 'update-target.sh: no git remote named origin, skipping pull and using current checkout\n' >&2
    fi
  else
    printf 'update-target.sh: overlay directory is not a git worktree, skipping pull\n' >&2
  fi
fi

"$SCRIPT_DIR/install.sh" "$TARGET_DIR" "${PASSTHRU[@]}"
