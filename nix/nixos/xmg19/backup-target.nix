{ ... }:

# The restic repositories other machines write here: pc's datasets, zephylux's
# working set (secrets/backup/restic/*/xmg19.conf). The writers hold the
# passwords, so xmg19 stores ciphertext and nothing that opens it.
#
# The writers reach the repositories as `backup`, an SFTP-only user locked into
# /srv/backup: no shell, no forwarding, nothing outside the chroot. The
# repositories sit under /restic inside it, which is /srv/backup/restic here.
{
  users.users.backup = {
    isSystemUser = true;
    group = "backup";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPyy5xWC5my4ZPkc7mUEPKi/SfqdUEeq12pMKo5D/D4p" # zephyrus
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHZifXbOmWESRCVMJmThjlFD3gdBrVH5ydol1Eo7EU9/" # pc
    ];
  };
  users.groups.backup = { };

  # sshd refuses a chroot whose path has a component that is not root's or that
  # anyone else can write to, so the user's writable directory is one level in.
  systemd.tmpfiles.rules = [
    "d /srv/backup 0755 root root -"
    "d /srv/backup/restic 0700 backup backup -"
  ];

  services.openssh.extraConfig = ''
    Match User backup
      ChrootDirectory /srv/backup
      ForceCommand internal-sftp
      DisableForwarding yes
      PermitTTY no
  '';
}
