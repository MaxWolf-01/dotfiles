# The Pythons uv downloads are built for a conventional Linux: their OpenSSL
# reads its CA bundle from /etc/ssl/cert.pem, which NixOS does not provide, so
# every HTTPS fetch fails verification. Linking it there reaches every caller,
# systemd units included, with no variable to export.
#
# python3 is on PATH too (nix/home/), and uv would take it for a venv where it
# has no Python of its own for the version; that one cannot load the many wheels
# that link libstdc++. only-managed keeps uv to its own Pythons.
{ config, ... }:
{
  environment.etc."ssl/cert.pem".source = config.security.pki.caBundle;
  environment.variables.UV_PYTHON_PREFERENCE = "only-managed";
}
