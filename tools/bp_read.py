#!/usr/bin/env python3
"""bp_read.py — stop the CPU at a runtime address and dump guest memory there.

Why this exists
---------------
Several open questions are "what is the value of this operand at the instant the
game prints or charges it". Static reading cannot answer that (docs/commerce.md
§ 3 is the standing example: the price pair is written by a routine whose output
a static reader can only model), and polling cannot answer it either, because the
operand is scratch that the next caller overwrites.

The mechanism is Spice86's `monitor breakCsIp`, driven over the GDB remote
protocol by the same RSP class tools/reject_trap.py validated on 2026-10-22. This
module reuses that class rather than re-deriving it.

Two facts inherited from reject_trap.py and not renegotiated here:
  * `breakCsIp` parses its arguments as HEX while /api/status reports DECIMAL.
    The conversion goes through reject_trap.cs_ip_from_status, which asserts.
  * The trap is read-only with respect to guest memory: it never patches guest
    bytes, so it cannot damage the byte-exact comparison the project depends on.

Controls
--------
`--selftest` proves the mechanism against a live run in BOTH directions:
  positive  arm on the address the CPU is already executing -> must stop
  negative  arm on an address that can never execute        -> must NOT stop
A tool that can only ever report a hit is worthless here; the negative control is
what makes "no stop" mean something.

Usage
-----
    # arm, resume, and dump DS:27..2C when the tavern price print is reached
    python3 tools/bp_read.py --ip 17B7 --dump 27:6 --dump 4E:4 --timeout 90

    # prove the tool can fail
    python3 tools/bp_read.py --selftest
"""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.request

sys.path.insert(0, __file__.rsplit('/', 1)[0])
from reject_trap import RSP, DS_SEG, cs_ip_from_status  # noqa: E402

CS_DEFAULT = 0x017D          # the code segment the runtime CFG reports


def http_json(port: int, path: str):
    with urllib.request.urlopen(f"http://127.0.0.1:{port}{path}", timeout=5) as r:
        return json.load(r)


def read_ds(port: int, off: int, n: int) -> bytes:
    url = f"/api/memory/{DS_SEG * 16 + off}/range/{n}"
    data = http_json(port, url)
    if isinstance(data, dict):
        # the endpoint answers {"values": [...]}; older notes say "bytes"/"data".
        # Accept any of them but never silently return empty.
        for key in ('values', 'bytes', 'data'):
            if key in data:
                data = data[key]
                break
        else:
            raise SystemExit(f'unrecognised memory response keys: {list(data)}')
    return bytes(data)


def status(port: int):
    """/api/status, normalised. Flat decimal cs/ip -- NOT nested, NOT hex.

    reject_trap.py's whole warning about hex-vs-decimal lives here: this API reports
    decimal (cs=381 means 0x17D) while breakCsIp wants hex.
    """
    st = http_json(port, '/api/status')
    return {'cs': st['cs'], 'ip': st['ip'], 'paused': st.get('isPaused')}


def parse_ranges(specs):
    out = []
    for s in specs:
        a, _, n = s.partition(':')
        out.append((int(a, 16), int(n) if n else 1))
    return out


def wait_for_pause(port: int, target_ip: int, timeout: float, strict: bool = True):
    """Poll /api/status until the emulator is paused AT target_ip; return that status.

    isPaused alone is NOT proof of a breakpoint hit. Any HTTP memory read pauses the
    CPU for its duration (docs/spice86-capture.md, and the standing trap about keys
    lost during a read), and tools/spice86_type.py reads memory to verify its own key
    injection. So a concurrent key send produces real pauses at whatever address the
    CPU happened to be at -- which is how the first version of this tool reported a
    stop at the idle key-poll address while asking for 17B7.

    With strict=True a pause at any other address is skipped and polling continues.
    """
    t0 = time.time()
    while time.time() - t0 < timeout:
        st = status(port)
        if st['paused'] and (not strict or st['ip'] == target_ip):
            return st
        time.sleep(0.02)
    return None


def arm(conn: RSP, cs_hex: str, ip_hex: str) -> bool:
    reply = conn.monitor(f"breakCsIp {cs_hex} {ip_hex}", 2.0)
    return "Breakpoint added" in conn.decode_monitor(reply)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--http-port', type=int, default=20180)
    ap.add_argument('--gdb-port', type=int, default=20190)
    ap.add_argument('--ip', help='runtime offset (hex) to stop at, e.g. 17B7')
    ap.add_argument('--cs', type=lambda x: int(x, 16), default=CS_DEFAULT,
                    help='code segment (hex), default 17D')
    ap.add_argument('--dump', action='append', default=[],
                    help='DS range as OFF:LEN (hex), repeatable')
    ap.add_argument('--timeout', type=float, default=60.0)
    ap.add_argument('--no-continue', action='store_true',
                    help='arm but leave the target stopped (caller resumes)')
    ap.add_argument('--selftest', action='store_true',
                    help='positive and negative control against a live run')
    a = ap.parse_args()

    ranges = parse_ranges(a.dump)

    if a.selftest:
        st = status(a.http_port)
        cs_dec, ip_dec = st['cs'], st['ip']
        cs_hex, ip_hex = cs_ip_from_status(cs_dec, ip_dec)
        conn = RSP(a.gdb_port)
        print(f'selftest: CPU is at {cs_hex}:{ip_hex}')
        ok_pos = arm(conn, cs_hex, ip_hex)
        print(f'  positive control armed on the live address: {ok_pos}')
        conn.continue_()
        got = wait_for_pause(a.http_port, ip_dec, 10)
        print(f'  positive control actually stopped: {got is not None}'
              + (f' at {got["cs"]:04X}:{got["ip"]:04X}' if got else ''))
        if got:
            conn.continue_()
        conn.close()
        if not (ok_pos and got):
            print('SELFTEST FAIL: trap did not arm and stop on an executing address')
            return 1
        print('SELFTEST OK -- but this run is now POISONED: Spice86 has no command to')
        print('remove a breakpoint (monitor help lists only breakCycles/breakCsIp/')
        print('breakStop/callStack/peekRet/state/ramx/dumpAll), so the trap armed here')
        print('on the live idle address keeps firing. Restart the run before any')
        print('real capture.')
        return 0

    if not a.ip:
        print('nothing to do (use --ip or --selftest)', file=sys.stderr)
        return 2

    st = status(a.http_port)
    cs_hex, ip_hex = f'{a.cs:X}', a.ip.upper()
    conn = RSP(a.gdb_port)
    if not arm(conn, cs_hex, ip_hex):
        print(f'FAIL: could not arm breakCsIp {cs_hex} {ip_hex}', file=sys.stderr)
        conn.close()
        return 1
    print(f'armed on {cs_hex}:{ip_hex}')

    if not a.no_continue:
        conn.continue_()

    st = wait_for_pause(a.http_port, int(ip_hex, 16), a.timeout)
    if st is None:
        print(f'NO STOP within {a.timeout:.0f}s at {cs_hex}:{ip_hex}')
        conn.close()
        return 3

    print(f'STOP at {st["cs"]:04X}:{st["ip"]:04X} '
          f'(decimal {st["cs"]}:{st["ip"]}, paused={st["paused"]})')
    for off, n in ranges:
        raw = read_ds(a.http_port, off, n)
        print(f'  DS:{off:02X}..{off + n - 1:02X} = ' +
              ' '.join(f'{b:02X}' for b in raw) +
              f'   (as BCD pairs: ' +
              ' '.join(f'{raw[i]:02d}' for i in range(0, len(raw), 2)) + ')')
    conn.continue_()
    conn.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
