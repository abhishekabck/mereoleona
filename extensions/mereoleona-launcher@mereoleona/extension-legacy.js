// mereoleona-launcher — GNOME 42-44 legacy (old-style imports)
/* global imports, global */
const { St, Gio, GLib, Clutter } = imports.gi;
const Main = imports.ui.main;

const CONFIG_PATH = GLib.build_filenamev([
    GLib.get_home_dir(), '.config', 'mereoleona-launcher', 'entries.json'
]);

function loadEntries() {
    try {
        const [, bytes] = Gio.File.new_for_path(CONFIG_PATH).load_contents(null);
        return JSON.parse(new TextDecoder().decode(bytes));
    } catch (_) { return []; }
}

function saveEntries(entries) {
    try {
        Gio.File.new_for_path(CONFIG_PATH).replace_contents(
            new TextEncoder().encode(JSON.stringify(entries, null, 2)),
            null, false, Gio.FileCreateFlags.REPLACE_DESTINATION, null
        );
        return true;
    } catch (_) { return false; }
}

function launch(raw, inTerminal) {
    const cmd = raw.split('~/').join(GLib.get_home_dir() + '/');
    try {
        if (inTerminal) {
            GLib.spawn_command_line_async('kitty --hold bash -c ' + GLib.shell_quote(cmd));
        } else {
            GLib.spawn_command_line_async(cmd);
        }
    } catch (e) {
        Main.notifyError('Mereoleona Launcher', String(e));
    }
}

function makeEntry(styleClass) {
    return new St.Entry({ style_class: styleClass, can_focus: true, x_expand: true });
}

