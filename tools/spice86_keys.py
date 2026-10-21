#!/usr/bin/env python3
"""spice86_keys.py — send keystrokes to the running game window.

This is the actuator only. It deliberately does NOT read game state: a keystroke
is not a move. Nothing is queued while the game is mid-message, a blocked move
leaves the position unchanged, and a dropped key looks exactly like a blocked
move. Always confirm by reading memory afterwards (see tools/poll_probe.py and
tools/turn_recorder.py for the read side).

MECHANICS, all of them load-bearing
  * The window must be FOCUSED. Global XTEST events reach SDL. `xdotool key
    --window W` uses XSendEvent, which SDL ignores by design: it exits 0 and
    does nothing. So we `windowactivate --sync` first and then send globally.
  * DISPLAY and XAUTHORITY must be discovered, never hardcoded. The xauth
    filename carries a random suffix and changes per session, and this script is
    often run from a context where DISPLAY is unset.
  * A multi-key command has a timing WINDOW, not a minimum. The game's key read
    drains and discards pending keys before returning the one it keeps, so a
    second key sent too fast is thrown away, while one sent too slowly lets the
    prompt expire. One `xdotool key --delay N` invocation gives the controlled
    gap; per-key invocations add process-start jitter instead.
  * NumLock is forced off at startup, and its state is READ from the X server
    via python-Xlib rather than guessed. `xset` and `numlockx` are both absent on
    this host, and a blind toggle is as likely to turn NumLock on as off. The
    arrow patch removes the game's AL==0 gate, which means numpad digits with
    NumLock on would be read as arrows; turning it off removes that case instead
    of relying on luck.

Arrow spelling
  mode "real"  Up/Down/Left/Right. Needs tools/patch_arrows.py on the run copy.
  mode "kp"    KP_Up/KP_Down/... Works on a stock binary, but xdotool toggles
               NumLock to synthesise them, which is the behaviour this tool
               exists to avoid.

Usage
    python3 tools/spice86_keys.py --key Up
    python3 tools/spice86_keys.py --burst T Up
    python3 tools/spice86_keys.py --status
"""
import argparse
import glob
import os
import shutil
import subprocess
import sys
import time

ARROW_MODES = ('real', 'kp')
_BINDINGS = {
    'real': {'Up': 'Up', 'Down': 'Down', 'Left': 'Left', 'Right': 'Right'},
    'kp': {'Up': 'KP_Up', 'Down': 'KP_Down', 'Left': 'KP_Left', 'Right': 'KP_Right'},
}
_ALIASES = {}
for _k, _v in _BINDINGS['real'].items():
    _ALIASES[_k] = _k
    _ALIASES['KP_' + _k] = _k
    _ALIASES['NumPad' + {'Up': '8', 'Down': '2', 'Left': '4', 'Right': '6'}[_k]] = _k


class KeyboardError(RuntimeError):
    """Keys cannot be delivered, or a key could not be bound."""


def find_xauthority():
    pinned = os.environ.get('XAUTHORITY', '')
    if pinned and os.path.exists(pinned):
        return pinned
    for path in sorted(glob.glob('/run/user/%d/xauth_*' % os.getuid())):
        return path
    return ''


