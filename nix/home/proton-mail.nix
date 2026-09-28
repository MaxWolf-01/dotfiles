# The Proton mailbox as a local Maildir: Proton Mail Bridge decrypts it and
# serves it over IMAP on 127.0.0.1:1143, mbsync pulls it into ~/data/proton-mail
# (bin/proton-mail-mirror, on a timer in timers.nix), and notmuch indexes it.
# The Maildir is plain files, one per message with its attachments inside, so
# it reads without Proton or Bridge, and restic backs it up.
#
# The mirror only pulls: nothing done to the local copy reaches Proton. Bridge
# itself still accepts IMAP writes and SMTP (127.0.0.1:1025) from anything
# holding the Bridge password, which any process running as max can decrypt.
#
# One-time login, while the service is stopped (Bridge refuses to run twice):
#   systemctl --user stop protonmail-bridge
#   protonmail-bridge --cli
#     login                         Proton password, then 2FA
#     info                          prints the Bridge password mbsync logs in with
#     cert export                   into ~/.config/proton-bridge/
#     exit
#   sops secrets/creds/raw/proton-bridge      paste the Bridge password
#   rm ~/.config/proton-bridge/key.pem
#   systemctl --user start protonmail-bridge
#   proton-mail-mirror
#
# Bridge keeps its vault key in the GNOME keyring and its own encrypted cache
# in ~/.local/share/protonmail/bridge-v3; neither is backed up, and a new
# machine logs in again.
{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
  maildir = "${home}/data/proton-mail";
in
{
  services.protonmail-bridge.enable = true;

  home.packages = [ pkgs.isync pkgs.notmuch ];

  # Mirror, not archive: a message deleted on Proton leaves the Maildir on the
  # next run, and the restic snapshots keep what the Maildir held. "All Mail"
  # holds every message a second time. Labels/* and Starred do too, for the
  # messages they tag, and stay in because those copies are the labels.
  xdg.configFile."isyncrc".text = ''
    IMAPAccount proton
    Host 127.0.0.1
    Port 1143
    User max@mwolf.dev
    PassCmd "sops -d ${home}/.dotfiles/secrets/creds/raw/proton-bridge"
    TLSType STARTTLS
    # Bridge's certificate is self-signed; mbsync trusts it by exact match.
    CertificateFile ${home}/.config/proton-bridge/cert.pem

    IMAPStore proton-remote
    Account proton

    MaildirStore proton-local
    Path ${maildir}/
    Inbox ${maildir}/INBOX
    SubFolders Verbatim

    Channel proton
    Far :proton-remote:
    Near :proton-local:
    Patterns * !"All Mail"
    Sync Pull
    Create Near
    Remove Near
    Expunge Near
    SyncState *
  '';

  # The index lives outside the Maildir, so the backup carries mail, not a
  # database `notmuch new` rebuilds.
  xdg.configFile."notmuch/default/config".text = ''
    [database]
    path=${home}/.local/share/notmuch/proton
    mail_root=${maildir}

    [user]
    name=Max Wolf
    primary_email=max@mwolf.dev

    # No inbox tag: `folder:INBOX` says where a message is, and the tag would
    # land on Sent and Archive too.
    [new]
    tags=unread;
    ignore=.mbsyncstate;.mbsyncstate.journal;.mbsyncstate.new;.mbsyncstate.lock;.uidvalidity

    [search]
    exclude_tags=deleted;spam;
  '';
}
