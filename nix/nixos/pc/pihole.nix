{ ... }:

{
  services.pihole-ftl = {
    enable = false; # disabled until nixpkgs#500852 is fixed (pihole/pihole-ftl version mismatch)
    openFirewallDNS = true;
    openFirewallWebserver = true;
    settings = {
      dns.upstreams = [ "1.1.1.1" "1.0.0.1" ];
      dns.listeningMode = "all"; # default "local" ignores Tailscale queries; safe because firewall blocks external access
    };
    lists = [
      {
        url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
        type = "block";
        enabled = true;
        description = "Hagezi Pro - comprehensive ad/tracker blocking";
      }
    ];
  };

  services.pihole-web = {
    enable = true;
    ports = [ "8053s" ];
  };
}
