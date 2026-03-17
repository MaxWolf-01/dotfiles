{ ... }:

{
  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    openFirewallWebserver = true;
    settings = {
      dns.upstreams = [ "1.1.1.1" "1.0.0.1" ];
      dns.listeningMode = "all";
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
