#!/usr/bin/env bash
# ci_base.sh — print the ref the body guard should compare against, or fail.
#
# The guard compares a working tree to a ref. On a clean CI checkout HEAD *is* the tree, so
# a guard run without a base compares a commit to itself and can only ever report
# "conserved". That is how asm_body_guard spent its whole life green in CI while being
# incapable of failing. This script exists so no workflow can quietly fall back to that.
#
# Order of preference:
#   1. ASM_GUARD_BASE, if the caller already knows (a rebase, a targeted audit)
#   2. a pull_request's base sha
#   3. a push's before-sha (what the push replaced)
#   4. HEAD~1, so a single-commit run still checks something real
# Exits 2 with a clear message if none of them resolves to a commit, because a gate that
# cannot run must be red, not green.
set -uo pipefail

emit() { echo "$1"; exit 0; }

if [ -n "${ASM_GUARD_BASE:-}" ] && git cat-file -e "${ASM_GUARD_BASE}^{commit}" 2>/dev/null; then
    emit "$ASM_GUARD_BASE"
fi

for cand in "${GITHUB_PR_BASE:-}" "${GITHUB_PUSH_BEFORE:-}"; do
    if [ -n "$cand" ] && [ "$cand" != "0000000000000000000000000000000000000000" ] \
       && git cat-file -e "${cand}^{commit}" 2>/dev/null; then
        emit "$cand"
    fi
done

if git cat-file -e 'HEAD~1^{commit}' 2>/dev/null; then
    emit "$(git rev-parse HEAD~1)"
fi

echo "ci_base: no usable base ref (no ASM_GUARD_BASE, no PR/push base, no HEAD~1)." >&2
echo "ci_base: the history is probably too shallow -- checkout needs fetch-depth: 0." >&2
exit 2
