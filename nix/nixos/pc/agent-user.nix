# The unprivileged user dispatch workers run as (/mx:dispatch).
#
# Workers here run with permission prompts bypassed, so this user's boundary is
# the only thing between a worker and the rest of the machine: no read access to
# max's home or the HDD pool mounted inside it, no wheel, no sudo, no docker
# group, no outgoing tailnet.
{ pkgs, lib, ... }:

let
  # Fixed so the rootless docker socket path is known at build time (the agent's
  # home-manager config points DOCKER_HOST at /run/user/<uid>).
  agentUid = 1001;

  # Tailscale ACLs are per-node and cannot separate unix users, so the tailnet
  # boundary is drawn by uid instead. The firewall's reload script re-runs
  # extraCommands, so every rule needs a delete in exactly the shape it was
  # added -- otherwise each rebuild leaves another copy behind.
  # ip46tables covers v4 and v6: tailscale is dual-stack and nothing mirrors
  # v4 rules to v6 by itself.
  agentTailnetRules = [
    # Inbound ssh is answered by sshd's session process, which runs as the
    # agent -- so its reply packets carry that uid. Without this exemption the
    # reject below kills dispatch's own connection.
    "OUTPUT -o tailscale0 -m owner --uid-owner agent -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"
    # REJECT rather than DROP: a blocked worker fails immediately instead of
    # hanging until some timeout.
    "OUTPUT -o tailscale0 -m owner --uid-owner agent -j REJECT"
  ];
in
{
  users.users.agent = {
    isNormalUser = true;
    description = "dispatch workers";
    uid = agentUid;
    group = "agent";
    shell = pkgs.zsh;
    # Without lingering, the user's tmux server dies with its last session and
    # takes every worker in it along.
    linger = true;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyy5xWC5my4ZPkc7mUEPKi/SfqdUEeq12pMKo5D/D4p" # zephyrus
    ];
  };
  users.groups.agent.gid = agentUid;

  # The agent is kept out of max's data by this mode and nothing else -- the
  # pool's datasets mount inside that directory, so it covers them too. It is
  # the default, but the boundary above should not rest on a default staying
  # put.
  users.users.max.homeMode = "700";

  # Rootless docker, for the agent alone. Two things about the upstream module
  # make "just enable it" wrong here: its user service is wantedBy every
  # non-root user's default.target, and `setSocketVariable` exports DOCKER_HOST
  # from /etc/profile for everyone -- which would silently move max's docker CLI
  # off the system daemon onto a rootless one of his own. So the socket variable
  # is set in the agent's home-manager config instead of globally, and the
  # daemon is pinned to the one user who runs containers unsupervised.
  virtualisation.docker.rootless.enable = true;
  systemd.user.services.docker.unitConfig.ConditionUser = lib.mkForce "agent";

  # The uid rule above only sees packets the agent's own processes send.
  # tailscaled originates its own as root, and its control socket is world
  # readable -- which hands any local user the full tailnet inventory and
  # `tailscale ping` to any node. Mutations are already gated in-process by
  # --operator=max, so what leaks is disclosure and a probe, not control.
  # Closing the directory rather than the socket keeps that operator access
  # working: max is in wheel, the agent is in no group but its own. systemd
  # recreates this directory on every start, so the mode belongs on the unit
  # rather than in tmpfiles.
  systemd.services.tailscaled.serviceConfig = {
    RuntimeDirectoryMode = lib.mkForce "0750";
    ExecStartPost = [ "${pkgs.coreutils}/bin/chgrp wheel /run/tailscale" ];
  };

  networking.firewall = {
    extraCommands = lib.concatMapStringsSep "\n" (rule: "ip46tables -A ${rule}") agentTailnetRules;
    extraStopCommands = lib.concatMapStringsSep "\n" (rule: "ip46tables -D ${rule} || true") agentTailnetRules;
  };
}
