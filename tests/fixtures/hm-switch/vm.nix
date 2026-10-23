# The VM tests/hm-switch.test drives: one user, max, whose systemd manager
# holds the `old` units, switched to the `new` ones by Home Manager's unit
# switcher. Each backup adds its name to ~/runs and sleeps for the seconds in
# ~/seconds/<unit name>, one by default.
{ nixpkgs, old, new }:
let
  pkgs = import nixpkgs { system = "x86_64-linux"; };
  lib = pkgs.lib;
  backups = map (lib.removePrefix "Wants=")
    (builtins.filter (lib.hasPrefix "Wants=")
      (lib.splitString "\n" (builtins.readFile (new + "/backup-catchup.target"))));
in
pkgs.testers.runNixOSTest {
  name = "hm-switch";
  nodes.machine = {
    users.users.max = { isNormalUser = true; uid = 1000; linger = true; };
    environment.systemPackages = [ pkgs.sd-switch ];
  };
  testScript = ''
    import json

    backups = json.loads('${builtins.toJSON backups}')
    running = backups[0]
    seconds = "/home/max/seconds/" + running.removesuffix(".service")
    units = "/home/max/.config/systemd/user"

    def user(cmd):
        return machine.succeed(
            "runuser -u max -- env XDG_RUNTIME_DIR=/run/user/1000"
            f" DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus {cmd}"
        )

    def runs():
        names = user("sh -c 'touch /home/max/runs; cat /home/max/runs'").split()
        return {b: names.count(b.removesuffix(".service")) for b in backups}

    machine.wait_for_unit("user@1000.service")
    user(f"mkdir -p {units} /home/max/seconds")
    user(f"cp ${old}/. {units}/ -r")
    user("systemctl --user daemon-reload")

    with subtest("a login's catch-up runs every backup"):
        user("systemctl --user start backup-catchup.target")
        ran = runs()
        assert all(n == 1 for n in ran.values()), ran

    user(f"sh -c 'echo 600 > {seconds}'")
    user(f"systemctl --user start --no-block {running}")
    machine.wait_until_succeeds(
        "runuser -u max -- env XDG_RUNTIME_DIR=/run/user/1000"
        f" systemctl --user show -P ActiveState {running} | grep -qx activating"
    )
    before = runs()

    with subtest("a switch while a backup runs finishes and starts no backup"):
        user(f"cp -rf ${new}/. {units}/")
        status, out = machine.execute(
            "runuser -u max -- env XDG_RUNTIME_DIR=/run/user/1000"
            " DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
            " timeout 120 sd-switch --verbose --timeout 60000"
            " --old-units ${old} --new-units ${new} 2>&1"
        )
        print(out)
        assert status == 0, f"sd-switch exited {status}"
        assert runs() == before, (before, runs())
        state = user(f"systemctl --user show -P ActiveState {running}").strip()
        assert state == "activating", f"{running} is {state}, not still running"

    with subtest("a catch-up after the switch runs every backup"):
        user(f"systemctl --user stop {running}")
        user(f"rm {seconds}")
        user("systemctl --user start backup-catchup.target")
        after = runs()
        assert all(after[b] == before[b] + 1 for b in backups), (before, after)
  '';
}
