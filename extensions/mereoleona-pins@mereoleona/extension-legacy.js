// mereoleona-pins — GNOME 42-44 legacy (old-style imports)
/* global imports, global */
const { St, Clutter, Meta, GLib, GObject } = imports.gi;
const Main      = imports.ui.main;
const PanelMenu = imports.ui.panelMenu;
const PopupMenu = imports.ui.popupMenu;
const DND       = imports.ui.dnd;

const SLOTS = 6;

function flash(win, cls) {
    try {
        const r = win.get_frame_rect();
        const a = new St.Widget({ style_class: cls, reactive: false, opacity: 0,
            x: r.x, y: r.y, width: r.width, height: r.height });
        a.set_pivot_point(0.5, 0.5);
        a.set_scale(1.12, 1.12);
        Main.layoutManager.uiGroup.add_child(a);
        a.ease({ opacity: 235, scale_x: 1, scale_y: 1, duration: 230,
            mode: Clutter.AnimationMode.EASE_OUT_QUAD,
            onComplete: () => a.ease({ opacity: 0, scale_x: 1.06, scale_y: 1.06, duration: 880,
                mode: Clutter.AnimationMode.EASE_IN_QUAD, onComplete: () => a.destroy() }) });
        const actor = win.get_compositor_private();
        if (actor) {
            actor.set_pivot_point(0.5, 0.5); actor.set_scale(1.03, 1.03);
            actor.ease({ scale_x: 1, scale_y: 1, duration: 420, mode: Clutter.AnimationMode.EASE_OUT_BACK });
        }
    } catch (e) {}
}

function windowAtPointer() {
    const [x, y] = global.get_pointer();
    const actors = global.get_window_actors();
    for (let i = actors.length - 1; i >= 0; i--) {
        const w = actors[i].meta_window;
        if (!w || w.get_window_type() !== Meta.WindowType.NORMAL || w.minimized) continue;
        const r = w.get_frame_rect();
        if (x >= r.x && x <= r.x + r.width && y >= r.y && y <= r.y + r.height) return w;
    }
    return null;
}

const Pin = class Pin {
    constructor(win, ext) {
        this.win = win; this.ext = ext; this._ids = []; this._lockTimer = 0; this._relock = false;
        if (win.get_maximized && win.get_maximized()) win.unmaximize(Meta.MaximizeFlags.BOTH);
        const r = win.get_frame_rect(); this.w = r.width; this.h = r.height;
        win.make_above(); win.activate(global.get_current_time());
        this._ids.push(win.connect('size-changed', () => this._scheduleLock()));
        this._ids.push(win.connect('unmanaged', () => this.ext.releaseWindow(win, true)));
        flash(win, 'mereo-pin-freeze');
    }
    _scheduleLock() {
        if (this._relock) return;
        if (this._lockTimer) GLib.Source.remove(this._lockTimer);
        this._lockTimer = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 220, () => {
            this._lockTimer = 0;
            const r = this.win.get_frame_rect();
            if (r.width !== this.w || r.height !== this.h) {
                this._relock = true;
                this.win.move_resize_frame(false, r.x, r.y, this.w, this.h);
                this._relock = false;
            }
            return GLib.SOURCE_REMOVE;
        });
    }
    shortLabel() {
        const t = this.win.get_title() || this.win.get_wm_class() || 'window';
        return t.length > 14 ? t.slice(0, 13) + '…' : t;
    }
    raise() { try { this.win.activate(global.get_current_time()); } catch (e) {} }
    release(thaw) {
        if (this._lockTimer) { GLib.Source.remove(this._lockTimer); this._lockTimer = 0; }
        for (let i = 0; i < this._ids.length; i++) { try { this.win.disconnect(this._ids[i]); } catch (e) {} }
        this._ids = [];
        if (thaw && this.win) { try { this.win.unmake_above(); } catch (e) {} flash(this.win, 'mereo-pin-thaw'); }
    }
};

// ext reference shared between Indicator and lifecycle functions
let _ext = null;

const Indicator = GObject.registerClass(
class Indicator extends PanelMenu.Button {
    _init(ext) {
        super._init(0.0, 'Mereoleona Pins');
        this.ext = ext;
        this.add_child(new St.Label({ text: '❄', y_align: Clutter.ActorAlign.CENTER, style_class: 'mereo-pins-icon' }));
        const head = new PopupMenu.PopupMenuItem('🔥 Pins — drag a pin onto a window (or click pin → click window)', { reactive: false });
        head.label.add_style_class_name('mereo-pins-header');
        this.menu.addMenuItem(head);
        const item = new PopupMenu.PopupBaseMenuItem({ reactive: false, can_focus: false });
        this._row = new St.BoxLayout({ style_class: 'mereo-pin-row', x_expand: true });
        item.add_child(this._row);
        this.menu.addMenuItem(item);
        this.rebuild();
    }
    rebuild() {
        this._row.destroy_all_children();
        for (let i = 0; i < SLOTS; i++) this._row.add_child(this.ext.makePin(i));
    }
});

