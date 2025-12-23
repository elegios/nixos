{ config, pkgs, lib, ... }:

{
  services.pihole-ftl = {
    enable = true;
    openFirewallDNS = true;
    settings = {
      dns.upstreams = [ "8.8.8.8" ];
    };
    lists = [
      { url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt"; }
    ];
  };
  services.pihole-web = {
    enable = true;
    ports = [ 8083 ];
  };
}
