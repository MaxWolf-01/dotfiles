// The update dot: a flake lock bump that waits for max, coloured by the
// rating `update-review run` gave it (`update-review --help` has the levels
// and the state file's fields). Hidden while nothing waits; a click opens the
// report.
import Clutter from 'gi://Clutter';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';

const STATE_FILE = GLib.build_filenamev([GLib.get_user_state_dir(), 'update-review', 'state.json']);
const LEVELS = ['routine', 'promising', 'critical', 'held'];
const SHOW = [GLib.build_filenamev([GLib.get_home_dir(), 'bin', 'update-review']), 'show'];

const Dot = GObject.registerClass(
class Dot extends PanelMenu.Button {
    _init() {
        super._init(0.5, 'Updates', true);
        this._dot = new St.Widget({style_class: 'update-dot', y_align: Clutter.ActorAlign.CENTER});
        this.add_child(this._dot);

        this._label = new St.Label({style_class: 'dash-label update-dot-label'});
        this._label.hide();
        Main.layoutManager.addChrome(this._label);
        this.connect('notify::hover', () => this._updateLabel());

        const click = new Clutter.ClickGesture();
        click.connect('recognize', () => this._open());
        this.add_action(click);

        this._cancellable = new Gio.Cancellable();
        this._file = Gio.File.new_for_path(STATE_FILE);
        this._monitor = this._file.monitor_file(Gio.FileMonitorFlags.NONE, null);
        this._monitor.connect('changed', () => this._read());
        this._shown = null;
        this._read();
    }

    // No file, or one that does not parse, is nothing waiting.
    _read() {
        this._file.load_contents_async(this._cancellable, (file, result) => {
            try {
                const [, bytes] = file.load_contents_finish(result);
                this._show(JSON.parse(new TextDecoder().decode(bytes)));
            } catch (e) {
                if (e.matches?.(Gio.IOErrorEnum, Gio.IOErrorEnum.CANCELLED))
                    return;
                this._show(null);
            }
        });
    }

    _show(shown) {
        this._shown = shown;
        const level = LEVELS.includes(shown?.level) ? shown.level : null;
        this.visible = level !== null;
        this._dot.style_class = level ? `update-dot update-dot-${level}` : 'update-dot';
        this._updateLabel();
    }

    _open() {
        try {
            Gio.Subprocess.new(SHOW, Gio.SubprocessFlags.NONE);
        } catch (e) {
            Main.notify('Updates', `${SHOW.join(' ')}: ${e.message}`);
        }
    }

    _updateLabel() {
        if (!this.hover || !this._shown) {
            this._label.hide();
            return;
        }
        const {level, headline, date} = this._shown;
        this._label.text = `${level} bump of ${date}\n${headline}\nclick for the report; update-review apply applies it`;
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

export default class UpdateDotExtension extends Extension {
    enable() {
        this._dot = new Dot();
        Main.panel.addToStatusArea(this.uuid, this._dot, 0, 'right');
    }

    disable() {
        this._dot.destroy();
        this._dot = null;
    }
}
