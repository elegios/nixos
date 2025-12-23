{ config, pkgs, lib, ... }:

let
  boxes-app = builtins.fetchGit {
    url = "https://github.com/elegios/boxes-app.git";
    rev = "b0e9ce377c010df5b93988f70bdb9b2e3bbb2dda";
  };
in

{
  imports = [
    "${boxes-app}/module.nix"
  ];

  services.paperless = {
    enable = true;
    address = "192.168.1.20";
    port = 8080;
    settings.PAPERLESS_OCR_LANGUAGE = "eng+swe";
  };
  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.allowedUDPPorts = [ 8080 ];

  services.komga = {
    enable = true;
    settings.server.port = 8081;
    openFirewall = true;
  };

  services.boxes-app = {
    enable = true;
    settings.port = 8082;
    openFirewall = true;
  };

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
