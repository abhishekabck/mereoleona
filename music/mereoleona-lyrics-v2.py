#!/usr/bin/env python3
"""
mereoleona-lyrics-v2: Single-line GTK overlay, no terminal.
Shows only the current line being sung. Configurable colors.

Usage: lyrics-v2 [--bg COLOR] [--fg COLOR] [--size PX] [--pos top|bottom|center]
Colors: #rrggbb or #rrggbbaa (aa = alpha, e.g. cc = 80%)
"""
import argparse, json, math, os, re, socket, subprocess, sys, threading, time
import urllib.error, urllib.parse, urllib.request

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('PangoCairo', '1.0')
from gi.repository import Gtk, Gdk, GLib, Pango, PangoCairo
import cairo

# ── IPv4 fix (same as v1 — this host's IPv6 DNS hangs) ───────────────────────
_gai = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: (
    [r for r in _gai(*a, **k) if r[0] == socket.AF_INET] or _gai(*a, **k)
)

# ── gtk-layer-shell: proper Wayland overlay (optional) ───────────────────────
try:
    gi.require_version('GtkLayerShell', '0.1')
    from gi.repository import GtkLayerShell
    HAS_LAYER_SHELL = True
except (ImportError, ValueError):
    HAS_LAYER_SHELL = False

PLAYER  = "spotify,%any"
TIMEOUT = 15
RETRIES = 4

# ── shared lyrics state ───────────────────────────────────────────────────────
_LK = threading.Lock()
LY  = {"key": None, "synced": [], "plain": "", "status": "idle"}


def pctl(*args):
    try:
        return subprocess.run(
            ["playerctl", "-p", PLAYER, *args],
            capture_output=True, text=True, timeout=3
        ).stdout.strip()
    except Exception:
        return ""


