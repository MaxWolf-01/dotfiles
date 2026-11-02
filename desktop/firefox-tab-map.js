// Which Firefox process serves which site and tabs, for bin/proc-load: once a
// minute, appended as one line to ~/.local/state/proc-load/firefox/<date>.jsonl
// when it differs from the line before. It is what about:processes shows,
// without the CPU figures, which proc-load reads from /proc itself.
//
// Firefox runs this at startup with full privileges (autoconfig, appended to
// mozilla.cfg by the Nix wrapper). Everything is caught: an exception escaping
// here would put up an error dialog at every launch. It writes nothing until
// the directory exists, which `proc-load record` creates.
(function firefoxTabMap() {
  try {
    const { classes: Cc, interfaces: Ci } = Components;
    const home = Cc["@mozilla.org/file/directory_service;1"]
      .getService(Ci.nsIProperties)
      .get("Home", Ci.nsIFile).path;
    const dir = home + "/.local/state/proc-load/firefox";
    const pad = (n) => String(n).padStart(2, "0");
    const short = (uri) => (uri ? uri.spec.split(/[?#]/)[0].slice(0, 200) : "");
    let last = "";

    function append(name, line) {
      const file = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
      file.initWithPath(dir);
      if (!file.exists()) return;
      file.append(name);
      const out = Cc["@mozilla.org/network/file-output-stream;1"].createInstance(Ci.nsIFileOutputStream);
      out.init(file, 0x02 | 0x08 | 0x10, 0o644, 0); // write, create, append
      const text = Cc["@mozilla.org/intl/converter-output-stream;1"].createInstance(Ci.nsIConverterOutputStream);
      text.init(out, "UTF-8");
      text.writeString(line);
      text.close();
    }

    async function sample() {
      const info = await ChromeUtils.requestProcInfo();
      const procs = info.children.map((child) => ({
        pid: child.pid,
        type: child.type,
        origin: child.origin,
        tabs: child.windows.map((w) => [w.documentTitle, short(w.documentURI)]),
      }));
      const now = new Date();
      const day = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
      const body = JSON.stringify({ parent: info.pid, procs });
      // A new day's file gets a line even when nothing changed, so each file stands alone.
      if (day + body === last) return;
      last = day + body;
      append(`${day}.jsonl`, `{"t":${Math.floor(now / 1000)},${body.slice(1)}\n`);
    }

    const timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
    timer.initWithCallback(
      { notify: () => sample().catch(() => {}) },
      60000,
      Ci.nsITimer.TYPE_REPEATING_SLACK,
    );
    globalThis.firefoxTabMapTimer = timer;
  } catch (e) {}
})();
