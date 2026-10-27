# Runs tests/cold-backup.test as root in a throwaway NixOS VM with ZFS, for a
# host that has neither, or no root to give it. Run it by hand when bin/cold-backup
# changes, from the checkout to test:
#
#   nix build --impure -L --no-link -f tests/cold-backup-vm.nix
#
# It needs KVM (/dev/kvm writable) and takes about 4 minutes. It belongs to no
# test tier: make's tiers run *.test files only. The build fails unless the
# test exits 0; -L prints the test's lines.
#
# The VM gets the checkout's working tree, uncommitted edits included, and the
# nixpkgs its flake.lock pins.
let
  checkout = ./..;
  flake = builtins.getFlake "git+file://${toString checkout}";
  pkgs = flake.inputs.nixpkgs.legacyPackages.x86_64-linux;
  lib = pkgs.lib;
  src = lib.fileset.toSource {
    root = checkout;
    fileset = lib.fileset.unions [
      ../bin/cold-backup
      ../bin/run-log
      ./check.sh
      ./cold-backup.test
    ];
  };
in
pkgs.testers.runNixOSTest {
  name = "cold-backup";
  nodes.machine = { pkgs, ... }: {
    boot.supportedFilesystems = [ "zfs" ];
    networking.hostId = "deadbeef";
    virtualisation.memorySize = 2048;
    virtualisation.diskSize = 4096;
    # The test runs as root, as sudo would start it; run-log and the bundles
    # run as the user it names.
    users.users.max.isNormalUser = true;
    environment.systemPackages = with pkgs; [ jq git age util-linux ];
  };
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("cp -r ${src} /src && chmod -R u+w /src")
    out = machine.succeed("cd /tmp && SUDO_USER=max bash /src/tests/cold-backup.test 2>&1; echo exit=$?")
    print(out)
    assert "exit=0" in out, out
  '';
}
