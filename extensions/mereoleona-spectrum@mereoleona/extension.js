import St from 'gi://St';
import GLib from 'gi://GLib';
import Gio from 'gi://Gio';
import Clutter from 'gi://Clutter';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

// index 0..8 -> rising block characters (0 = quiet)
const BARS = [' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'];

export default class MereoleonaSpectrum extends Extension {
    enable() {
        this._cancel = new Gio.Cancellable();

        this._box = new St.BoxLayout({
            style_class: 'mereoleona-spectrum-box',
            y_align: Clutter.ActorAlign.CENTER,
            reactive: false,
        });
        this._label = new St.Label({
            text: '▁▁▁▁▁',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'mereoleona-spectrum',
        });
        this._box.add_child(this._label);

        // append to the LEFT box so we land after Activities + Workspaces
        Main.panel._leftBox.add_child(this._box);
        // re-assert "last in the left box" once other extensions finish loading
        this._posId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1500, () => {
            this._posId = 0;
            if (this._box && this._box.get_parent() === Main.panel._leftBox) {
                const lb = Main.panel._leftBox;
                lb.set_child_at_index(this._box, lb.get_n_children() - 1);
            }
            return GLib.SOURCE_REMOVE;
        });

        this._startCava();
    }

    _startCava() {
        const cfg = GLib.build_filenamev([GLib.get_home_dir(), '.mereoleona', 'music', 'cava-bar-config']);
        try {
            this._proc = Gio.Subprocess.new(
                ['cava', '-p', cfg],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE
            );
        } catch (e) {
            if (this._label) this._label.set_text('♪');   // ♪ — cava missing
            return;
        }
        this._stream = new Gio.DataInputStream({base_stream: this._proc.get_stdout_pipe()});
        this._read();
    }

    _read() {
        if (!this._stream) return;
        this._stream.read_line_async(GLib.PRIORITY_DEFAULT_IDLE, this._cancel, (stream, res) => {
            let line = null;
            try {
                [line] = stream.read_line_finish_utf8(res);
            } catch (e) {
                return;
            }
            if (line === null) return;          // EOF / cancelled
            this._render(line);
            this._read();
        });
    }

    _render(line) {
        const parts = line.split(';');
        let out = '';
        for (let i = 0; i < parts.length; i++) {
            if (parts[i] === '') continue;
            let n = parseInt(parts[i], 10);
            if (isNaN(n) || n < 0) n = 0;
            if (n > 8) n = 8;
            out += BARS[n];
        }
        if (out && this._label) this._label.set_text(out);
    }

    disable() {
        if (this._posId) { GLib.Source.remove(this._posId); this._posId = 0; }
        if (this._cancel) { this._cancel.cancel(); this._cancel = null; }
        if (this._proc) { try { this._proc.force_exit(); } catch (e) {} this._proc = null; }
        this._stream = null;
        if (this._box) { this._box.destroy(); this._box = null; }
        this._label = null;
    }
}