def jget(url):
    req = urllib.request.Request(url, headers={"User-Agent": "mereoleona-lyrics/2.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.load(r)


def fetch_lyrics(artist, title, album, dur):
    base   = "https://lrclib.net/api/"
    neterr = False
    queries = [
        ("get",    {"artist_name": artist, "track_name": title, "album_name": album, "duration": dur}),
        ("get",    {"artist_name": artist, "track_name": title}),
        ("search", {"q": f"{artist} {title}"}),
    ]
    for ep, params in queries:
        try:
            d = jget(base + ep + "?" + urllib.parse.urlencode(params))
            if ep == "search":
                if isinstance(d, list) and d:
                    return (next((x for x in d if x.get("syncedLyrics")), d[0]), False)
            elif d and (d.get("syncedLyrics") or d.get("plainLyrics")):
                return (d, False)
        except urllib.error.HTTPError:
            pass
        except Exception:
            neterr = True
    return (None, neterr)


def parse_lrc(text):
    out = []
    for ln in text.splitlines():
        for mm, ss in re.findall(r"\[(\d+):(\d+(?:\.\d+)?)\]", ln):
            out.append((int(mm) * 60 + float(ss), re.sub(r"\[[^\]]*\]", "", ln).strip()))
    out.sort(key=lambda x: x[0])
    return out


def fetch_worker(key, artist, title, album, dur):
    data, neterr = None, False
    for _ in range(RETRIES):
        data, neterr = fetch_lyrics(artist, title, album, dur)
        if data is not None or not neterr:
            break
        time.sleep(2)
    with _LK:
        if LY["key"] != key:
            return
        if data:
            sl = data.get("syncedLyrics") or ""
            LY["synced"] = parse_lrc(sl) if sl else []
            LY["plain"]  = data.get("plainLyrics") or ""
            if data.get("instrumental"):
                LY["status"] = "none"
            else:
                LY["status"] = "done" if (LY["synced"] or LY["plain"]) else "none"
        else:
            LY["status"] = "error" if neterr else "none"


def parse_color(s):
    """#rrggbb → (r,g,b, 0.82)   #rrggbbaa → (r,g,b,a)  all floats 0–1."""
    s = s.lstrip('#')
    if len(s) == 6:
        return int(s[0:2],16)/255, int(s[2:4],16)/255, int(s[4:6],16)/255, 0.82
    if len(s) == 8:
        return (int(s[0:2],16)/255, int(s[2:4],16)/255,
                int(s[4:6],16)/255, int(s[6:8],16)/255)
    raise ValueError(f"Expected #rrggbb or #rrggbbaa, got '#{s}'")


def _rounded_rect(cr, x, y, w, h, r):
    cr.new_path()
    cr.arc(x + r,     y + r,     r, math.pi,       3*math.pi/2)
    cr.arc(x + w - r, y + r,     r, 3*math.pi/2,   0)
    cr.arc(x + w - r, y + h - r, r, 0,              math.pi/2)
    cr.arc(x + r,     y + h - r, r, math.pi/2,     math.pi)
    cr.close_path()


class LyricsOverlay(Gtk.Window):
    PAD_X = 36
    PAD_Y = 14

    def __init__(self, bg, fg, font_size, position):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self._bg        = bg
        self._fg        = fg
        self._font_size = font_size
        self._position  = position
        self._line      = ""

        # Window chrome
        self.set_decorated(False)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.set_accept_focus(False)
        self.set_title("mereoleona-lyrics-v2")

        # RGBA (transparency)
        screen = self.get_screen()
        visual  = screen.get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        # Wayland layer shell (best)
        if HAS_LAYER_SHELL:
            GtkLayerShell.init_for_window(self)
            GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
            GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.LEFT,  True)
            GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT, True)
            if position == 'top':
                GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
                GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, 52)
            elif position == 'center':
                pass  # no edge anchoring → vertically centered
            else:  # bottom
                GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
                GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 52)
            GtkLayerShell.set_exclusive_zone(self, -1)   # don't push panels aside
            GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        else:
            self.set_keep_above(True)
            self.set_type_hint(Gdk.WindowTypeHint.NOTIFICATION)

        # Drawing area (sized to just wrap the text + padding)
        h_px = font_size + self.PAD_Y * 2
        self._da = Gtk.DrawingArea()
        self._da.set_size_request(200, h_px)   # width grows on first draw
        self._da.connect('draw', self._on_draw)
        self.add(self._da)

        self.connect('destroy', Gtk.main_quit)
        self.connect('key-press-event', self._on_key)

        # Poll state
        self._poll_t      = 0.0
        self._track_pos   = 0.0
        self._play_status = "Stopped"
        self._last_idx    = -2

        GLib.timeout_add(55, self._tick)   # ~18 fps

        self.show_all()
        if not HAS_LAYER_SHELL:
            self._reposition()

    def _on_key(self, _w, ev):
        if ev.keyval in (Gdk.KEY_q, Gdk.KEY_Escape, Gdk.KEY_Q):
            Gtk.main_quit()
        return False

    def _reposition(self):
        display = Gdk.Display.get_default()
        mon     = display.get_primary_monitor()
        geo     = mon.get_geometry()
        h       = self._font_size + self.PAD_Y * 2
        self.resize(geo.width, h)
        if self._position == 'top':
            self.move(geo.x, geo.y + 52)
        elif self._position == 'center':
            self.move(geo.x, geo.y + (geo.height - h) // 2)
        else:
            self.move(geo.x, geo.y + geo.height - h - 64)

    def _on_draw(self, widget, cr):
        alloc = widget.get_allocation()
        w, h  = alloc.width, alloc.height

        # Clear to transparent
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()

        if not self._line:
            return False

        # Measure text
        layout = widget.create_pango_layout(self._line)
        desc   = Pango.FontDescription.from_string(f"Sans Bold {self._font_size}")
        layout.set_font_description(desc)
        tw, th = layout.get_pixel_size()

        # Pill behind the text, centred in the allocated area
        bw = tw + self.PAD_X * 2
        bh = th + self.PAD_Y * 2
        bx = (w - bw) / 2
        by = (h - bh) / 2
        r  = bh / 2   # full pill

        cr.set_operator(cairo.OPERATOR_OVER)
        cr.set_source_rgba(*self._bg)
        _rounded_rect(cr, bx, by, bw, bh, r)
        cr.fill()

        # Text
        cr.set_source_rgba(*self._fg)
        cr.move_to(bx + self.PAD_X, by + self.PAD_Y)
        PangoCairo.show_layout(cr, layout)

        return False

    def _tick(self):
        now = time.time()

        if now - self._poll_t > 0.25:
            self._poll_t      = now
            self._play_status = pctl("status") or "Stopped"
            title  = pctl("metadata", "xesam:title")
            artist = pctl("metadata", "xesam:artist")
            album  = pctl("metadata", "xesam:album")
            try:
                dur = int(int(pctl("metadata", "mpris:length")) / 1_000_000)
            except Exception:
                dur = 0
            try:
                self._track_pos = float(pctl("position"))
            except Exception:
                pass
            key = (artist, title)
            if key != LY["key"]:
                with _LK:
                    LY.update(key=key, synced=[], plain="",
                              status="fetching" if title else "none")
                if title:
                    threading.Thread(
                        target=fetch_worker,
                        args=(key, artist, title, album, dur),
                        daemon=True
                    ).start()

        disp = self._track_pos + (now - self._poll_t if self._play_status == "Playing" else 0)

        with _LK:
            synced = list(LY["synced"])
            status = LY["status"]

        idx = -1
        if synced:
            lo, hi = 0, len(synced)
            while lo < hi:
                mid = (lo + hi) // 2
                if synced[mid][0] <= disp:
                    lo = mid + 1
                else:
                    hi = mid
            idx = lo - 1

        if 0 <= idx < len(synced):
            new_line = synced[idx][1]
        elif status == "fetching":
            new_line = "♪  loading lyrics…"
        elif status == "error":
            new_line = "⚠  couldn't reach the lyrics server"
        else:
            new_line = ""

        if new_line != self._line:
            self._line = new_line
            self._da.queue_draw()

        return True   # keep timer alive


def main():
    p = argparse.ArgumentParser(
        description="lyrics-v2: single-line lyrics overlay, no terminal"
    )
    p.add_argument("--bg",   default="#1a1a2ecc",
                   help="Background color: #rrggbb or #rrggbbaa  (default: dark navy 80%%)")
    p.add_argument("--fg",   default="#ffffffee",
                   help="Text color: #rrggbb or #rrggbbaa  (default: white 93%%)")
    p.add_argument("--size", type=int, default=22,
                   help="Font size in px  (default: 22)")
    p.add_argument("--pos",  choices=["top","bottom","center"], default="bottom",
                   help="Vertical position  (default: bottom)")
    args = p.parse_args()

    try:
        bg = parse_color(args.bg)
    except ValueError as e:
        print(f"lyrics-v2: bad --bg: {e}", file=sys.stderr); sys.exit(1)
    try:
        fg = parse_color(args.fg)
    except ValueError as e:
        print(f"lyrics-v2: bad --fg: {e}", file=sys.stderr); sys.exit(1)

    LyricsOverlay(bg, fg, args.size, args.pos)
    Gtk.main()


if __name__ == "__main__":
    main()
