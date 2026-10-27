// mereoleona-timer — GNOME 45+ (ESM)
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

const DATA_DIR   = GLib.build_filenamev([GLib.get_home_dir(), '.config', 'mereoleona-timer']);
const TASKS_FILE = GLib.build_filenamev([DATA_DIR, 'tasks.json']);
const LOG_FILE   = GLib.build_filenamev([DATA_DIR, 'log.json']);

function ensureDir() { GLib.mkdir_with_parents(DATA_DIR, 0o755); }

function readJSON(path, fallback) {
    try {
        const [, bytes] = Gio.File.new_for_path(path).load_contents(null);
        return JSON.parse(new TextDecoder().decode(bytes));
    } catch (_) { return fallback; }
}

function writeJSON(path, data) {
    ensureDir();
    Gio.File.new_for_path(path).replace_contents(
        new TextEncoder().encode(JSON.stringify(data, null, 2)),
        null, false, Gio.FileCreateFlags.REPLACE_DESTINATION, null
    );
}

function now()   { return Math.floor(Date.now() / 1000); }
function today() {
    const d = new Date();
    return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
}
function fmtDuration(secs) {
    const h = Math.floor(secs / 3600);
    const m = Math.floor((secs % 3600) / 60);
    const s = secs % 60;
    return `${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
}
function genId() { return Date.now().toString(36) + Math.random().toString(36).slice(2, 6); }

class TaskStore {
    load() {
        const d = readJSON(TASKS_FILE, { running: null, paused: [] });
        this.running = d.running || null;
        this.paused  = d.paused  || [];
    }
    save() { writeJSON(TASKS_FILE, { running: this.running, paused: this.paused }); }
    runningElapsed() {
        if (!this.running) return 0;
        return this.running.accSecs + (now() - this.running.startedAt);
    }
    start(ticket, task) {
        if (this.running) this._pauseRunning();
        this.running = { id: genId(), ticket: ticket || 'P', task, startedAt: now(), accSecs: 0, date: today() };
        this.save();
    }
    pause() { if (this.running) { this._pauseRunning(); this.save(); } }
    _pauseRunning() {
        this.running.accSecs += now() - this.running.startedAt;
        this.running.startedAt = null;
        this.paused.push(this.running);
        this.running = null;
    }
    resume(id) {
        const idx = this.paused.findIndex(t => t.id === id);
        if (idx === -1) return;
        if (this.running) this._pauseRunning();
        const t = this.paused.splice(idx, 1)[0];
        t.startedAt = now();
        this.running = t;
        this.save();
    }
    stop(id)     { this._log(id, 'stopped'); }
    complete(id) { this._log(id, 'completed'); }
    _log(id, status) {
        let task = null;
        if (this.running && this.running.id === id) {
            task = this.running;
            task.accSecs += now() - task.startedAt;
            this.running = null;
        } else {
            const idx = this.paused.findIndex(t => t.id === id);
            if (idx !== -1) task = this.paused.splice(idx, 1)[0];
        }
        if (!task) return;
        const log = readJSON(LOG_FILE, []);
        log.push({ id: task.id, ticket: task.ticket, task: task.task, date: task.date, duration: task.accSecs, status });
        writeJSON(LOG_FILE, log);
        this.save();
    }
}

class TimerIndicator extends PanelMenu.Button {
    _init() {
        super._init(0.0, 'Mereoleona Timer', false);
        this._store = new TaskStore();
        this._store.load();
        this._tickId = 0;
        this._label = new St.Label({
            text: '⏱',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'mereo-timer-panel-label',
        });
        this.add_child(this._label);
        this.menu.connect('open-state-changed', (_m, open) => { if (open) this._refreshMenu(); });
        this._startTick();
    }

    destroy() { this._stopTick(); super.destroy(); }

    _startTick() {
        this._tickId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
            this._updateLabel();
            return GLib.SOURCE_CONTINUE;
        });
    }
    _stopTick() { if (this._tickId) { GLib.source_remove(this._tickId); this._tickId = 0; } }

    _updateLabel() {
        if (this._store.running) {
            this._label.set_text(`⏱ ${this._store.running.ticket}  ${fmtDuration(this._store.runningElapsed())}`);
        } else {
            this._label.set_text(this._store.paused.length ? `⏸ ${this._store.paused.length}` : '⏱');
        }
    }

    _refreshMenu() {
        this.menu.removeAll();
        this._store.load();

        if (this._store.running) {
            const t = this._store.running;
            const hdr = new PopupMenu.PopupMenuItem(`▶  ${t.ticket} — ${t.task}`, { reactive: false });
            hdr.label.add_style_class_name('mereo-timer-running-label');
            this.menu.addMenuItem(hdr);
            const timeItem = new PopupMenu.PopupMenuItem(`   ${fmtDuration(this._store.runningElapsed())}`, { reactive: false });
            timeItem.label.add_style_class_name('mereo-timer-elapsed');
            this.menu.addMenuItem(timeItem);
            this._addActionRow([
                { label: '⏸ Pause',    fn: () => { this._store.pause();        this._afterAction(); } },
                { label: '✓ Complete', fn: () => { this._store.complete(t.id); this._afterAction(); } },
                { label: '■ Stop',     fn: () => { this._store.stop(t.id);     this._afterAction(); } },
            ]);
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        }

        if (this._store.paused.length) {
            const ph = new PopupMenu.PopupMenuItem('Paused', { reactive: false });
            ph.label.add_style_class_name('mereo-timer-section-header');
            this.menu.addMenuItem(ph);
            for (const t of this._store.paused) {
                const row = new PopupMenu.PopupMenuItem(`⏸  ${t.ticket} — ${t.task}  (${fmtDuration(t.accSecs)})`, { reactive: false });
                this.menu.addMenuItem(row);
                const id = t.id;
                this._addActionRow([
                    { label: '▶ Resume',   fn: () => { this._store.resume(id);   this._afterAction(); } },
                    { label: '✓ Complete', fn: () => { this._store.complete(id); this._afterAction(); } },
                    { label: '■ Stop',     fn: () => { this._store.stop(id);     this._afterAction(); } },
                ]);
            }
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        }

        const newHdr = new PopupMenu.PopupMenuItem('New Task', { reactive: false });
        newHdr.label.add_style_class_name('mereo-timer-section-header');
        this.menu.addMenuItem(newHdr);

        const ticketItem = new PopupMenu.PopupBaseMenuItem({ reactive: false });
        const ticketEntry = new St.Entry({ style_class: 'mereo-timer-entry', hint_text: 'Ticket (e.g. PROJ-42)', can_focus: true, x_expand: true });
        ticketItem.add_child(ticketEntry);
        this.menu.addMenuItem(ticketItem);

        const taskItem = new PopupMenu.PopupBaseMenuItem({ reactive: false });
        const taskEntry = new St.Entry({ style_class: 'mereo-timer-entry', hint_text: 'Task description', can_focus: true, x_expand: true });
        taskItem.add_child(taskEntry);
        this.menu.addMenuItem(taskItem);

        const startItem = new PopupMenu.PopupMenuItem('▶  Start Task');
        startItem.label.add_style_class_name('mereo-timer-start-btn');
        startItem.connect('activate', () => {
            const ticket = ticketEntry.get_text().trim() || 'P';
            const task   = taskEntry.get_text().trim();
            if (!task) { Main.notify('Mereoleona Timer', 'Task description is required'); return; }
            this._store.start(ticket, task);
            this._afterAction();
        });
        this.menu.addMenuItem(startItem);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        const logItem = new PopupMenu.PopupMenuItem('📋  View Log / Export');
        logItem.connect('activate', () => { this.menu.close(); this._openLogWindow(); });
        this.menu.addMenuItem(logItem);
    }

    _addActionRow(actions) {
        const row = new PopupMenu.PopupBaseMenuItem({ reactive: false });
        const box = new St.BoxLayout({ x_expand: true, style_class: 'mereo-timer-action-row' });
        for (const a of actions) {
            const btn = new St.Button({ label: a.label, style_class: 'mereo-timer-action-btn', can_focus: true, reactive: true, x_expand: true });
            btn.connect('clicked', () => a.fn());
            box.add_child(btn);
        }
        row.add_child(box);
        this.menu.addMenuItem(row);
    }

    _afterAction() { this._updateLabel(); this._refreshMenu(); }

    _openLogWindow() {
        const log = readJSON(LOG_FILE, []);
        const win = new St.Widget({ style_class: 'mereo-timer-log-win', reactive: true, layout_manager: new Clutter.BinLayout() });
        const box = new St.BoxLayout({ style_class: 'mereo-timer-log-box', vertical: true, x_expand: true, y_expand: true });

        const hdr = new St.BoxLayout({ style_class: 'mereo-timer-log-header-row' });
        const titleLbl = new St.Label({ text: '📋  Task Log', style_class: 'mereo-timer-log-title', x_expand: true, y_align: Clutter.ActorAlign.CENTER });
        const closeBtn = new St.Button({ label: '✕', style_class: 'mereo-timer-log-close', can_focus: true, reactive: true });
        closeBtn.connect('clicked', () => win.destroy());
        hdr.add_child(titleLbl); hdr.add_child(closeBtn);
        box.add_child(hdr);

        const filterRow = new St.BoxLayout({ style_class: 'mereo-timer-log-filter-row' });
        const filterEntry = new St.Entry({ style_class: 'mereo-timer-entry', hint_text: 'Filter by date (YYYY-MM-DD) or ticket…', can_focus: true, x_expand: true });
        const exportBtn = new St.Button({ label: '⬇ Export', style_class: 'mereo-timer-action-btn', can_focus: true, reactive: true });
        filterRow.add_child(filterEntry); filterRow.add_child(exportBtn);
        box.add_child(filterRow);

        const tableHdr = new St.BoxLayout({ style_class: 'mereo-timer-table-hdr' });
        for (const [lbl, expand] of [['Date',false],['Ticket',false],['Task',true],['Duration',false],['Status',false]])
            tableHdr.add_child(new St.Label({ text: lbl, style_class: 'mereo-timer-table-hdr-cell', x_expand: expand }));
        box.add_child(tableHdr);

        const scroll = new St.ScrollView({ style_class: 'mereo-timer-scroll', x_expand: true, y_expand: true });
        const list   = new St.BoxLayout({ vertical: true, x_expand: true });
        scroll.set_child(list);
        box.add_child(scroll);

        const renderRows = (filter) => {
            list.destroy_all_children();
            const q = filter.toLowerCase().trim();
            const shown = q
                ? log.filter(e => e.date.includes(q) || e.ticket.toLowerCase().includes(q) || e.task.toLowerCase().includes(q))
                : [...log].reverse();
            if (!shown.length) { list.add_child(new St.Label({ text: 'No entries found.', style_class: 'mereo-timer-log-empty' })); return; }
            for (const e of shown) {
                const row = new St.BoxLayout({ style_class: 'mereo-timer-table-row' });
                for (const [txt, expand] of [[e.date,false],[e.ticket,false],[e.task,true],[fmtDuration(e.duration),false],[e.status,false]])
                    row.add_child(new St.Label({ text: txt, style_class: 'mereo-timer-table-cell', x_expand: expand }));
                list.add_child(row);
            }
        };
        filterEntry.get_clutter_text().connect('text-changed', () => renderRows(filterEntry.get_text()));

        exportBtn.connect('clicked', () => {
            const q = filterEntry.get_text().toLowerCase().trim();
            const rows = q ? log.filter(e => e.date.includes(q) || e.ticket.toLowerCase().includes(q) || e.task.toLowerCase().includes(q)) : [...log];
            if (!rows.length) { Main.notify('Mereoleona Timer', 'Nothing to export'); return; }
            const byDate = {};
            for (const e of rows) { if (!byDate[e.date]) byDate[e.date] = []; byDate[e.date].push(e); }
            let out = '';
            for (const date of Object.keys(byDate).sort()) {
                out += `\n── ${date} ──────────────────────────────────\n`;
                out += `${'Ticket'.padEnd(14)} : ${'Task'.padEnd(40)} : Duration\n`;
                out += `${'-'.repeat(14)}-+-${'-'.repeat(40)}-+-${'-'.repeat(8)}\n`;
                for (const e of byDate[date])
                    out += `${e.ticket.padEnd(14)} : ${e.task.padEnd(40)} : ${fmtDuration(e.duration)}\n`;
            }
            const exportPath = GLib.build_filenamev([DATA_DIR, `export-${today()}.txt`]);
            try {
                Gio.File.new_for_path(exportPath).replace_contents(
                    new TextEncoder().encode(out.trimStart()),
                    null, false, Gio.FileCreateFlags.REPLACE_DESTINATION, null
                );
                Main.notify('Mereoleona Timer', `Exported → ${exportPath}`);
            } catch (err) { Main.notifyError('Mereoleona Timer', String(err)); }
        });

        renderRows('');
        win.add_child(box);
        global.stage.add_child(win);
        const m = Main.layoutManager.primaryMonitor;
        win.set_size(Math.min(800, m.width - 80), Math.min(560, m.height - 100));
        win.set_position(m.x + Math.round((m.width - win.width) / 2), m.y + Math.round((m.height - win.height) / 2));
    }
}

export default class MereoleonaTimer extends Extension {
    enable() {
        this._indicator = new TimerIndicator();
        Main.panel.addToStatusArea('mereoleona-timer', this._indicator);
    }
    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
