#!/usr/bin/env bash
# Regenerate all Phase-1 validation artefacts after the decompiler runs.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== asm byte-match =="
./tools/verify_asm.sh 2>/dev/null | tail -1
echo "== CP6 stratified sample =="
python3 tools/bytecheck_sample.py
echo "== full-corpus validation =="
python3 tools/bytecheck_full.py
echo "== functions inventory =="
python3 tools/make_functions_tsv.py
