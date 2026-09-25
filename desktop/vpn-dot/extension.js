// The VPN dot: shows the state `vpn watch` publishes (`vpn watch --help` has
// the states and the file's fields), and switches the exit node on and off
// when clicked.
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

const STATE_FILE = GLib.build_filenamev([GLib.get_user_runtime_dir(), 'vpn-state.json']);
const STATES = ['up', 'down', 'off', 'unknown'];
// The unit deletes the file when the watcher stops.
const NOT_RUNNING = {state: 'unknown', reason: 'vpn-watch is not running'};

const ON = [GLib.build_filenamev([GLib.get_home_dir(), 'bin', 'vpn']), 'on'];
// A bare tailscale, not `vpn off`: turning the VPN off has to work when uv,
// DNS and the tunnel are all gone.
const OFF = ['tailscale', 'set', '--exit-node='];

const Dot = GObject.registerClass(
class Dot extends PanelMenu.Button {
    _init() {
        super._init(0.5, 'VPN', true);
        this._dot = new St.Widget({style_class: 'vpn-dot', y_align: Clutter.ActorAlign.CENTER});
        this.add_child(this._dot);

        this._label = new St.Label({style_class: 'dash-label vpn-dot-label'});
        this._label.hide();
        Main.layoutManager.addChrome(this._label);
        this.connect('notify::hover', () => this._updateLabel());

        const click = new Clutter.ClickGesture();
        click.connect('recognize', () => this._toggle());
        this.add_action(click);

        this._cancellable = new Gio.Cancellable();
        this._file = Gio.File.new_for_path(STATE_FILE);
        this._monitor = this._file.monitor_file(Gio.FileMonitorFlags.NONE, null);
        this._monitor.connect('changed', () => this._read());
        this._shown = NOT_RUNNING;
        this._running = null;
        this._read();
    }

    _read() {
        this._file.load_contents_async(this._cancellable, (file, result) => {
            try {
                const [, bytes] = file.load_contents_finish(result);
                this._show(JSON.parse(new TextDecoder().decode(bytes)));
            } catch (e) {
                if (e.matches?.(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                    return;
                this._show(NOT_RUNNING);
            }
        });
    }

    _show(shown) {
        this._shown = shown;
        const state = STATES.includes(shown.state) ? shown.state : 'unknown';
        this._dot.style_class = `vpn-dot vpn-dot-${state}`;
        this._updateLabel();
    }

    // A click while the dot's own `vpn on` runs turns the VPN off: that move
    // stops once it sees the exit node gone, and its failure goes unreported.
    _toggle() {
        const {state} = this._shown;
        if (this._running?.argv === ON || (!this._running && ['up', 'down'].includes(state)))
            this._run(OFF, 'turning off');
        else if (!this._running && state === 'off')
            this._run(ON, 'turning on');
    }

    _run(argv, doing) {
        let proc;
        try {
            proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_MERGE);
        } catch (e) {
            Main.notify('VPN', `${argv.join(' ')}: ${e.message}`);
            return;
        }
        const run = {argv, doing};
        this._running = run;
        this._pulse(true);
        this._updateLabel();
        proc.communicate_utf8_async(null, this._cancellable, (p, result) => {
            let output = '';
            try {
                [, output] = p.communicate_utf8_finish(result);
            } catch (e) {
                if (e.matches?.(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                    return;
                output = e.message;
            }
            if (this._running !== run)
                return;
            this._running = null;
            this._pulse(false);
            this._updateLabel();
            if (!p.get_successful()) {
                const last = output.trim().split('\n').pop();
                Main.notify('VPN', last || `${argv.join(' ')} failed`);
            } else if (argv === OFF) {
                // The watcher publishes the change about a second later. A
                // dot still green for that second invites another click, which
                // lands once the file says "off" and turns the VPN back on.
                this._show({state: 'off', reason: '', mode: 'off', since: new Date().toISOString()});
            }
        });
    }

    _pulse(on) {
        this._dot.remove_all_transitions();
        this._dot.opacity = 255;
        if (on) {
            this._dot.ease({
                opacity: 70,
                duration: 700,
                mode: Clutter.AnimationMode.EASE_IN_OUT_SINE,
                autoReverse: true,
                repeatCount: -1,
            });
        }
    }

    _updateLabel() {
        if (!this.hover) {
            this._label.hide();
            return;
        }
        this._label.text = describe(this._shown, this._running?.doing);
        this._label.show();
        const [x, y] = this.get_transformed_position();
        const [width, height] = this.get_transformed_size();
        const labelX = Math.floor(x + (width - this._label.width) / 2);
        this._label.set_position(
            Math.clamp(labelX, 0, global.stage.width - this._label.width),
            Math.floor(y + height + 4));
    }

    _onDestroy() {
        this._cancellable.cancel();
        this._monitor.cancel();
        this._label.destroy();
        super._onDestroy();
    }
});

const MODES = {
    automatic: 'automatic (Tailscale picks the node by latency)',
    pinned: 'pinned (stays on this node)',
};

function describe({state, reason, mode, node, city, country, since}, running) {
    const age = since ? ` for ${ago(Date.parse(since))}` : '';
    const lines = [`${state}${age}${reason ? `: ${reason}` : ''}`];
    if (node) {
        lines.push(`node: ${node}`);
        const place = [city, country].filter(Boolean).join(', ');
        if (place)
            lines.push(`location: ${place}`);
        lines.push(`mode: ${MODES[mode] ?? mode}`);
    }
    if (running)
        lines.push(`${running}…`);
    return lines.join('\n');
}

function ago(then) {
    const secs = Math.max(0, Math.round((Date.now() - then) / 1000));
    if (secs < 60)
        return `${secs} s`;
    const mins = Math.floor(secs / 60);
    if (mins < 60)
        return `${mins} min`;
    const hours = Math.floor(mins / 60);
    if (hours < 24)
        return mins % 60 ? `${hours} h ${mins % 60} min` : `${hours} h`;
    return `${Math.floor(hours / 24)} d`;
}

export default class VpnDotExtension extends Extension {
    enable() {
        this._dot = new Dot();
        Main.panel.addToStatusArea(this.uuid, this._dot, 0, 'right');
    }

    disable() {
        this._dot.destroy();
        this._dot = null;
    }
}
