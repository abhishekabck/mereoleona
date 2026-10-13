#!/usr/bin/env python3
"""
mereo-ext-ui — Mereoleona Extension Manager (graphical)
GTK3 app. Launch with: mereo-ext ui  OR  mereo-ext-ui
"""
import json, os, re, shutil, subprocess, sys, threading

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('Gdk', '3.0')
gi.require_version('PangoCairo', '1.0')
from gi.repository import Gtk, Gdk, GLib, Pango
import cairo

MEREO_DIR = os.path.expanduser("~/.mereoleona")
REGISTRY  = os.path.join(MEREO_DIR, "extensions", "registry.json")
EXT_BASE  = os.path.expanduser("~/.local/share/gnome-shell/extensions")
BIN_DIR   = os.path.expanduser("~/.local/bin")
ICONS_DIR = os.path.join(MEREO_DIR, "assets", "icons")

# ── fire palette ──────────────────────────────────────────────────────────────
C_BG      = "#1a0e00"
C_CARD    = "#241608"
C_BORDER  = "rgba(232,101,14,0.2)"
C_TITLE   = "#fff6e6"
C_DESC    = "#a89070"
C_EMBER   = "#e8650e"
C_GOLD    = "#f2a81e"
C_DIM     = "#4a3020"
C_GREEN   = "#a6e3a1"
C_RED     = "#f38ba8"
C_YELLOW  = "#f9e2af"

CSS = f"""
window {{
    background-color: {C_BG};
}}
headerbar {{
    background-color: #200f00;
    color: {C_TITLE};
    border-bottom: 1px solid rgba(232,101,14,0.3);
    min-height: 46px;
}}
headerbar .title {{
    color: {C_TITLE};
    font-weight: bold;
    font-size: 14px;
}}
.ext-row {{
    background-color: {C_CARD};
    border-bottom: 1px solid rgba(232,101,14,0.12);
    padding: 12px 16px;
    margin: 0;
}}
.ext-row:hover {{
    background-color: #2e1a08;
}}
.ext-name {{
    color: {C_TITLE};
    font-weight: bold;
    font-size: 13px;
}}
.ext-desc {{
    color: {C_DESC};
    font-size: 11px;
}}
.ext-id {{
    color: {C_DIM};
    font-size: 10px;
    font-family: monospace;
}}
.badge-gnome {{
    background-color: rgba(232,101,14,0.18);
    color: {C_EMBER};
    border-radius: 4px;
    font-size: 10px;
    font-weight: bold;
    padding: 2px 7px;
}}
.badge-app {{
    background-color: rgba(242,168,30,0.18);
    color: {C_GOLD};
    border-radius: 4px;
    font-size: 10px;
    font-weight: bold;
    padding: 2px 7px;
}}
.status-enabled {{
    color: {C_GREEN};
    font-size: 11px;
    font-weight: bold;
}}
.status-disabled {{
    color: {C_YELLOW};
    font-size: 11px;
}}
.status-installed {{
    color: {C_GREEN};
    font-size: 11px;
    font-weight: bold;
}}
.status-not-installed {{
    color: {C_DIM};
    font-size: 11px;
}}
.btn-primary {{
    background-color: rgba(232,101,14,0.22);
    color: {C_EMBER};
    border: 1px solid rgba(232,101,14,0.4);
    border-radius: 6px;
    font-size: 11px;
    font-weight: bold;
    padding: 4px 14px;
    min-width: 90px;
}}
.btn-primary:hover {{
    background-color: rgba(232,101,14,0.40);
}}
.btn-danger {{
    background-color: rgba(243,139,168,0.15);
    color: {C_RED};
    border: 1px solid rgba(243,139,168,0.3);
    border-radius: 6px;
    font-size: 11px;
    font-weight: bold;
    padding: 4px 14px;
    min-width: 90px;
}}
.btn-danger:hover {{
    background-color: rgba(243,139,168,0.28);
}}
.btn-warn {{
    background-color: rgba(249,226,175,0.15);
    color: {C_YELLOW};
    border: 1px solid rgba(249,226,175,0.3);
    border-radius: 6px;
    font-size: 11px;
    font-weight: bold;
    padding: 4px 14px;
    min-width: 90px;
}}
.btn-warn:hover {{
    background-color: rgba(249,226,175,0.28);
}}
.section-header {{
    color: {C_EMBER};
    font-weight: bold;
    font-size: 11px;
    padding: 10px 16px 6px;
    background-color: transparent;
    letter-spacing: 1px;
}}
.footer-bar {{
    background-color: #200f00;
    border-top: 1px solid rgba(232,101,14,0.2);
    padding: 6px 16px;
}}
.footer-label {{
    color: {C_DIM};
    font-size: 10px;
}}
.icon-circle {{
    border-radius: 50%;
    min-width: 40px;
    min-height: 40px;
}}
"""


