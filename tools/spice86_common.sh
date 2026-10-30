#!/usr/bin/env bash
# spice86_common.sh — shared helpers for spice86_start.sh / spice86_stop.sh.
# Sourced, never run directly.
#
# Why this exists: the CFG is not read out of a running emulator by us. Spice86
# writes it out itself, on clean exit, into its recorded-data directory
# (spice86dumpCfgBlocks.json / spice86dumpCfgPartitions.json / ExecutionFlow /
# MemoryDump). A SIGKILL therefore destroys the harvest, which is exactly why
# stopping is a script and not an ad-hoc `kill -9`.
#
# Rules this honours (AGENTS.md + docs/spice86-capture.md):
#   * never run in place: the game rewrites `player`, so every run gets a fresh
#     copy of the pristine references/ultima2/ backup under the project tmp/.
#   * project tmp/ is disk-backed and gitignored; the system /tmp is tmpfs (RAM)
#     and is never used for run dirs or captures.
#   * references/ is read-only: copied from, never written.

SPICE86_COMMON_LOADED=1

# --- paths ---------------------------------------------------------------
# Resolve the project root from this file's location so the scripts work from
# any cwd.
s86_root() {
    local here
    here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || return 1
    dirname -- "$here"
}

s86_tmp_root()   { printf '%s/tmp' "$(s86_root)"; }
s86_refs()       { printf '%s/references/ultima2' "$(s86_root)"; }
# U2V2_SPICE86_DLL overrides which emulator build is launched. Set it to a
# freshly built upstream Spice86.dll to A/B-test a patched build against the
# vendored one without editing anything.
s86_dll()        { printf '%s' "${U2V2_SPICE86_DLL:-$(s86_root)/tools/spice86/Spice86.dll}"; }
s86_capture_dir(){ printf '%s/captures/spice86' "$(s86_root)"; }

# State file for the live session. One at a time on purpose: two emulators
# fighting over the same ports is the failure mode the doc already warns about.
s86_state_file() { printf '%s/.spice86-session.env' "$(s86_tmp_root)"; }

