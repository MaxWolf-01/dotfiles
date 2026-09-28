# Proton Mail, readable from the shell: Proton Mail Bridge decrypts the mailbox
# and serves it over IMAP on 127.0.0.1:1143; himalaya reads it from there.
#
# Read-only by configuration, not by enforcement: himalaya has no SMTP block, so
# `himalaya message send` has nowhere to go. Bridge still serves SMTP on
# 127.0.0.1:1025 and accepts IMAP writes (flags, moves, deletes) from anything
# holding the Bridge password, which any process running as max can decrypt.
#
# One-time login, while the service is stopped (Bridge refuses to run twice):
#   systemctl --user stop protonmail-bridge
#   protonmail-bridge --cli
#     login                         Proton password, then 2FA
#     info                          prints the Bridge password himalaya logs in with
#     cert export                   into ~/.config/himalaya/proton-bridge/
#     exit
#   sops secrets/creds/raw/proton-bridge      paste the Bridge password
#   rm ~/.config/himalaya/proton-bridge/key.pem
#   systemctl --user start protonmail-bridge
#   himalaya account check
#
# Bridge keeps its vault key in the GNOME keyring and its message cache in
# ~/.local/share/protonmail/bridge-v3, which restic does not back up: a new
# machine logs in again and Bridge re-syncs.
{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
  toml = pkgs.formats.toml { };
in
{
  services.protonmail-bridge.enable = true;

  home.packages = [ pkgs.himalaya ];

  # Not programs.himalaya: its module still writes the v1 config format, which
  # himalaya 2 rejects.
  xdg.configFile."himalaya/config.toml".source = toml.generate "himalaya-config.toml" {
    accounts.proton = {
      default = true;
      mailbox.alias = {
        inbox = "INBOX";
        sent = "Sent";
        drafts = "Drafts";
        trash = "Trash";
        archive = "Archive";
        all = "All Mail";
      };
      imap = {
        server = "imap://127.0.0.1:1143";
        starttls = true;
        # Bridge's certificate is self-signed; it is its own root.
        tls.cert = "${home}/.config/himalaya/proton-bridge/cert.pem";
        sasl.plain = {
          username = "max@mwolf.dev";
          password.command = [
            "sops"
            "-d"
            "${home}/.dotfiles/secrets/creds/raw/proton-bridge"
          ];
        };
      };
    };
  };
}
