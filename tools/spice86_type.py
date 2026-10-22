#!/usr/bin/env python3
"""spice86_type.py — inject keystrokes into a HEADLESS Spice86 session.

Why this exists: tools/spice86_keys.py sends keys with xdotool/XTEST, which needs a
focused window. An agent shell on this host has no DISPLAY, no WAYLAND_DISPLAY and no
Xvfb, so headed input is unavailable and every capture looked blocked on a human.

It is not blocked, because the game reads the keyboard the way a real 1983 machine
did. docs/pass-message-rendering.md records that **INT 16h is used at exactly one
site**, asm/4F4D_key_poll (AH=01h to test, AH=00h to consume). INT 16 reads the BIOS
typeahead ring buffer, not a window. So a key is just bytes in memory:

    0040:001E  head   (word, offset within the BDA segment)
    0040:001C  tail   (word)
    0040:001E  ring   16 entries of (scancode, ascii), wrap at 0040:003E

Writing a pair at tail and advancing tail is a key press. Verified: a headless run
parked at CS:F000:003D (the BIOS wait-for-key loop) with head == tail == 0x041E,
i.e. an empty buffer waiting to be filled.

Writes go through Spice86's own MCP endpoint (--McpHttpPort), which is the only
write path; the HTTP API is read-only. This speaks streamable-HTTP MCP directly
(initialize -> notifications/initialized -> tools/call, with
`Accept: application/json, text/event-stream` and the session id header) rather than
registering the server with an agent harness, so it works from any shell, any agent,
and CI with no per-host configuration.

Usage:
    python3 tools/spice86_type.py --list                 # what does the API offer?
    python3 tools/spice86_type.py --keys Escape,p        # ESC then P (play)
    python3 tools/spice86_type.py --probe                # show buffer + CS:IP, no write
    python3 tools/spice86_type.py --keys p --delay 0.4
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.request

HTTP = 20180
MCP = 20181
DS = 0x08BE                      # proven in docs/spice86-capture.md
BDA = 0x0040
OFF_HEAD = 0x001A
OFF_TAIL = 0x001C
RING_START = 0x001E
RING_END = 0x003E                # exclusive; 16 entries of 2 bytes

# name -> PcKeyboardKey spelling (SDL's enum, case-insensitive per the tool desc).
# Only what the title screen and driving need so far; single alphanumerics are
# handled generically and do not need an entry here.
KEYS = {
    'escape': 'Escape', 'esc': 'Escape',
    'return': 'Return', 'enter': 'Return',
    'space': 'Space',
    'up': 'Up', 'down': 'Down', 'left': 'Left', 'right': 'Right',
}


def letter(name):
    """Resolve a friendly key name to a PcKeyboardKey spelling."""
    if len(name) == 1 and name.isalnum():
        return name.upper()
    k = KEYS.get(name.lower())
    if k is None:
        raise SystemExit('unknown key %r — known: %s (single letters/digits always work)'
                         % (name, ', '.join(sorted(set(KEYS)))))
    return k


# ---------------------------------------------------------------- HTTP read side
def read_mem(seg, off, n, port=HTTP):
    phys = seg * 16 + off
    url = 'http://127.0.0.1:%d/api/memory/%d/range/%d' % (port, phys, n)
    with urllib.request.urlopen(url, timeout=10) as r:
        return bytes(json.load(r)['values'])


def status(port=HTTP):
    with urllib.request.urlopen('http://127.0.0.1:%d/api/status' % port,
                                timeout=10) as r:
        return json.load(r)


def keyboard_state(port=HTTP):
    bda = read_mem(BDA, 0x00, 0x40, port)
    head = int.from_bytes(bda[OFF_HEAD:OFF_HEAD + 2], 'little')
    tail = int.from_bytes(bda[OFF_TAIL:OFF_TAIL + 2], 'little')
    return head, tail, bda[RING_START:RING_END]


# ---------------------------------------------------------------- MCP write side
class Mcp:
    """Minimal streamable-HTTP MCP client: handshake once, then call tools."""

    def __init__(self, port=MCP):
        self.url = 'http://127.0.0.1:%d/mcp' % port
        self.session = None
        self._id = 0

    def _post(self, method, params=None, notify=False):
        self._id += 1
        body = {'jsonrpc': '2.0', 'method': method}
        if params is not None:
            body['params'] = params
        if not notify:
            body['id'] = self._id
        req = urllib.request.Request(self.url, data=json.dumps(body).encode(),
                                     headers={
                                         'Content-Type': 'application/json',
                                         'Accept': 'application/json, '
                                                   'text/event-stream',
                                         **({'Mcp-Session-Id': self.session}
                                            if self.session else {})})
        with urllib.request.urlopen(req, timeout=30) as r:
            sid = r.headers.get('Mcp-Session-Id')
            if sid:
                self.session = sid
            raw = r.read().decode('utf-8', 'replace')
        if notify:
            return None
        # The reply is either bare JSON or an SSE stream; pull the last data line.
        for line in raw.splitlines():
            if line.startswith('data:'):
                raw = line[5:].strip()
                break
        try:
            return json.loads(raw)
        except ValueError:
            return {'raw': raw[:400]}

    def open(self):
        r = self._post('initialize', {
            'protocolVersion': '2024-11-05', 'capabilities': {},
            'clientInfo': {'name': 'spice86_type', 'version': '1'}})
        self._post('notifications/initialized', notify=True)
        return r

    def tools(self):
        return self._post('tools/list')

    def call(self, name, args):
        return self._post('tools/call', {'name': name, 'arguments': args})


def write_mem(mcp, seg, off, data_hex):
    """write_memory takes segment/offset/data(hex string); try the shapes we know."""
    for args in ({'segment': seg, 'offset': off, 'data': data_hex},
                 {'Segment': seg, 'Offset': off, 'Data': data_hex}):
        r = mcp.call('write_memory', args)
        if r and 'error' not in r and not (r.get('result') or {}).get('isError'):
            return r
    return r


# ---------------------------------------------------------------- the injection
def send_key(mcp, keyname):
    """Full press: down then up, which is what the tool's description requires."""
    down = mcp.call('send_keyboard_key', {'key': keyname, 'isPressed': True})
    up = mcp.call('send_keyboard_key', {'key': keyname, 'isPressed': False})
    for r in (down, up):
        if r and 'error' in r:
            return r
    return up