# --- state ---------------------------------------------------------------
s86_state_write() {
    local f
    f=$(s86_state_file)
    mkdir -p "$(dirname "$f")"
    {
        printf 'S86_PID=%s\n'      "$1"
        printf 'S86_PGID=%s\n'     "$2"
        printf 'S86_RUN_DIR=%s\n'  "$3"
        printf 'S86_DUMP_DIR=%s\n' "$4"
        printf 'S86_LABEL=%s\n'    "$5"
        printf 'S86_HTTP_PORT=%s\n' "$6"
        printf 'S86_MCP_PORT=%s\n'  "$7"
        printf 'S86_GDB_PORT=%s\n'  "$8"
        printf 'S86_STARTED=%s\n'  "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$f"
}

s86_state_read() {
    local f
    f=$(s86_state_file)
    [ -f "$f" ] || return 1
    # shellcheck disable=SC1090
    . "$f"
    return 0
}

s86_state_clear() { rm -f "$(s86_state_file)"; }

# --- ports ---------------------------------------------------------------
s86_port_free() {
    local p=$1
    ! (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null
}

s86_pick_port() {
    # s86_pick_port START [EXCLUDE ...]
    #
    # Returns the first free port at or above START, skipping any port listed in EXCLUDE.
    # The exclusions are the whole point and they exist because of a real failure: the
    # three API ports used to be allocated independently, so when a stale emulator was
    # squatting 20180/20181 the HTTP and MCP pickers BOTH walked up to 20182 and were
    # handed the same port. Spice86 then bound one API and the other silently did not
    # exist, and every tool that talked to that endpoint was talking to the stale emulator
    # instead — it returned a confident, plausible, completely wrong character and sector.
    # A caller that asks for three ports must get three different ones.
    local start=$1 p i
    shift
    local -a exclude=("$@")
    for ((i = 0; i < 400; i++)); do
        p=$((start + i))
        local skip=0 e
        for e in "${exclude[@]}"; do
            [ "$p" = "$e" ] && { skip=1; break; }
        done
        [ "$skip" = 1 ] && continue
        if s86_port_free "$p"; then printf '%s\n' "$p"; return 0; fi
    done
    echo "no free port at or above $start" >&2
    return 1
}

# --- display -------------------------------------------------------------
# A shell not started from the desktop session does not inherit the display
# environment. Wayland first; XWayland as the fallback.
s86_export_display() {
    export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    if [ -S "$XDG_RUNTIME_DIR/wayland-0" ]; then
        export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
    fi
    if [ -z "${DISPLAY:-}" ] && [ -S /tmp/.X11-unix/X0 ]; then
        export DISPLAY=:0
    fi
    if [ -z "${XAUTHORITY:-}" ]; then
        local xa
        xa=$(ls "$XDG_RUNTIME_DIR"/xauth_* 2>/dev/null | head -1) || true
        [ -n "$xa" ] && export XAUTHORITY="$xa"
    fi
    export DOTNET_ROLL_FORWARD=Major
}

# --- readiness -----------------------------------------------------------
s86_wait_api() {
    local port=$1 deadline=$((SECONDS + ${2:-60}))
    while [ $SECONDS -lt $deadline ]; do
        if curl -fsS --max-time 2 "http://127.0.0.1:${port}/api/status" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.5
    done
    return 1
}

# --- live dump (optional, needs gdb) ------------------------------------
# `monitor dumpAll` makes Spice86 write the CFG dump WITHOUT stopping the run,
# so a harvest can happen while the game is still on screen. The command name
# is camelCase: `monitor help` lists it as dumpAll, and a lowercase `dumpall`
# is silently ignored (measured 2026-10-21), which looks like a successful
# gdb call that produces no files.
s86_dumpall_live() {
    local gdb_port=$1
    command -v gdb >/dev/null 2>&1 || return 1
    gdb -batch -q \
        -ex "target remote 127.0.0.1:${gdb_port}" \
        -ex "monitor dumpAll" 2>&1 | tail -3
    return 0
}

# --- harvest -------------------------------------------------------------
# Copy whatever Spice86 dumped into the capture dir and print counts. Globs
# rather than fixed names so a prefix change upstream cannot silently produce
# an empty harvest, and searches recursively because Spice86 puts the dump in a
# subdirectory named after the SHA-256 of the emulated program unless -r pins
# the location exactly.
s86_harvest() {
    local dump_dir=$1 label=$2
    local dest
    dest="$(s86_capture_dir)/${label}"
    mkdir -p "$dest" || return 1

    local -a patterns=( -name '*Cfg*.json' -o -name '*ExecutionFlow*.json'
                        -o -name '*MemoryDump*.bin' -o -name '*Reload*.json'
                        -o -name '*CpuRegisters*.json' )

    # One find, copy in place, then count what actually landed. Counting the
    # destination rather than the source means an empty harvest can never be
    # reported as a success.
    find "$dump_dir" -type f \( "${patterns[@]}" \) \
         -exec cp -p {} "$dest"/ \; 2>/dev/null || true

    local n
    n=$(find "$dest" -type f 2>/dev/null | wc -l)
    if [ "${n:-0}" -eq 0 ]; then
        echo "  no dump files under $dump_dir" >&2
        echo "  (Spice86 writes the CFG on clean exit; a SIGKILL produces none)" >&2
        return 1
    fi
    printf '%s\n' "$dest"
}

# Summarise a harvest so the operator sees evidence, not just filenames.
s86_harvest_summary() {
    local dest=$1
    python3 - "$dest" <<'PY'
import glob, json, os, sys
d = sys.argv[1]
def load(pat):
    hits = sorted(glob.glob(os.path.join(d, pat)))
    if not hits:
        return None, None
    p = hits[0]
    try:
        with open(p) as fh:
            return p, json.load(fh)
    except Exception as e:            # noqa: BLE001
        return p, None
for pat, label in (("*CfgBlocks*.json", "CFG blocks"),
                   ("*CfgPartitions*.json", "CFG partitions"),
                   ("*ExecutionFlow*.json", "execution flow")):
    path, data = load(pat)
    if path is None:
        print(f"  {label:<18} absent")
        continue
    # CfgBlocks is a dict (currentContextEntryPoint, entryPointAddresses,
    # blocks, partitions, transfers ...); CfgPartitions is {partitions,
    # transfers}. Count the list that carries the records rather than the
    # top-level key count, which would report "5" for a 800-block graph.
    if isinstance(data, dict):
        for key in ("blocks", "partitions", "functions", "labels", "instructions"):
            if isinstance(data.get(key), list):
                print(f"  {label:<18} {len(data[key]):>6} {key}"
                      f"   {os.path.basename(path)}")
                break
        else:
            if "entryPointAddresses" in data:
                print(f"  {label:<18} {len(data['entryPointAddresses']):>6} entry points"
                      f"   {os.path.basename(path)}")
            else:
                print(f"  {label:<18} dict keys={list(data)[:4]}"
                      f"   {os.path.basename(path)}")
    elif isinstance(data, list):
        print(f"  {label:<18} {len(data):>6} records   {os.path.basename(path)}")
    else:
        print(f"  {label:<18} unparseable   {os.path.basename(path)}")
for pat, label in (("*MemoryDump*.bin", "memory dump"),):
    hits = glob.glob(os.path.join(d, pat))
    if hits:
        print(f"  {label:<18} {os.path.getsize(hits[0]):>6} B     {os.path.basename(hits[0])}")
PY
}

# Snapshot the live data segment over the read-only HTTP API.
# DS is not reported by the API; 0x08BE is the value proven in
# docs/spice86-capture.md for this game once the main body is running.
s86_snapshot_ds() {
    local port=$1 dest=$2 ds_seg=${3:-0x08BE} len=${4:-65536}
    local phys
    phys=$(( ds_seg * 16 ))
    curl -fsS --max-time 20 "http://127.0.0.1:${port}/api/memory/${phys}/range/${len}" \
      | python3 -c "import json,sys;d=json.load(sys.stdin);sys.stdout.buffer.write(bytes(d['values']))" \
      > "$dest" 2>/dev/null || return 1
    [ -s "$dest" ]
}
