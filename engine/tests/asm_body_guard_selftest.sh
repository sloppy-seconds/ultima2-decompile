#!/usr/bin/env bash
# asm_body_guard_selftest.sh — prove the body guard can still go red.
#
# The guard was just given an exception path (a `# body corrected:` marker permits a body
# change). AGENTS.md: "A gate that cannot go red is worse than a tool that lies... demonstrate
# a gate failing before you trust it passing." An exception path is exactly where a gate
# silently dies, so all four controls run here:
#
#   1  body changed, NO marker            -> guard MUST fail   (the original guarantee)
#   2  body changed, WITH marker          -> guard MUST pass   (the new permission works)
#   3  marker + a change that alters BYTES-> assemble_clean/check_func MUST fail even though
#      the guard passes                   (the exception cannot smuggle a semantic change)
#   4  body MOVED between files, stream preserved -> guard MUST pass with no marker
#                                          (merges stay legal -- today's three merges)
#
# Runs in a throwaway git worktree so the real checkout is never touched. Skips cleanly if
# git worktree is unavailable.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WT=$(mktemp -d /var/tmp/u2-guard-selftest.XXXXXX)
rmdir "$WT"

pass=0; fail=0
ok()   { echo "  OK      $1"; pass=$((pass+1)); }
no()   { echo "  FAILED  $1"; fail=$((fail+1)); }

if ! git -C "$ROOT" worktree add -q "$WT" HEAD 2>/dev/null; then
    echo "SKIP: git worktree unavailable; controls not run"; exit 0
fi
trap 'git -C "$ROOT" worktree remove --force "$WT" 2>/dev/null; git -C "$ROOT" worktree prune 2>/dev/null' EXIT

cd "$WT" || exit 1
TARGET="asm/0711_speed_delay_lookup.asm"
[ -f "$TARGET" ] || { echo "SKIP: $TARGET not present"; exit 0; }
# Run the guard from the REAL checkout, not the worktree's copy: the worktree is at HEAD,
# so running its own guard would test the old code and report a change that was never made.
# The guard reads HEAD via git and asm/ via cwd, so cwd=worktree + script=ROOT is correct.
GUARD="python3 $ROOT/engine/tests/asm_body_guard.py"

echo "controls on the body guard:"

# ---- 1: unmarked body change must fail -----------------------------------------------
python3 - "$TARGET" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old="        mov    0x580(%bx),%bx"
assert old in s, "control precondition: target line not found"
open(p,'w').write(s.replace(old,"        mov 0x580(%bx),%bx",1))
PY
if $GUARD >/dev/null 2>&1; then no "1  unmarked body change was accepted"; else ok "1  unmarked body change rejected"; fi

# ---- 2: same change, now marked, must pass -------------------------------------------
python3 - "$TARGET" <<'PY'
import sys
p=sys.argv[1]; lines=open(p).read().splitlines(True)
for i,l in enumerate(lines):
    if l.startswith('#'):
        continue
    lines.insert(i, "# body corrected: 2026-10-28 -- evidence: selftest control, whitespace only\n")
    break
open(p,'w').writelines(lines)
PY
if $GUARD >/dev/null 2>&1; then ok "2  marked body change permitted"; else no "2  marked body change was rejected"; fi

# ---- 3: marked, but the change alters BYTES -> the byte proof must catch it ----------
git -C "$WT" checkout -q -- "$TARGET"
python3 - "$TARGET" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old="        mov    0x580(%bx),%bx"
assert old in s
s=s.replace(old,"        add    0x580(%bx),%bx",1)          # different opcode: real byte change
lines=s.splitlines(True)
for i,l in enumerate(lines):
    if l.startswith('#'):
        continue
    lines.insert(i,"# body corrected: 2026-10-28 -- evidence: selftest control, deliberate byte change\n")
    break
open(p,'w').writelines(lines)
PY
if $GUARD >/dev/null 2>&1; then ok "3a marker accepted a byte-changing edit (by design)"; else no "3a guard blocked a marked edit"; fi
if python3 tools/check_func.py 0711 >/dev/null 2>&1; then no "3b check_func accepted altered bytes -- THE EXCEPTION IS A HOLE"; else ok "3b check_func caught the altered bytes"; fi
git -C "$WT" checkout -q -- "$TARGET"

# ---- 4: content moved between files, stream preserved -> legal, no marker ------------
python3 - <<'PY'
import glob, re, os
files=sorted(glob.glob("asm/*.asm"))
def start(p):
    m=re.match(r'.*/([0-9A-Fa-f]{4})_',p); return int(m.group(1),16) if m else -1
for i in range(len(files)-1):
    a,b=files[i],files[i+1]
    if start(b)==start(a)+1:
        body=lambda p:[l for l in open(p).read().splitlines() if not l.lstrip().startswith('#')]
        # append the body lines EXACTLY: a leading blank line here would add a body line,
        # and blank lines count as body (they do not start with '#'), so the canonical
        # stream would gain a line and the control would fail for the wrong reason.
        with open(a,'a') as f:
            f.write("\n".join(body(b))+"\n")
        os.remove(b)
        print(f"  (moved {os.path.basename(b)} body into {os.path.basename(a)})")
        break
PY
if $GUARD >/dev/null 2>&1; then ok "4  merge-shaped change accepted with no marker"; else no "4  guard broke merging -- regression"; fi

echo
echo "caught $pass, MISSED $fail"
[ "$fail" -eq 0 ] && echo "GUARD SELFTEST: PASS" || echo "GUARD SELFTEST: FAIL"
exit $((fail != 0))
