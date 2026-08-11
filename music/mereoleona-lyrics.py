#!/usr/bin/env python3
# 🔥 Mereoleona desktop lyrics — synced, fire-gradient karaoke for the current track.
# Sources: playerctl (track + position) + lrclib.net (synced lyrics). Stdlib only.
# Fetch runs in a BACKGROUND THREAD with retries + a long timeout, so a slow/flaky
# LRCLIB never freezes the window or drops the whole song's lyrics.
import json, math, os, re, shutil, socket, subprocess, sys, threading, time
import urllib.error, urllib.parse, urllib.request

# ---- force IPv4 (this host's IPv6 DNS hangs) ----
_gai = socket.getaddrinfo
socket.getaddrinfo = lambda *a, **k: ([r for r in _gai(*a, **k) if r[0] == socket.AF_INET] or _gai(*a, **k))

PLAYER = "spotify,%any"
TIMEOUT = 15            # per HTTP request (lrclib can take 6s+)
RETRIES = 4             # attempts before giving up
RST = "\033[0m"; HIDE, SHOW = "\033[?25l", "\033[?25h"
STOPS = [(200, 52, 30), (232, 101, 14), (242, 168, 30), (255, 214, 107), (255, 246, 230)]

# ---- shared lyrics state (written by the fetch thread, read by the render loop) ----
_LK = threading.Lock()
LY = {"key": None, "synced": [], "plain": "", "info": "", "status": "idle"}
#  status: idle | fetching | done | none | error

def lerp(a, b, t): return int(a + (b - a) * t)
def grad(frac):
    frac = max(0.0, min(1.0, frac)); x = frac * (len(STOPS) - 1); i = int(x); t = x - i
    if i >= len(STOPS) - 1: return STOPS[-1]
    a, b = STOPS[i], STOPS[i + 1]
    return (lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t))
def fg(r, g, b): return f"\033[38;2;{r};{g};{b}m"
def dim(rgb, k): return fg(int(rgb[0]*k), int(rgb[1]*k), int(rgb[2]*k))

def pctl(*args):
    try:
        return subprocess.run(["playerctl", "-p", PLAYER, *args],
                              capture_output=True, text=True, timeout=3).stdout.strip()
    except Exception:
        return ""

