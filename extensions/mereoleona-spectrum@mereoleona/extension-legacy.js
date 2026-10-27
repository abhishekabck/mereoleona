// mereoleona-spectrum — GNOME 42-44 legacy (old-style imports)
/* global imports */
const { St, GLib, Gio, Clutter } = imports.gi;
const Main = imports.ui.main;

const BARS = [' ', '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'];

let _box    = null;
let _label  = null;
let _proc   = null;
let _stream = null;
let _cancel = null;
let _posId  = 0;

function init() {} // eslint-disable-line no-unused-vars

function enable() { // eslint-disable-line no-unused-vars
    _cancel = new Gio.Cancellable();
    _box = new St.BoxLayout({ style_class: 'mereoleona-spectrum-box', y_align: Clutter.ActorAlign.CENTER, reactive: false });
    _label = new St.Label({ text: '▁▁▁▁▁', y_align: Clutter.ActorAlign.CENTER, style_class: 'mereoleona-spectrum' });
    _box.add_child(_label);
    Main.panel._leftBox.add_child(_box);
    _posId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1500, () => {
        _posId = 0;
        if (_box && _box.get_parent() === Main.panel._leftBox) {
            const lb = Main.panel._leftBox;
            lb.set_child_at_index(_box, lb.get_n_children() - 1);
        }
        return GLib.SOURCE_REMOVE;
    });
    _startCava();
}

function _startCava() {
    const cfg = GLib.build_filenamev([GLib.get_home_dir(), '.mereoleona', 'music', 'cava-bar-config']);
    try {
        _proc = Gio.Subprocess.new(['cava', '-p', cfg], Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE);
    } catch (e) {
        if (_label) _label.set_text('♪');
        return;
    }
    _stream = new Gio.DataInputStream({ base_stream: _proc.get_stdout_pipe() });
    _read();
}

function _read() {
    if (!_stream) return;
    _stream.read_line_async(GLib.PRIORITY_DEFAULT_IDLE, _cancel, (stream, res) => {
        let line = null;
        try { [line] = stream.read_line_finish_utf8(res); } catch (e) { return; }
        if (line === null) return;
        _render(line);
        _read();
    });
}

function _render(line) {
    const parts = line.split(';');
    let out = '';
    for (let i = 0; i < parts.length; i++) {
        if (parts[i] === '') continue;
        let n = parseInt(parts[i], 10);
        if (isNaN(n) || n < 0) n = 0;
        if (n > 8) n = 8;
        out += BARS[n];
    }
    if (out && _label) _label.set_text(out);
}

function disable() { // eslint-disable-line no-unused-vars
    if (_posId) { GLib.Source.remove(_posId); _posId = 0; }
    if (_cancel) { _cancel.cancel(); _cancel = null; }
    if (_proc) { try { _proc.force_exit(); } catch (e) {} _proc = null; }
    _stream = null;
    if (_box) { _box.destroy(); _box = null; }
    _label = null;
}
