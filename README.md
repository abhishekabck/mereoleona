# 🔥 Mereoleona Vermillion — fire theme for GNOME

A reversible Black Clover / Mereoleona "Crimson Lion King" rice for your
Ubuntu 24.04 · GNOME 46 (Wayland) desktop. Built *on top of* your existing
MacTahoe-Dark + dash2dock + blur/wobbly/coverflow setup — nothing of yours was
replaced, only layered and 100% toggleable.

## Palette (extracted from her art)
| role | hex | from |
|------|-----|------|
| ember-black base | `#1A0F0A` / `#160C07` | dark vignette |
| molten orange | `#E8650E` | her flames |
| amber gold | `#F2A81E` | background fire |
| crimson | `#C8341E` | cape / eyeliner |
| cream text | `#F5E6CC` | skin highlight |
| steel-blue accent | `#6FA8B5` | **her eyes** (cursor/selection) |

## Use it
One-click in the app grid: **"🔥 Mereoleona — Fire Theme ON"** and
**"❄ Mereoleona — Restore Original"**.

Or from a terminal (`mereoleona` is on your PATH via `~/.local/bin`):
```
mereoleona on        # apply the fire theme
mereoleona off       # restore your original MacTahoe-Dark setup
mereoleona toggle    # flip
mereoleona status    # ON / OFF
mereoleona live      # install Hidamari + enable the LIVE video wallpaper (big download)
mereoleona wallpaper ~/Pictures/other.jpg   # rebuild wallpapers from a new image
```

## ⚡ To fully ignite (one-time)
The **fire window-open/close animation** (Burn My Windows) and any shell-theme
change only load when GNOME Shell restarts. On **Wayland that means a logout**:
1. Save your work, **log out and back in**.
2. Open new windows → they burst into flame. 🔥
3. Tune it: *Extensions* app → **Burn My Windows** → Effects (Fire is on by
   default; a `mereoleona` color profile is preloaded in
   `~/.config/burn-my-windows/profiles/`).

Everything else (wallpaper, terminal colors + banner, GTK accents, ember
workspace pills) is **already live now** — open a new terminal to see it.

## What changed (every layer is reversible)
| layer | what | revert |
|-------|------|--------|
| wallpaper | `gsettings` → darkened desktop + vivid lockscreen | dconf-load from backup |
| terminal | **new** "🔥 Mereoleona" gnome-terminal profile, set default | original default restored, profile removed |
| GTK3/4 | ember accent CSS layered onto your `gtk.css` | gtk4 restored byte-identical; gtk3 file removed |
| zsh | one `source` line → fire p10k colors + banner + LS_COLORS | source line stripped (your `.p10k.zsh` never edited) |
| space-bar | workspace pills → ember | original CSS restored from backup |
| extension | Burn My Windows installed + enabled + fire profile | disabled & removed from enabled list |

Your pristine snapshot lives in `~/.mereoleona/backup/` (full `dconf dump`, the
original `gtk.css`, `.zshrc`, wallpaper, theme/extension manifest). Even without
the scripts you can hand-restore: `dconf load / < ~/.mereoleona/backup/dconf-full.ini`.

## Live video wallpaper (max-vibe extra)
`mereoleona live` renders a seamless 12s "breathing ember" loop with ffmpeg
(`assets/mereoleona-live.mp4`, already generated) and installs **Hidamari**
(flatpak, user-scope, no sudo — but the first install pulls the large GNOME
runtime). After install, Hidamari opens: pick **mereoleona-live** from your
Videos folder and Apply. It auto-starts on login; `mereoleona off` stops it.

## Optional extras (apt — needs your password)
These power `blaze`/`ember` aliases and a richer fetch banner. Paste in a terminal:
```bash
sudo apt update && sudo apt install -y fastfetch cmatrix cbonsai lolcat figlet
```
Then `blaze` = red Matrix rain, `ember` = a living bonsai, `mana` = reprint banner.

## Knobs (set before the source line, or `export` then open a new shell)
```
export MEREOLEONA_PROMPT=0      # keep your exact p10k colors (skip fire recolor)
export MEREOLEONA_NO_BANNER=1   # no ASCII banner on terminal launch
```

## Deliberately NOT touched
Your **wobbly windows, blur-my-shell, magic-lamp, CoverflowAltTab,
dash2dock-lite** and your **MacTahoe GTK/icon/cursor themes** were left exactly
as you tuned them — they already supply the "magical motion", and the fire layer
rides on top. (A full custom GNOME-Shell theme was skipped on purpose to avoid
fighting dash2dock/blur-my-shell.)

