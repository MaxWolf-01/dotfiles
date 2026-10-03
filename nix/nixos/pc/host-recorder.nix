{ pkgs, ... }:

# The host recorder (bin/host-recorder). pc runs it as a system service, not a
# user one like zephylux: a row names a tmux pane by its largest process's
# working directory, and only root can read that of another user's process.
{
  systemd.services.host-recorder = {
    description = "Record memory, CPU and sensors to CSV";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.bash ]; # coreutils and findutils are on every unit's PATH
    serviceConfig = {
      ExecStart = "/home/max/.dotfiles/bin/host-recorder";
      # The rows name every user's panes and their working directories, which
      # the workers' 700 homes keep from each other (agent-user.nix). So the
      # files are readable by wheel, which holds max and no worker.
      Group = "wheel";
      UMask = "0027";
      StateDirectory = "host-recorder";
      StateDirectoryMode = "0750";
      Restart = "always";
      RestartSec = 10;
      # It is meant to keep writing while pc runs out of memory, which is when
      # its rows matter. The OOM killer never picks it, and memory.min keeps
      # its pages resident: a small process that sleeps between samples is
      # otherwise the first the kernel reclaims, and it then stalls on every
      # page it faults back in. memory.min covers what is charged to the
      # unit: its own memory, the CSVs it writes, and any file page it faults
      # in itself. Pages of bash another process read first are charged
      # there and can be reclaimed, once: faulted back in by the recorder,
      # they are its own. 32M covers its ~6 MB resident and the day's CSVs.
      OOMScoreAdjust = -1000;
      MemoryMin = "32M";
    };
  };

  # memory.min protects a cgroup only as far as each ancestor's does, so the
  # slice holding the recorder reserves as much. A service that later sets
  # its own MemoryMin has to add it here.
  systemd.slices.system.sliceConfig.MemoryMin = "32M";

  # The recorder prunes files older than 14 days when it starts, and on pc it
  # starts about once per boot; tmpfiles' daily clean keeps the same bound by
  # modification time, so reading an old file does not keep it.
  systemd.tmpfiles.rules = [ "e /var/lib/host-recorder - - - m:14d" ];
}