class GameKeyboard:
    def __init__(self, window_class='Spice86', arrows='real', settle=2.0,
                 burst_delay_ms=30, display=None):
        if shutil.which('xdotool') is None:
            raise KeyboardError('xdotool is not installed')
        if arrows not in ARROW_MODES:
            raise KeyboardError('arrows must be one of %s, got %r'
                                % (list(ARROW_MODES), arrows))
        self.arrows = arrows
        self.settle = settle
        self.burst_delay_ms = burst_delay_ms
        self.window_class = window_class
        self.display = display or os.environ.get('DISPLAY') or ':0'
        self.xauthority = find_xauthority()
        # Publish to the real process environment, not just the subprocess dict:
        # python-Xlib reads DISPLAY/XAUTHORITY from os.environ, so a NumLock read
        # silently returns 'unknown' if only the subprocess env is set.
        os.environ['DISPLAY'] = self.display
        if self.xauthority:
            os.environ['XAUTHORITY'] = self.xauthority
        self._env = self.build_env()

    def build_env(self):
        env = dict(os.environ)
        env['DISPLAY'] = self.display
        if self.xauthority:
            env['XAUTHORITY'] = self.xauthority
        else:
            env.pop('XAUTHORITY', None)
        return env

    def _x(self, *args, check=True):
        r = subprocess.run(['xdotool', *args], capture_output=True, env=self._env)
        if check and r.returncode != 0:
            raise KeyboardError('xdotool %s failed: %s'
                                % (' '.join(args), r.stderr.decode().strip()))
        return r.stdout.decode().strip()

    # -- window ---------------------------------------------------------------
    def find_window(self):
        out = self._x('search', '--class', self.window_class, check=False)
        return out.split()[0] if out else None

    def focus(self):
        w = self.find_window()
        if not w:
            return False
        self._x('windowactivate', '--sync', w)
        return True

    # -- numlock --------------------------------------------------------------
    def _led_mask(self):
        """Read the keyboard LED mask straight from the X server.

        `xset` and `numlockx` are both absent on this host, so python-Xlib is the
        only way to read state rather than guess it. Reading matters here: a blind
        toggle is as likely to turn NumLock ON as off.
        """
        try:
            from Xlib import display as xdisplay
        except ImportError:
            return None
        try:
            d = xdisplay.Display(self.display)
            mask = d.get_keyboard_control().led_mask
            d.close()
            return mask
        except Exception:
            return None

    def numlock_state(self):
        """'on' / 'off' / 'unknown'. NumLock is LED bit 1 on PC layouts;
        numlock_off() verifies by re-reading rather than trusting that."""
        mask = self._led_mask()
        if mask is None:
            return 'unknown'
        return 'on' if mask & 0x2 else 'off'

    def numlock_off(self):
        """Force NumLock off. The arrow patch makes numpad digits read as arrows
        when it is on, so this is a correctness step, not a nicety. Confirmed by
        re-reading the LED mask; a toggle that did not take is reported, not hidden."""
        state = self.numlock_state()
        if state == 'off':
            return 'already off'
        if state == 'unknown':
            return ('state unreadable (no Xlib or no X access); NOT toggling, '
                    'because a blind toggle can turn NumLock on')
        self._x('key', 'Num_Lock')
        time.sleep(0.3)
        after = self.numlock_state()
        if after == 'off':
            return 'toggled off (verified)'
        return 'FAILED: still %s after toggle - NumLock LED may not be bit 1 here' % after

    # -- keys -----------------------------------------------------------------
    def bind(self, key):
        tok = _ALIASES.get(key)
        if tok is None:
            return key          # non-arrow keys pass through untouched
        return _BINDINGS[self.arrows][tok]

    def send(self, key, settle=None):
        """Send one key. Returns whether it was DISPATCHED, not whether it landed."""
        if not self.focus():
            raise KeyboardError('no window matching class %r' % self.window_class)
        self._x('key', self.bind(key))
        time.sleep(self.settle if settle is None else settle)
        return True

    def send_burst(self, keys):
        """Several keys in ONE xdotool call with a controlled gap.

        Required for any two-keystroke command. Too tight and the game's key read
        discards the second key; too loose and the prompt expires. One invocation
        with --delay is the controlled version.
        """
        if not keys:
            return
        if not self.focus():
            raise KeyboardError('no window matching class %r' % self.window_class)
        bound = [self.bind(k) for k in keys]
        self._x('key', '--delay', str(self.burst_delay_ms), *bound)
        time.sleep(self.settle)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--key', help='send one key, e.g. Up, a, i')
    ap.add_argument('--burst', nargs='+', help='send several keys with a controlled gap')
    ap.add_argument('--status', action='store_true', help='report window and NumLock')
    ap.add_argument('--arrows', default='real', choices=list(ARROW_MODES))
    ap.add_argument('--window-class', default='Spice86')
    ap.add_argument('--settle', type=float, default=2.0)
    ap.add_argument('--display', default=None)
    args = ap.parse_args()

    try:
        kb = GameKeyboard(window_class=args.window_class, arrows=args.arrows,
                          settle=args.settle, display=args.display)
    except KeyboardError as e:
        print('ERROR: %s' % e, file=sys.stderr)
        return 2

    print('display=%s xauth=%s arrows=%s'
          % (kb.display, kb.xauthority or '<none found>', kb.arrows))
    win = kb.find_window()
    print('window: %s' % (win or 'NOT FOUND'))
    print('numlock: %s' % kb.numlock_state())

    if args.status:
        return 0 if win else 1
    if not win:
        print('ERROR: no game window to send to', file=sys.stderr)
        return 1

    print('numlock off: %s' % kb.numlock_off())
    if args.key:
        kb.send(args.key)
        print('sent %r (dispatched only — confirm by reading state)' % args.key)
    if args.burst:
        kb.send_burst(args.burst)
        print('sent burst %s (dispatched only)' % args.burst)
    return 0


if __name__ == '__main__':
    sys.exit(main())