def run_cmd(*cmd):
    return subprocess.run(list(cmd), capture_output=True, text=True)


def gnome_installed(ext):
    return os.path.isdir(os.path.join(EXT_BASE, ext["uuid"]))

def gnome_enabled(ext):
    return ext["uuid"] in run_cmd("gnome-extensions", "list", "--enabled").stdout

def app_installed(ext):
    return os.path.isfile(os.path.join(BIN_DIR, ext["bin"]))

def get_status(ext):
    if ext["type"] == "gnome-shell":
        if not gnome_installed(ext): return "not-installed"
        return "enabled" if gnome_enabled(ext) else "disabled"
    return "installed" if app_installed(ext) else "not-installed"

def gsettings_add(uuid):
    cur = run_cmd("gsettings", "get", "org.gnome.shell", "enabled-extensions").stdout.strip()
    if uuid in cur: return
    new = f"['{uuid}']" if cur in ("@as []", "[]") else cur[:-1] + f", '{uuid}']"
    run_cmd("gsettings", "set", "org.gnome.shell", "enabled-extensions", new)

def gsettings_rm(uuid):
    cur = run_cmd("gsettings", "get", "org.gnome.shell", "enabled-extensions").stdout.strip()
    if uuid not in cur: return
    new = re.sub(rf",?\s*'{re.escape(uuid)}'", "", cur)
    new = re.sub(rf"'{re.escape(uuid)}',?\s*", "", new)
    new = re.sub(r",\s*\]", "]", new).strip() or "@as []"
    run_cmd("gsettings", "set", "org.gnome.shell", "enabled-extensions", new)


class IconWidget(Gtk.DrawingArea):
    """40×40 circle with emoji in center."""
    EMOJI_BG = {
        "gnome-shell": (0.91, 0.40, 0.05),  # ember
        "app":         (0.95, 0.66, 0.12),  # gold
    }

    def __init__(self, ext):
        super().__init__()
        self._emoji = ext["icon_emoji"]
        self._color = self.EMOJI_BG.get(ext["type"], (0.5, 0.5, 0.5))
        self.set_size_request(40, 40)
        self.connect("draw", self._draw)

    def _draw(self, _w, cr):
        r, g, b = self._color
        cr.set_source_rgba(r, g, b, 0.22)
        cr.arc(20, 20, 19, 0, 6.2832)
        cr.fill()
        cr.set_source_rgba(r, g, b, 0.55)
        cr.arc(20, 20, 19, 0, 6.2832)
        cr.set_line_width(1.5)
        cr.stroke()
        layout = self.create_pango_layout(self._emoji)
        desc = Pango.FontDescription.from_string("Noto Color Emoji 14")
        layout.set_font_description(desc)
        tw, th = layout.get_pixel_size()
        cr.move_to((40 - tw) / 2, (40 - th) / 2)
        from gi.repository import PangoCairo
        PangoCairo.show_layout(cr, layout)
        return False


