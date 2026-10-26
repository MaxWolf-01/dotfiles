# The unprivileged users dispatch workers run as (/mx:dispatch), one per Claude
# account: `agent` on the personal account, `agent-hl` on the Helferline one.
#
# Workers here run with permission prompts bypassed, so the unix user is the
# only boundary between a worker and the rest of the machine: no read access to
# max's home or anything mounted inside it (pc's HDD pool), none to the other
# worker's home (both are mode 700, the NixOS default), no wheel, no sudo, no
# docker group, no outgoing tailnet. Two users rather than two config dirs
# under one user because the Helferline account is shared with a whole team: a
# session on it must not be able to read the personal account's transcripts,
# worktrees or plugin cache. A home boundary covers exactly what is inside a
# home; dispatch's scratch dir and worker logs under /tmp are outside it.
#
# A function of what differs between the hosts that import it:
#   memoryMax        the memory every user's sessions share (below)
#   sessionsReserve  how much of it max's sessions are protected up to (below)
#   slots            how many dispatched runs the machine holds at once,
#                    whichever worker user runs them
#   dispatcherKeys   the public key of each machine that dispatches to the
#                    workers. Without its key a machine gets "Permission denied
#                    (publickey)" from these users, and `worker-hosts` shows
#                    that message in place of the host's state.
{ memoryMax, sessionsReserve, slots, dispatcherKeys }:
{ pkgs, lib, ... }:

let
  # Fixed uids so each rootless docker socket path is known at build time (the
  # home-manager config points DOCKER_HOST at /run/user/<uid>).
  workers = {
    agent = { uid = 1001; description = "dispatch workers"; };
    agent-hl = { uid = 1002; description = "dispatch workers, Helferline account"; };
  };
  names = lib.attrNames workers;
  # max's uid, pinned so the slice sessionsReserve protects keeps its name.
  maxUid = 1000;

  host-slots = pkgs.runCommand "host-slots" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    install -Dm755 ${../../bin/host-slots} $out/bin/host-slots
    patchShebangs $out/bin/host-slots
    wrapProgram $out/bin/host-slots --set HOST_SLOTS ${toString slots} \
      --prefix PATH : ${lib.makeBinPath (with pkgs; [ coreutils gnugrep util-linux ])}
  '';

  # Tailscale ACLs are per-node and cannot separate unix users, so the tailnet
  # boundary is drawn by uid instead. The firewall's reload script re-runs
  # extraCommands, so every rule needs a delete in exactly the shape it was
  # added -- otherwise each rebuild leaves another copy behind.
  # ip46tables covers v4 and v6: tailscale is dual-stack and nothing mirrors
  # v4 rules to v6 by itself.
  tailnetRules = lib.concatMap (name: [
    # Inbound ssh is answered by sshd's session process, which runs as the
    # worker user -- so its reply packets carry that uid. Without this exemption
    # the reject below kills dispatch's own connection.
    "OUTPUT -o tailscale0 -m owner --uid-owner ${name} -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
    # REJECT rather than DROP: a blocked worker fails immediately instead of
    # hanging until some timeout.
    "OUTPUT -o tailscale0 -m owner --uid-owner ${name} -j REJECT"
  ]) names;
in
{
  users.users = lib.mkMerge [
    (lib.mapAttrs (name: w: {
      isNormalUser = true;
      inherit (w) uid description;
      group = name;
      shell = pkgs.zsh;
      # Without lingering, the user's tmux server dies with its last session and
      # takes every worker in it along.
      linger = true;
      openssh.authorizedKeys.keys = dispatcherKeys;
    }) workers)
    {
      # rwx------ on /home/max. The workers are in no group of max's and there
      # are no ACLs, so this directory mode is the only thing that denies them
      # /home/max, and with it whatever mounts inside it, pc's pool among them.
      # 700 is already the NixOS default for normal users; it is pinned here so
      # the boundary does not depend on that default staying put.
      max.homeMode = "700";
      max.uid = maxUid;
    }
  ];
  users.groups = lib.mapAttrs (_: w: { gid = w.uid; }) workers;

  # The memory every user's sessions share: logind parents each user's slice
  # to user.slice, max's included, and what is left above memoryMax is the
  # system's. Within it max's slice is protected up to sessionsReserve, so
  # reclaim takes the workers' memory first, and the workers together hold
  # memoryMax less what max's sessions use, any one worker all of it. At the
  # ceiling the OOM killer ranks by size plus oom_score_adj, in
  # thousandths of the ceiling; the workers' 500 puts them before max's
  # processes (200 or less) up to 30% of the ceiling larger, 3 GiB on pc's
  # 10G. No swap: a swapping cgroup stalls the host long before the killer
  # acts.
  systemd.slices.user.sliceConfig = {
    MemoryMax = memoryMax;
    MemorySwapMax = 0;
  };
  # A drop-in on the slice logind makes from user-.slice, named by uid.
  systemd.slices."user-${toString maxUid}" = {
    overrideStrategy = "asDropin";
    sliceConfig.MemoryLow = sessionsReserve;
  };

  # The slots (`host-slots --help`), in a directory every worker user shares.
  # Only the workers take slots, so only they get the tool.
  home-manager.users = lib.genAttrs names (_: { home.packages = [ host-slots ]; });
  systemd.tmpfiles.rules = [
    "d /run/host-slots 1777 root root -"
    "f /run/host-slots/lock 0644 root root -"
  ];

  # Rootless docker, for the workers alone. Two things about the upstream module
  # make "just enable it" wrong here: its user service is wantedBy every
  # non-root user's default.target, and `setSocketVariable` exports DOCKER_HOST
  # from /etc/profile for everyone -- which would silently move max's docker CLI
  # off the system daemon onto a rootless one of his own. So the socket variable
  # is set in the workers' home-manager config instead of globally, and the
  # daemon is pinned to the users who run containers unsupervised: `|` makes
  # these triggering conditions, of which one has to hold.
  virtualisation.docker.rootless.enable = true;
  systemd.user.services.docker.unitConfig.ConditionUser = lib.mkForce (map (name: "|${name}") names);
  # Its containers inherit this, as ssh-started processes inherit the same
  # value from nix/home/worker.nix.
  systemd.user.services.docker.serviceConfig.OOMScoreAdjust = 500;

  # The uid rules above only see packets the workers' own processes send.
  # tailscaled originates its own as root, and its control socket is world
  # readable -- which hands any local user the full tailnet inventory and
  # `tailscale ping` to any node. Mutations are already gated in-process to
  # root and the host's --operator, if it names one, so what leaks is
  # disclosure and a probe, not control.
  # Closing the directory rather than the socket keeps that operator access
  # working: max is in wheel, the workers are in no group but their own. systemd
  # recreates this directory on every start, so the mode belongs on the unit
  # rather than in tmpfiles.
  systemd.services.tailscaled.serviceConfig = {
    RuntimeDirectoryMode = lib.mkForce "0750";
    ExecStartPost = [ "${pkgs.coreutils}/bin/chgrp wheel /run/tailscale" ];
  };

  networking.firewall = {
    extraCommands = lib.concatMapStringsSep "\n" (rule: "ip46tables -A ${rule}") tailnetRules;
    extraStopCommands = lib.concatMapStringsSep "\n" (rule: "ip46tables -D ${rule} || true") tailnetRules;
  };
}