const ExtImpl = class ExtImpl {
    enable() {
        this.slots = new Array(SLOTS).fill(null);
        this._armSlot = -1; this._pickId = 0; this._pickTimeout = 0; this._armTimeout = 0; this._armed = false;
        this._hint = null;
        this.indicator = new Indicator(this);
        Main.panel.addToStatusArea('mereoleona-pins', this.indicator);
    }
    disable() {
        this._cancelPick();
        for (let i = 0; i < this.slots.length; i++) { if (this.slots[i]) this.slots[i].release(true); }
        this.slots = new Array(SLOTS).fill(null);
        if (this.indicator) { this.indicator.destroy(); this.indicator = null; }
    }
    makePin(i) {
        const pin = this.slots[i];
        const btn = new St.Button({ style_class: 'mereo-pin ' + (pin ? 'assigned' : 'free'), can_focus: true, x_expand: true });
        const box = new St.BoxLayout({ vertical: true });
        box.add_child(new St.Label({ text: pin ? '❄' : '📌', style_class: 'mereo-pin-ico', x_align: Clutter.ActorAlign.CENTER }));
        box.add_child(new St.Label({ text: pin ? pin.shortLabel() : 'pin ' + (i + 1), style_class: 'mereo-pin-cap', x_align: Clutter.ActorAlign.CENTER }));
        btn.set_child(box);
        if (pin) {
            btn.connect('clicked', () => pin.raise());
            btn.connect('button-press-event', (_a, ev) => {
                if (ev.get_button() === 3) { this.releaseSlot(i); return Clutter.EVENT_STOP; }
                return Clutter.EVENT_PROPAGATE;
            });
        } else {
            btn.connect('clicked', () => this._armPick(i));
            const drag = DND.makeDraggable(btn, { restoreOnSuccess: true });
            drag.connect('drag-end',       () => this._dropOnWindow(i));
            drag.connect('drag-cancelled', () => this._dropOnWindow(i));
        }
        return btn;
    }
    _dropOnWindow(i) { if (!this.slots[i]) { const w = windowAtPointer(); if (w) this.assign(i, w); } }
    _armPick(i) {
        this._cancelPick();
        this._armSlot = i; this._armed = false;
        this._showHint('❄  Click the window to assign pin ' + (i + 1));
        this._armTimeout = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 450, () => { this._armed = true; this._armTimeout = 0; return GLib.SOURCE_REMOVE; });
        this._pickId = global.display.connect('notify::focus-window', () => {
            if (!this._armed) return;
            const w = global.display.get_focus_window();
            if (!w || w.get_window_type() !== Meta.WindowType.NORMAL) return;
            const slot = this._armSlot;
            this._cancelPick();
            this.assign(slot, w);
        });
        this._pickTimeout = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 12, () => { this._pickTimeout = 0; this._cancelPick(); return GLib.SOURCE_REMOVE; });
    }
    _cancelPick() {
        if (this._pickId)    { global.display.disconnect(this._pickId);   this._pickId = 0; }
        if (this._pickTimeout) { GLib.Source.remove(this._pickTimeout); this._pickTimeout = 0; }
        if (this._armTimeout)  { GLib.Source.remove(this._armTimeout);  this._armTimeout = 0; }
        this._armed = false; this._armSlot = -1; this._hideHint();
    }
    assign(i, win) {
        if (i < 0 || i >= SLOTS || this.slots[i]) return;
        if (this.slots.some(p => p && p.win === win)) { Main.notify('Mereoleona Pins', 'That window is already pinned'); return; }
        this.slots[i] = new Pin(win, this);
        if (this.indicator) this.indicator.rebuild();
    }
    releaseSlot(i) {
        if (!this.slots[i]) return;
        this.slots[i].release(true); this.slots[i] = null;
        if (this.indicator) this.indicator.rebuild();
    }
    releaseWindow(win, gone) {
        let found = -1;
        for (let i = 0; i < this.slots.length; i++) { if (this.slots[i] && this.slots[i].win === win) { found = i; break; } }
        if (found < 0) return;
        this.slots[found].release(!gone); this.slots[found] = null;
        if (this.indicator) this.indicator.rebuild();
    }
    _showHint(text) {
        this._hideHint();
        this._hint = new St.Label({ text, style_class: 'mereo-pin-hint' });
        Main.layoutManager.addTopChrome(this._hint);
        const place = () => {
            const m = Main.layoutManager.primaryMonitor;
            this._hint.set_position(m.x + Math.floor((m.width - this._hint.width) / 2), m.y + 90);
        };
        place(); this._hint.connect('notify::width', place);
    }
    _hideHint() { if (this._hint) { this._hint.destroy(); this._hint = null; } }
};

// ── lifecycle ─────────────────────────────────────────────────────────────────
function init()    { _ext = new ExtImpl(); } // eslint-disable-line no-unused-vars
function enable()  { _ext.enable(); }        // eslint-disable-line no-unused-vars
function disable() { _ext.disable(); }       // eslint-disable-line no-unused-vars