class ExtRow(Gtk.ListBoxRow):
    def __init__(self, ext, on_action):
        super().__init__()
        self.ext = ext
        self._on_action = on_action
        self.get_style_context().add_class("ext-row")
        self.set_activatable(False)
        self.set_selectable(False)

        outer = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        outer.set_border_width(0)

        # icon
        icon = IconWidget(ext)
        icon.set_valign(Gtk.Align.CENTER)
        outer.pack_start(icon, False, False, 0)

        # text block
        text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        text_box.set_valign(Gtk.Align.CENTER)

        name_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        name_lbl = Gtk.Label(label=ext["name"])
        name_lbl.get_style_context().add_class("ext-name")
        name_lbl.set_halign(Gtk.Align.START)
        name_row.pack_start(name_lbl, False, False, 0)

        badge_cls = "badge-gnome" if ext["type"] == "gnome-shell" else "badge-app"
        badge_txt = "gnome-shell" if ext["type"] == "gnome-shell" else "app"
        badge = Gtk.Label(label=badge_txt)
        badge.get_style_context().add_class(badge_cls)
        badge.set_valign(Gtk.Align.CENTER)
        name_row.pack_start(badge, False, False, 0)

        desc_lbl = Gtk.Label(label=ext["description"])
        desc_lbl.get_style_context().add_class("ext-desc")
        desc_lbl.set_halign(Gtk.Align.START)
        desc_lbl.set_line_wrap(True)
        desc_lbl.set_max_width_chars(55)
        desc_lbl.set_xalign(0)

        id_lbl = Gtk.Label(label=ext["id"])
        id_lbl.get_style_context().add_class("ext-id")
        id_lbl.set_halign(Gtk.Align.START)

        text_box.pack_start(name_row, False, False, 0)
        text_box.pack_start(desc_lbl, False, False, 0)
        text_box.pack_start(id_lbl, False, False, 0)

        outer.pack_start(text_box, True, True, 0)

        # right side: status + buttons
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        right.set_valign(Gtk.Align.CENTER)
        right.set_halign(Gtk.Align.END)

        self._status_lbl = Gtk.Label()
        self._status_lbl.set_halign(Gtk.Align.END)
        right.pack_start(self._status_lbl, False, False, 0)

        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        btn_box.set_halign(Gtk.Align.END)

        self._btn_primary = Gtk.Button()
        self._btn_primary.connect("clicked", lambda _: self._act_primary())
        btn_box.pack_start(self._btn_primary, False, False, 0)

        if ext["type"] == "gnome-shell":
            self._btn_toggle = Gtk.Button()
            self._btn_toggle.connect("clicked", lambda _: self._act_toggle())
            btn_box.pack_start(self._btn_toggle, False, False, 0)
        else:
            self._btn_toggle = None

        right.pack_start(btn_box, False, False, 0)
        outer.pack_end(right, False, False, 0)

        self.add(outer)
        self.refresh()

    def refresh(self):
        status = get_status(self.ext)
        # status label
        cls_map = {
            "enabled":       ("● Enabled",       "status-enabled"),
            "disabled":      ("● Disabled",       "status-disabled"),
            "installed":     ("● Installed",      "status-installed"),
            "not-installed": ("○ Not installed",  "status-not-installed"),
        }
        txt, cls = cls_map[status]
        for c in ["status-enabled","status-disabled","status-installed","status-not-installed"]:
            self._status_lbl.get_style_context().remove_class(c)
        self._status_lbl.set_text(txt)
        self._status_lbl.get_style_context().add_class(cls)

        # primary button
        for c in ["btn-primary", "btn-danger"]:
            self._btn_primary.get_style_context().remove_class(c)
        if status == "not-installed":
            self._btn_primary.set_label("Install")
            self._btn_primary.get_style_context().add_class("btn-primary")
        else:
            self._btn_primary.set_label("Remove")
            self._btn_primary.get_style_context().add_class("btn-danger")

        # toggle button (GNOME only)
        if self._btn_toggle:
            for c in ["btn-primary", "btn-warn"]:
                self._btn_toggle.get_style_context().remove_class(c)
            if status == "enabled":
                self._btn_toggle.set_label("Disable")
                self._btn_toggle.get_style_context().add_class("btn-warn")
                self._btn_toggle.set_sensitive(True)
            elif status == "disabled":
                self._btn_toggle.set_label("Enable")
                self._btn_toggle.get_style_context().add_class("btn-primary")
                self._btn_toggle.set_sensitive(True)
            else:
                self._btn_toggle.set_label("Enable")
                self._btn_toggle.set_sensitive(False)

    def _set_busy(self, busy):
        self._btn_primary.set_sensitive(not busy)
        if self._btn_toggle:
            self._btn_toggle.set_sensitive(not busy)

    def _act_primary(self):
        status = get_status(self.ext)
        self._set_busy(True)
        action = "remove" if status != "not-installed" else "install"
        threading.Thread(target=self._run_action, args=(action,), daemon=True).start()

    def _act_toggle(self):
        status = get_status(self.ext)
        self._set_busy(True)
        action = "disable" if status == "enabled" else "enable"
        threading.Thread(target=self._run_action, args=(action,), daemon=True).start()

    def _run_action(self, action):
        ext = self.ext
        try:
            if action == "install":
                if ext["type"] == "gnome-shell":
                    src = os.path.join(MEREO_DIR, ext["source"])
                    dst = os.path.join(EXT_BASE, ext["uuid"])
                    os.makedirs(dst, exist_ok=True)
                    shutil.copytree(src, dst, dirs_exist_ok=True)
                    gsettings_add(ext["uuid"])
                    run_cmd("gnome-extensions", "enable", ext["uuid"])
                else:
                    for bf in ext.get("bin_files", []):
                        src = os.path.join(MEREO_DIR, bf)
                        dst = os.path.join(BIN_DIR, os.path.basename(bf))
                        shutil.copy2(src, dst)
                        os.chmod(dst, 0o755)
            elif action == "remove":
                if ext["type"] == "gnome-shell":
                    run_cmd("gnome-extensions", "disable", ext["uuid"])
                    gsettings_rm(ext["uuid"])
                    d = os.path.join(EXT_BASE, ext["uuid"])
                    if os.path.isdir(d):
                        shutil.rmtree(d)
                else:
                    for bf in ext.get("bin_files", []):
                        p = os.path.join(BIN_DIR, os.path.basename(bf))
                        if os.path.isfile(p): os.remove(p)
            elif action == "enable":
                gsettings_add(ext["uuid"])
                run_cmd("gnome-extensions", "enable", ext["uuid"])
            elif action == "disable":
                run_cmd("gnome-extensions", "disable", ext["uuid"])
                gsettings_rm(ext["uuid"])
        except Exception as e:
            print(f"mereo-ext-ui error [{action}]: {e}", file=sys.stderr)
        GLib.idle_add(self._after_action, action)

    def _after_action(self, action):
        self.refresh()
        self._set_busy(False)
        self._on_action(self.ext, action)
        return False


