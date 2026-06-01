#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

bash -n install.sh sync-from-source.sh update-target.sh uninstall.sh scripts/validate-overlay.sh
bash -n tests/install_contract.sh
python3 -m py_compile overlay/.omx/kernel-audit/bin/kaudit
python3 -m unittest discover -s tests
tests/install_contract.sh
overlay/.omx/kernel-audit/bin/kaudit --help >/dev/null
overlay/.omx/kernel-audit/bin/kaudit repro-cycle --help >/dev/null

printf 'overlay validation passed\n'