def jget(url):
    req = urllib.request.Request(url, headers={"User-Agent": "mereoleona-lyrics/1.0"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
        return json.load(r)

def fetch_lyrics(artist, title, album, dur):
    """Returns (data_or_None, network_error_bool)."""
    base = "https://lrclib.net/api/"
    neterr = False
    queries = [
        ("get", {"artist_name": artist, "track_name": title, "album_name": album, "duration": dur}),
        ("get", {"artist_name": artist, "track_name": title}),
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
            pass                     # 404 = not found (not a network problem)
        except Exception:
            neterr = True            # timeout / connection error
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
    for attempt in range(RETRIES):
        data, neterr = fetch_lyrics(artist, title, album, dur)
        if data is not None or not neterr:
            break                    # got it, OR a clean "not found"
        time.sleep(2)                # network hiccup -> wait and retry
    with _LK:
        if LY["key"] != key:
            return                   # track changed while we were fetching
        if data:
            sl = data.get("syncedLyrics") or ""
            LY["synced"] = parse_lrc(sl) if sl else []
            LY["plain"] = data.get("plainLyrics") or ""
            ok = LY["synced"] or LY["plain"]
            LY["status"] = "done" if ok else "none"
            if data.get("instrumental"):
                LY["status"] = "none"
        else:
            LY["status"] = "error" if neterr else "none"

def center(s, cols):
    return " " * max(0, (cols - len(s)) // 2) + s

def build_frame(snap, idx, pos, line_t, now, status, cols, rows):
    synced, plain, info, st = snap["synced"], snap["plain"], snap["info"], snap["status"]
    blank = " " * cols; grid = [blank] * rows; cy = rows // 2

    if st in ("fetching", "error", "none") and not synced and not plain:
        msg = {"fetching": "♪  loading lyrics…",
               "error": "⚠  couldn't reach the lyrics server (will keep trying)",
               "none": "♪  no lyrics found for this track"}[st]
        grid[cy] = fg(*STOPS[2]) + center(msg, cols) + RST
        if info:
            grid[cy + 2] = dim(STOPS[1], 0.7) + center(info[:cols], cols) + RST
        return "\033[H" + "\n".join(grid) + "\033[J"

    if not synced and plain:                       # unsynced: scroll window
        pl = plain.splitlines(); start = max(0, idx - cy)
        for r in range(rows):
            li = start + r
            if 0 <= li < len(pl):
                grid[r] = dim(STOPS[2], 0.75) + center(pl[li][:cols], cols) + RST
        return "\033[H" + "\n".join(grid) + "\033[J"

    n = len(synced)
    glow = 0.82 + 0.18 * math.sin(now * 2.0 * math.pi * 0.9)
    reveal = min(1.0, (now - line_t) / 0.45) if line_t else 1.0
    for off in range(-cy, rows - cy):
        r = cy + off; li = idx + off
        if li < 0 or li >= n:
            continue
        txt = synced[li][1]
        if not txt:
            continue
        if off == 0:
            shown = txt[:max(1, int(len(txt) * reveal))] if reveal < 1 else txt
            buf = " " * max(0, (cols - len(txt)) // 2)
            for i, ch in enumerate(shown):
                r0, g0, b0 = grad(i / max(1, len(txt) - 1))
                buf += fg(int(r0*glow), int(g0*glow), int(b0*glow)) + "\033[1m" + ch
            grid[r] = buf + RST
        else:
            k = max(0.22, 0.62 - 0.13 * abs(off))
            if status != "Playing":
                k *= 0.6
            grid[r] = dim(STOPS[2], k) + center(txt[:cols], cols) + RST
    grid[rows - 1] = dim(STOPS[1], 0.7) + center((("⏸ " if status != "Playing" else "♪ ") + info)[:cols], cols) + RST
    return "\033[H" + "\n".join(grid) + "\033[J"

def main():
    sys.stdout.write("\033[2J" + HIDE)
    last_idx, line_t, poll_t, pos, status = -2, 0.0, 0.0, 0.0, "Stopped"
    try:
        while True:
            now = time.time()
            cols, rows = shutil.get_terminal_size((80, 24)); rows = max(8, rows)

            if now - poll_t > 0.25:
                poll_t = now
                status = pctl("status") or "Stopped"
                title, artist = pctl("metadata", "xesam:title"), pctl("metadata", "xesam:artist")
                album = pctl("metadata", "xesam:album")
                try: dur = int(int(pctl("metadata", "mpris:length")) / 1_000_000)
                except Exception: dur = 0
                try: pos = float(pctl("position"))
                except Exception: pass
                key = (artist, title)
                if key != LY["key"]:
                    with _LK:
                        LY.update(key=key, synced=[], plain="", status=("fetching" if title else "none"),
                                  info=f"{artist} — {title}".strip(" —"))
                    if title:
                        threading.Thread(target=fetch_worker,
                                         args=(key, artist, title, album, dur), daemon=True).start()

            disp = pos + (now - poll_t if status == "Playing" else 0)
            with _LK:
                snap = dict(LY); snap["synced"] = LY["synced"]; snap["plain"] = LY["plain"]

            idx = -1
            if snap["synced"]:
                lo, hi = 0, len(snap["synced"])
                while lo < hi:
                    mid = (lo + hi) // 2
                    if snap["synced"][mid][0] <= disp: lo = mid + 1
                    else: hi = mid
                idx = lo - 1
            if idx != last_idx:
                last_idx, line_t = idx, now

            sys.stdout.write(build_frame(snap, idx, disp, line_t, now, status, cols, rows))
            sys.stdout.flush()
            time.sleep(1 / 18)
    except KeyboardInterrupt:
        pass
    finally:
        sys.stdout.write(SHOW + RST + "\033[2J\033[H"); sys.stdout.flush()

if __name__ == "__main__":
    main()