class ExtManager(Gtk.ApplicationWindow):
    def __init__(self, app, registry):
        super().__init__(application=app, title="Mereoleona Extensions")
        self._registry = registry

        self.set_default_size(740, 560)
        self.set_resizable(True)
        self.set_icon_name("preferences-system")

        # Header bar
        hb = Gtk.HeaderBar()
        hb.set_show_close_button(True)
        hb.set_title("Mereoleona Extensions")
        hb.set_subtitle("manage your fire setup")
        self.set_titlebar(hb)

        # Refresh button
        refresh_btn = Gtk.Button.new_from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON)
        refresh_btn.set_tooltip_text("Refresh status")
        refresh_btn.connect("clicked", lambda _: self._refresh_all())
        hb.pack_end(refresh_btn)

        # Main layout
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(outer)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        outer.pack_start(scroll, True, True, 0)

        self._listbox = Gtk.ListBox()
        self._listbox.set_selection_mode(Gtk.SelectionMode.NONE)
        scroll.add(self._listbox)

        # Section: GNOME Shell
        self._add_section("GNOME SHELL EXTENSIONS")
        for ext in [e for e in registry if e["type"] == "gnome-shell"]:
            row = ExtRow(ext, self._on_action)
            self._listbox.add(row)

        # Section: Apps
        self._add_section("APPS & TOOLS")
        for ext in [e for e in registry if e["type"] == "app"]:
            row = ExtRow(ext, self._on_action)
            self._listbox.add(row)

        # Footer
        self._footer = Gtk.Label()
        self._footer.get_style_context().add_class("footer-label")
        self._footer.set_halign(Gtk.Align.START)
        footer_box = Gtk.Box()
        footer_box.get_style_context().add_class("footer-bar")
        footer_box.pack_start(self._footer, False, False, 0)
        outer.pack_end(footer_box, False, False, 0)

        self._update_footer()
        self.show_all()

    def _add_section(self, title):
        lbl = Gtk.Label(label=title)
        lbl.get_style_context().add_class("section-header")
        lbl.set_halign(Gtk.Align.START)
        row = Gtk.ListBoxRow()
        row.set_activatable(False)
        row.set_selectable(False)
        row.add(lbl)
        self._listbox.add(row)

    def _on_action(self, ext, action):
        self._update_footer()
        if ext.get("requires_logout") and action in ("install", "enable", "disable"):
            self._toast(f"Log out and back in to apply changes to {ext['short']}.")

    def _toast(self, msg):
        dialog = Gtk.MessageDialog(
            transient_for=self, modal=False,
            message_type=Gtk.MessageType.INFO,
            buttons=Gtk.ButtonsType.OK,
            text=msg
        )
        dialog.connect("response", lambda d, _: d.destroy())
        dialog.show()

    def _refresh_all(self):
        for row in self._listbox.get_children():
            if isinstance(row, ExtRow):
                row.refresh()
        self._update_footer()

    def _update_footer(self):
        installed = sum(1 for e in self._registry if get_status(e) != "not-installed")
        enabled   = sum(1 for e in self._registry
                        if e["type"] == "gnome-shell" and get_status(e) == "enabled")
        gnome_total = sum(1 for e in self._registry if e["type"] == "gnome-shell")
        app_total   = sum(1 for e in self._registry if e["type"] == "app")
        app_inst    = sum(1 for e in self._registry
                         if e["type"] == "app" and get_status(e) == "installed")
        self._footer.set_text(
            f"{enabled}/{gnome_total} GNOME extensions enabled  ·  "
            f"{app_inst}/{app_total} apps installed"
        )


class ExtApp(Gtk.Application):
    def __init__(self, registry):
        super().__init__(application_id="io.mereoleona.ExtManager")
        self._registry = registry

    def do_activate(self):
        win = ExtManager(self, self._registry)
        win.present()


def main():
    if not os.path.exists(REGISTRY):
        print(f"Registry not found: {REGISTRY}\nRun install.sh first.", file=sys.stderr)
        sys.exit(1)
    with open(REGISTRY) as f:
        registry = json.load(f)

    provider = Gtk.CssProvider()
    provider.load_from_data(CSS.encode())
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(),
        provider,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )

    app = ExtApp(registry)
    sys.exit(app.run(sys.argv))


if __name__ == "__main__":
    main()
