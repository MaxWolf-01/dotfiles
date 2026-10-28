# The machines: every host max runs, and the dispatch worker users on each, in
# the one list below. Home Manager writes it out as ~/.config/machines.json,
# which the host tools in bin/ read; MACHINES_FILE points them at another copy.
# A machine the host tools learn of is an entry here. What a host needs beyond
# that stays where it was: its ssh alias in ./common.nix, and for a NixOS host
# its config in the flake, with a Home Manager config per worker user
# (./hosts/<host>-<user>.nix) and the hand-written half of that user's record,
# ./hosts/<host>-<user>/HOST.md, whose frontmatter this module writes.
#
# The hosts that run max's sessions (`sessions`) each run a container hub, and
# each one's hub relays every other trusted as much as it or less
# (./container-hub.nix), since relaying one means holding max's ssh login to
# it; a host is never handed a login to one it trusts more. The session copies
# follow the same rule (./session-copies.nix). hub.mwolf.dev
# (bin/container-hub-address) tries their hubs in the list's order and opens
# the first that answers, so the host up the most comes first.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  worker = types.submodule {
    options = {
      user = mkOption {
        type = types.str;
        description = "The worker user's login; user@<machine> is its ssh destination and its name.";
      };
      account = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          The Claude account its claude is logged into. A user with none (max on
          the laptop) runs a worker on the dispatcher's own profile, so it takes
          a spawn on any account, but only from a dispatcher on that machine.'';
      };
      isolated = mkOption {
        type = types.bool;
        description = "Whether a worker here is kept from the rest of the machine, by a user of its own.";
      };
      has = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Capabilities a spawn may ask for that no probe reads off the machine.";
      };
      withholds = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Capabilities placement must not offer by itself, though the machine has them.";
      };
      placement = mkOption {
        type = types.nullOr (types.enum [ "last" ]);
        default = null;
        description = "`last`: chosen only when no other host can take the spawn.";
      };
    };
  };

  # One step of an unlock: a command run on the machine over ssh, handed a
  # secret on stdin, or the age key, or nothing.
  step = types.submodule {
    options = {
      run = mkOption {
        type = types.listOf types.str;
        description = "The command, run on the machine as max.";
      };
      secret = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The secret it reads on stdin, by its name in secrets/creds/raw/.";
      };
      ageKey = mkOption {
        type = types.bool;
        default = false;
        description = "Whether it reads the age key on stdin, from SOPS_AGE_KEY_FILE.";
      };
    };
  };

  machine = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "The machine's tailnet name, which every tool names it by.";
      };
      ssh = mkOption {
        type = types.str;
        description = "The ssh destination that reaches the machine as max (an alias of common.nix's ssh hosts).";
      };
      trust = mkOption {
        type = types.int;
        description = "How far the machine is trusted, higher being further.";
      };
      sessions = mkOption {
        type = types.bool;
        default = false;
        description = "Whether it runs max's sessions, and so a container hub.";
      };
      unlock = mkOption {
        type = types.listOf step;
        default = [ ];
        description = ''
          What it keeps locked after a boot, as the steps `host-unlock <name>`
          runs in order to open it; none where nothing is locked. Each host's
          receiving end is its host-unlock-receive.'';
      };
      timers = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "The file of its timers, from the repo's root, whose restic backups it runs (bin/backup-hosts).";
      };
      workers = mkOption {
        type = types.listOf worker;
        default = [ ];
        description = "The users dispatch sends workers to on it.";
      };
    };
  };

  # A worker user's HOST.md frontmatter, every field it sets. It goes into the
  # written-out list as well, so a tool printing the record of a host it cannot
  # reach prints the frontmatter the host's own copy holds.
  frontmatter = host: w:
    lib.concatLines ([ "---" "host: ${host}" "user: ${w.user}" "isolated: ${lib.boolToString w.isolated}" ]
      ++ lib.optional (w.placement != null) "placement: ${w.placement}"
      ++ lib.optional (w.has != [ ]) "has: ${lib.concatStringsSep ", " w.has}"
      ++ lib.optional (w.withholds != [ ]) "withholds: ${lib.concatStringsSep ", " w.withholds}"
      ++ lib.optional (w.account != null) "account: ${w.account}"
      ++ [ "---" "" ]);

  names = map (m: m.name) config.machines;

  # Each worker user's entry, its frontmatter beside it.
  written = map (m: m // { workers = map (w: w // { frontmatter = frontmatter m.name w; }) m.workers; })
    config.machines;
in
{
  options.machines = mkOption {
    type = types.listOf machine;
    description = "Every machine, in the order hub.mwolf.dev tries their hubs.";
    default = [
      {
        name = "pc";
        ssh = "pc";
        trust = 2;
        sessions = true;
        # The age key, the SSH key in the agent, the ZFS datasets, then copyparty
        # and the backups' catch-up (../nixos/pc/host-unlock.nix).
        unlock = [
          { run = [ "host-unlock-receive" "age-key" ]; ageKey = true; }
          { run = [ "host-unlock-receive" "ssh-key" ]; secret = "ssh-passphrase-pc"; }
          { run = [ "host-unlock-receive" "zfs" "phone" ]; secret = "zfs-phone-general"; }
          { run = [ "host-unlock-receive" "zfs" "general" ]; secret = "zfs-phone-general"; }
          { run = [ "host-unlock-receive" "zfs" "encrypted" ]; secret = "zfs-encrypted"; }
          { run = [ "host-unlock-receive" "finish" ]; }
        ];
        timers = "nix/home/pc-timers.nix";
        workers = [
          { user = "agent"; account = "personal"; isolated = true; withholds = [ "gpu" ]; }
          { user = "agent-hl"; account = "helferline"; isolated = true; withholds = [ "gpu" ]; }
        ];
      }
      {
        name = "zephylux";
        ssh = "zephylux";
        trust = 2;
        sessions = true;
        timers = "nix/home/timers.nix";
        # The laptop's GPU overheats under load.
        workers = [ { user = "max"; isolated = false; placement = "last"; withholds = [ "gpu" ]; } ];
      }
      {
        name = "xmg19";
        ssh = "xmg";
        trust = 1;
        # Its /home (../nixos/xmg19/home-unlock.nix).
        unlock = [ { run = [ "sudo" "host-unlock-receive" ]; secret = "xmg19-home-luks"; } ];
        workers = [
          { user = "agent"; account = "personal"; isolated = true; }
          { user = "agent-hl"; account = "helferline"; isolated = true; }
        ];
      }
    ];
  };

  options.machineRecords = mkOption {
    type = types.attrsOf types.str;
    readOnly = true;
    default = lib.listToAttrs (lib.concatMap
      (m: map (w: { name = "${w.user}@${m.name}"; value = w.frontmatter; }) m.workers)
      written);
    description = "Each worker user's HOST.md frontmatter, by user@host.";
  };

  config = {
    assertions = [
      {
        assertion = lib.allUnique names;
        message = "machines names a machine more than once: ${lib.concatStringsSep ", " names}";
      }
    ] ++ map (m: {
      assertion = lib.allUnique (map (w: w.user) m.workers);
      message = "machines: ${m.name} lists a worker user more than once";
    }) config.machines;

    xdg.configFile."machines.json".text = builtins.toJSON written;
  };
}
