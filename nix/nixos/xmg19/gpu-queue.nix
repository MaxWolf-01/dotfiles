# The GPU queue (bin/gpu-queue): gpu-run and gpu-queue on every user's PATH,
# the worker users' included, whose homes cannot see max's ~/bin, and the
# directory every user's jobs queue in.
{ pkgs, lib, ... }:

let
  # One script under two names, which it tells apart by the name it was
  # called by: two copies, since the wrapper runs each under a name of its
  # own. The tools go after the caller's PATH, which the queued command runs
  # with, so a project's own shell still comes first.
  gpu-queue = pkgs.runCommand "gpu-queue" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    for name in gpu-queue gpu-run; do
      install -Dm755 ${../../../bin/gpu-queue} $out/bin/$name
      patchShebangs $out/bin/$name
      wrapProgram $out/bin/$name --suffix PATH : ${lib.makeBinPath (with pkgs; [ coreutils findutils gnused jq util-linux ])}
    done
  '';
in
{
  environment.systemPackages = [ gpu-queue ];

  # Sticky, as /tmp is: every user adds entries, and removes only their own.
  # Under /run, so a boot, which has ended every job, starts with it empty.
  systemd.tmpfiles.rules = [
    "d /run/gpu-queue 1777 root root -"
    "f /run/gpu-queue/.lock 0644 root root -"
  ];
}