def enqueue_bios(mcp, port, scan, asc):
    """Fallback: poke the BIOS typeahead ring directly (see module docstring)."""
    head, tail, _ = keyboard_state(port)
    if not (RING_START <= tail < RING_END):
        tail = RING_START
    write_mem(mcp, BDA, tail, '%02x%02x' % (scan, asc))
    nxt = tail + 2
    if nxt >= RING_END:
        nxt = RING_START
    write_mem(mcp, BDA, OFF_TAIL, '%04x' % nxt)
    return tail


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--http-port', type=int, default=HTTP)
    ap.add_argument('--mcp-port', type=int, default=MCP)
    ap.add_argument('--keys', help='comma/space separated: Escape,p')
    ap.add_argument('--delay', type=float, default=0.6,
                    help='seconds between keys (the game drains pending keys)')
    ap.add_argument('--list', action='store_true', help='list MCP tools and exit')
    ap.add_argument('--probe', action='store_true', help='show state, write nothing')
    a = ap.parse_args()

    st = status(a.http_port)
    print('CS:%04X IP:%04X cycles=%d' % (st['cs'], st['ip'], st['cycles']))
    head, tail, ring = keyboard_state(a.http_port)
    print('BDA head=0x%04X tail=0x%04X ring=%s'
          % (head, tail, ring[:8].hex(' ')))
    print('DS:36 name=%r' % read_mem(DS, 0x36, 16, a.http_port))
    if a.probe:
        return

    mcp = Mcp(a.mcp_port)
    init = mcp.open()
    if a.list:
        tl = mcp.tools()
        tools = (tl or {}).get('result', {}).get('tools', [])
        print('\nMCP session=%s, %d tools:' % (mcp.session, len(tools)))
        for t in tools:
            req = (t.get('inputSchema') or {}).get('required', [])
            print('  %-22s %s' % (t.get('name'), ','.join(req)))
        return

    names = [k for k in (a.keys or '').replace(',', ' ').split() if k]
    if not names:
        raise SystemExit('nothing to do (use --keys or --probe)')
    for name in names:
        keyname = letter(name)
        r = send_key(mcp, keyname)
        bad = (r or {}).get('error') or (r or {}).get('result', {}).get('isError')
        print('sent %-8s as %-8s %s' % (name, keyname, 'FAILED %s' % bad if bad else 'ok'))
        time.sleep(a.delay)
        s2 = status(a.http_port)
        h2, t2, _ = keyboard_state(a.http_port)
        print('   -> CS:%04X IP:%04X  head=0x%04X tail=0x%04X'
              % (s2['cs'], s2['ip'], h2, t2))
    print('DS:36 name=%r' % read_mem(DS, 0x36, 16, a.http_port))


if __name__ == '__main__':
    main()