## Extensions

Manage all extensions with the built-in CLI or GUI:

```bash
mereo-ext list          # show all extensions and their status
mereo-ext install pins  # install by id
mereo-ext remove pins   # uninstall
mereo-ext enable pins   # enable (must be installed first)
mereo-ext disable pins  # disable without removing
mereo-ext info pins     # details + deps
mereo-ext ui            # open graphical extension manager
```

Extension IDs: `pins` · `spectrum` · `launcher` · `timer` · `lyrics` · `lyrics-v2` · `viz`

---

### ⚡ Launcher

Quick-launch scripts and apps from the panel (the `⚡` button). Entries are stored in
`~/.config/mereoleona-launcher/entries.json`.

**Adding an entry via the popup:**
1. Click `⚡` in the top bar → `+` button (top right of the popup).
2. Fill in **Name** (display label), **Command** (full command or path, `~` is expanded).
3. Optionally set an **Icon** emoji.
4. Toggle **"Open in terminal"** (☑) if the command is a script you want to watch run — it opens in a `kitty` window that stays open after finishing.
5. Click **Save Entry**.

**Adding an entry manually** (edit the JSON directly):
```json
[
  { "key": "Build Rise",  "script": "~/scripts/build-rise.sh", "icon": "🔨", "terminal": true },
  { "key": "VS Code",     "script": "code ~",                  "icon": "✏️", "terminal": false }
]
```
Set `"terminal": true` for any script whose output you want to see.

**Running:** click an entry's `▶ Run` button, or use ↑/↓ to select then press Enter.

---

### ⏱ Timer

Task-time tracker in the panel. Tracks Jira tickets, supports pause/resume, logs
everything by day, and exports to a table.

**Starting a task:**
1. Click `⏱` in the top bar.
2. Fill in **Ticket** (e.g. `PROJ-42`; defaults to `P` if left blank).
3. Fill in **Task description**.
4. Click **▶ Start Task**.

The panel label updates every second: `⏱ PROJ-42  00:34:22`.

**While a task is running:**
- **⏸ Pause** — suspends the clock; task moves to the Paused list.
- **✓ Complete** — stops and logs the task as `completed`.
- **■ Stop** — stops and logs the task as `stopped`.

**Switching tasks:**
- Start a new task while one is running — the current task is auto-paused.
- Or click **⏸ Pause**, then Resume any paused task from the list.
- Only one task runs at a time.

**Viewing logs and exporting:**
1. Click `⏱` → **📋 View Log / Export**.
2. The log window shows all completed/stopped entries as a table.
3. **Filter** by typing a date (`2025-04-01`), ticket name, or keyword — the table updates live.
4. Click **⬇ Export** to write a `.txt` file to `~/.config/mereoleona-timer/export-<date>.txt`.

Export format (grouped by day):
```
── 2025-04-01 ──────────────────────────────────
Ticket         : Task                                     : Duration
--------------+-----------------------------------------+---------
PROJ-42        : Fix auth middleware token storage        : 01:23:10
PROJ-43        : Write migration tests                    : 00:45:00
```

**Data files** (`~/.config/mereoleona-timer/`):
| file | contents |
|------|----------|
| `tasks.json` | live state — running + paused tasks |
| `log.json` | all completed / stopped entries |
| `export-YYYY-MM-DD.txt` | last export run for that day |

---

### 🎵 Lyrics

Two separate tools — they don't conflict:

| command | what it does |
|---------|-------------|
| `mereoleona-lyrics` | Terminal karaoke — full scrolling lyrics in your terminal with fire gradient |
| `lyrics-v2` | GTK overlay — single current line floating on screen with a fire sweep animation |

Both fetch from [lrclib.net](https://lrclib.net) and require `playerctl` + a running media player.

```bash
lyrics-v2 --pos top        # anchor to top of screen
lyrics-v2 --pos bottom     # anchor to bottom (default)
lyrics-v2 --size 22        # font size in px
lyrics-v2 --bg '#1a0e00cc' # background color (RGBA hex)
lyrics-v2 --fg '#f2a81e'   # text color
```

---

## File map
```
~/.mereoleona/
├── bin/mereoleona            # the toggle command
├── backup/                   # pristine pre-theme snapshot (restore source)
├── assets/                   # wallpapers + mereoleona-live.mp4
├── shell/mereoleona.zsh      # fire prompt + banner (sourced from ~/.zshrc)
├── gtk/mereoleona-gtk.css    # ember GTK accent block
├── scripts/                  # backup / apply / restore / gen-* / installers
└── state/                    # active marker + terminal-profile uuid
```
