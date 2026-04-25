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

  services.tailscale.enable = true;
  services.tailscale.serve.enable = true;

  services.paperless = {
    enable = true;
    address = "::";
    port = 8080;
    settings.PAPERLESS_OCR_LANGUAGE = "eng+swe";
  };
  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.allowedUDPPorts = [ 8080 ];
  services.tailscale.serve.services.paperless.endpoints = {
    "tcp:80" = "http://localhost:8080";
  };

  services.komga = {
    enable = true;
    settings.server.port = 8081;
    openFirewall = true;
  };
  services.tailscale.serve.services.komga.endpoints = {
    "tcp:80" = "http://localhost:8081";
  };

  services.boxes-app = {
    enable = true;
    settings.port = 8082;
    openFirewall = true;
  };
  services.tailscale.serve.services.boxes.endpoints = {
    "tcp:80" = "http://localhost:8082";
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

  services.valheim = {
    enable = true;
    serverName = "Princely Chat";
    worldName = "ThePrincelyValheimWorld001";
    openFirewall = true;
    password = "princelychat";
    public = false;
  };

  services.restic.backups.gdrive = {
    repository = "rclone:gdrive:/backups";
    passwordFile = "/home/vipa/.restic-password";
    pruneOpts = [
      "--keep-within-daily 7d"   # NOTE(vipa, 2025-12-23): Daily backups for the last week
      "--keep-within-weekly 1m"  # NOTE(vipa, 2025-12-23): Weekly backups for the last month
      "--keep-within-monthly 1y" # NOTE(vipa, 2025-12-23): Monthly backups for the last year
      "--keep-within-yearly 75y" # NOTE(vipa, 2025-12-23): Yearly backups for 75 years
    ];
    paths = [
      "/var/lib/paperless"
      "/var/lib/komga"
      "/var/lib/boxes-app"
      "/var/lib/valheim"
    ];
  };
}