const Launcher = class Launcher {
    constructor() {
        this._entries  = [];
        this._filtered = [];
        this._selected = 0;
        this._rows     = [];
        this._keyId    = 0;
        this._built    = false;
        this._mode     = 'list';
    }

    _build() {
        this._backdrop = new St.Widget({
            style_class: 'mereo-launcher-backdrop',
            reactive: true, x: 0, y: 0,
            width: global.stage.width,
            height: global.stage.height,
        });
        this._backdrop.connect('button-press-event', () => { this.close(); return Clutter.EVENT_STOP; });

        this._box = new St.BoxLayout({ style_class: 'mereo-launcher-box', vertical: true, reactive: true });

        this._searchRow = new St.BoxLayout({ style_class: 'mereo-launcher-search-row', reactive: true });
        this._searchEntry = new St.Entry({ style_class: 'mereo-launcher-search', hint_text: 'Search…', can_focus: true, x_expand: true });
        this._searchEntry.get_clutter_text().connect('text-changed', () => { if (this._mode === 'list') this._filter(); });

        this._addBtn = new St.Button({ label: '+', style_class: 'mereo-launcher-add-btn', can_focus: true, reactive: true, y_align: Clutter.ActorAlign.CENTER });
        this._addBtn.connect('clicked', () => this._showAddForm());

        this._searchRow.add_child(new St.Label({ text: '🔍', style_class: 'mereo-launcher-search-icon', y_align: Clutter.ActorAlign.CENTER }));
        this._searchRow.add_child(this._searchEntry);
        this._searchRow.add_child(this._addBtn);

        this._listView   = new St.BoxLayout({ style_class: 'mereo-launcher-list', vertical: true, reactive: true });
        this._countLabel = new St.Label({ style_class: 'mereo-launcher-count', x_align: Clutter.ActorAlign.END });
        this._formView   = new St.BoxLayout({ style_class: 'mereo-launcher-form', vertical: true, reactive: true });
        this._buildForm();

        this._box.add_child(this._searchRow);
        this._box.add_child(this._listView);
        this._box.add_child(this._formView);
        this._box.add_child(this._countLabel);
        this._formView.hide();

        global.stage.add_child(this._backdrop);
        global.stage.add_child(this._box);
        this._built = true;
    }

    _buildForm() {
        const topRow  = new St.BoxLayout({ style_class: 'mereo-form-toprow', reactive: true });
        const backBtn = new St.Button({ label: '← Back', style_class: 'mereo-form-back-btn', can_focus: true, reactive: true });
        backBtn.connect('clicked', () => this._showList());
        topRow.add_child(backBtn);

        const nameRow = this._fieldRow('Name',    'mereo-form-entry');
        const cmdRow  = this._fieldRow('Command', 'mereo-form-entry');
        const iconRow = this._fieldRow('Icon',    'mereo-form-entry-short');
        this._fName = nameRow.entry; this._fCmd = cmdRow.entry; this._fIcon = iconRow.entry;
        this._fName.set_hint_text('e.g. Rise Dev');
        this._fCmd.set_hint_text('e.g. code ~/Projects/Rise  or  ~/scripts/build.sh');
        this._fIcon.set_hint_text('🔥');

        const termRow   = new St.BoxLayout({ style_class: 'mereo-form-field-row', reactive: true });
        const termLabel = new St.Label({ text: 'Open in terminal', style_class: 'mereo-form-label', y_align: Clutter.ActorAlign.CENTER, x_expand: true });
        this._fTerminal = new St.Button({ label: '☐', style_class: 'mereo-form-toggle-btn', can_focus: true, reactive: true, y_align: Clutter.ActorAlign.CENTER });
        this._terminalOn = false;
        this._fTerminal.connect('clicked', () => {
            this._terminalOn = !this._terminalOn;
            this._fTerminal.set_label(this._terminalOn ? '☑' : '☐');
        });
        termRow.add_child(termLabel); termRow.add_child(this._fTerminal);

        const saveRow = new St.BoxLayout({ style_class: 'mereo-form-save-row', reactive: true });
        const saveBtn = new St.Button({ label: 'Save Entry', style_class: 'mereo-form-save-btn', can_focus: true, reactive: true });
        saveBtn.connect('clicked', () => this._saveEntry());
        saveRow.add_child(new St.Widget({ x_expand: true }));
        saveRow.add_child(saveBtn);

        this._formView.add_child(topRow);
        this._formView.add_child(nameRow.row);
        this._formView.add_child(cmdRow.row);
        this._formView.add_child(iconRow.row);
        this._formView.add_child(termRow);
        this._formView.add_child(saveRow);
    }

    _fieldRow(labelText, entryClass) {
        const row   = new St.BoxLayout({ style_class: 'mereo-form-field-row', reactive: true });
        const label = new St.Label({ text: labelText, style_class: 'mereo-form-label', y_align: Clutter.ActorAlign.CENTER });
        const entry = makeEntry(entryClass);
        row.add_child(label); row.add_child(entry);
        return { row, entry };
    }

    open() {
        if (!this._built) this._build();
        this._entries = loadEntries();
        this._showList();
        this._backdrop.width  = global.stage.width;
        this._backdrop.height = global.stage.height;
        this._backdrop.show(); this._box.show();
        this._position();
        const aid = this._box.connect('notify::allocation', () => { this._box.disconnect(aid); this._position(); });
        this._keyId = global.stage.connect('key-press-event', (_a, ev) => this._onKey(ev));
    }

    _position() {
        const m = Main.layoutManager.primaryMonitor;
        this._box.set_position(
            m.x + Math.round((m.width  - this._box.width)  / 2),
            m.y + Math.round((m.height - this._box.height) / 3)
        );
    }

    close() {
        if (this._keyId) { global.stage.disconnect(this._keyId); this._keyId = 0; }
        if (this._backdrop) this._backdrop.hide();
        if (this._box) this._box.hide();
    }

    destroy() {
        this.close();
        if (this._backdrop) { this._backdrop.destroy(); this._backdrop = null; }
        if (this._box) { this._box.destroy(); this._box = null; }
        this._built = false;
    }

    _showList() {
        this._mode = 'list';
        this._formView.hide(); this._listView.show(); this._countLabel.show();
        this._searchEntry.set_text(''); this._filter();
        this._searchEntry.grab_key_focus();
    }

    _showAddForm() {
        this._mode = 'add';
        this._listView.hide(); this._countLabel.hide(); this._formView.show();
        this._fName.set_text(''); this._fCmd.set_text(''); this._fIcon.set_text('');
        this._terminalOn = false; this._fTerminal.set_label('☐');
        this._fName.grab_key_focus(); this._position();
    }

    _saveEntry() {
        const key    = this._fName.get_text().trim();
        const script = this._fCmd.get_text().trim();
        const icon   = this._fIcon.get_text().trim() || '▶';
        if (!key || !script) { Main.notify('Mereoleona Launcher', 'Name and Command are required'); return; }
        const entries = loadEntries();
        entries.push({ key, script, icon, terminal: this._terminalOn });
        if (saveEntries(entries)) { this._entries = entries; this._showList(); }
        else Main.notifyError('Mereoleona Launcher', 'Failed to save entries.json');
    }

    _filter() {
        const q = this._searchEntry.get_text().toLowerCase().trim();
        this._filtered = q ? this._entries.filter(e => e.key.toLowerCase().includes(q)) : this._entries.slice();
        this._selected = 0; this._renderList();
    }

    _renderList() {
        this._listView.destroy_all_children(); this._rows = [];
        for (let i = 0; i < this._filtered.length; i++) {
            const e = this._filtered[i]; const idx = i;
            const icon = new St.Label({ text: e.icon || '▶', style_class: 'mereo-launcher-item-icon', y_align: Clutter.ActorAlign.CENTER });
            const key  = new St.Label({ text: e.key,         style_class: 'mereo-launcher-item-key',  x_expand: true, y_align: Clutter.ActorAlign.CENTER });
            const scr  = new St.Label({ text: e.script,      style_class: 'mereo-launcher-item-script', y_align: Clutter.ActorAlign.CENTER });
            const runBtn = new St.Button({ label: '▶  Run', style_class: 'mereo-launcher-run-btn', can_focus: true, reactive: true, y_align: Clutter.ActorAlign.CENTER });
            runBtn.connect('clicked', () => { this.close(); launch(this._filtered[idx].script, !!this._filtered[idx].terminal); });
            const row = new St.BoxLayout({ style_class: 'mereo-launcher-item' + (i === this._selected ? ' selected' : ''), reactive: true });
            row.connect('enter-event', () => this._select(idx));
            row.add_child(icon); row.add_child(key); row.add_child(scr); row.add_child(runBtn);
            this._listView.add_child(row); this._rows.push(row);
        }
        this._countLabel.set_text(this._filtered.length + ' entries'); this._highlight();
    }

    _select(i) { this._selected = Math.max(0, Math.min(i, this._filtered.length - 1)); this._highlight(); }

    _highlight() {
        for (let i = 0; i < this._rows.length; i++) {
            if (i === this._selected) this._rows[i].add_style_class_name('selected');
            else this._rows[i].remove_style_class_name('selected');
        }
    }

    _onKey(ev) {
        const sym = ev.get_key_symbol();
        if (sym === Clutter.KEY_Escape) {
            if (this._mode === 'add') this._showList(); else this.close();
            return Clutter.EVENT_STOP;
        }
        if (this._mode === 'list') {
            if (sym === Clutter.KEY_Down)  { this._select(this._selected + 1); return Clutter.EVENT_STOP; }
            if (sym === Clutter.KEY_Up)    { this._select(this._selected - 1); return Clutter.EVENT_STOP; }
            if (sym === Clutter.KEY_Return || sym === Clutter.KEY_KP_Enter) {
                const e = this._filtered[this._selected];
                if (e) { this.close(); launch(e.script, !!e.terminal); }
                return Clutter.EVENT_STOP;
            }
        }
        return Clutter.EVENT_PROPAGATE;
    }
};

// ── lifecycle ─────────────────────────────────────────────────────────────────
let _launcher = null;
let _btn      = null;

function init() {} // eslint-disable-line no-unused-vars

function enable() { // eslint-disable-line no-unused-vars
    _launcher = new Launcher();
    _btn = new St.Button({
        style_class: 'panel-button mereo-launcher-panel-btn',
        reactive: true, can_focus: true, track_hover: true,
        accessible_name: 'Mereoleona Launcher',
    });
    _btn.set_child(new St.Label({ text: '⚡', y_align: Clutter.ActorAlign.CENTER, style_class: 'mereo-launcher-panel-icon' }));
    _btn.connect('clicked', () => _launcher.open());
    Main.panel._rightBox.insert_child_at_index(_btn, 0);
}

function disable() { // eslint-disable-line no-unused-vars
    if (_launcher) { _launcher.destroy(); _launcher = null; }
    if (_btn)      { _btn.destroy();      _btn = null; }
}
