# host-slots (`host-slots --help`) with a machine's slot count, and where its
# slots are not in /run/host-slots, the directory they are in: shell text,
# expanded each time it runs, so it can name the runtime directory of whoever
# runs it.
{ pkgs, lib, slots, dir ? null }:
pkgs.runCommand "host-slots" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  install -Dm755 ${./host-slots} $out/bin/host-slots
  patchShebangs $out/bin/host-slots
  wrapProgram $out/bin/host-slots --set HOST_SLOTS ${toString slots} \
    ${lib.optionalString (dir != null) "--run ${lib.escapeShellArg "export HOST_SLOTS_DIR=${dir}"}"} \
    --prefix PATH : ${lib.makeBinPath (with pkgs; [ coreutils gnugrep util-linux ])}
''
