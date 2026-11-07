{ config, pkgs, lib, ... }:

let
  boxes-app = builtins.fetchGit {
    url = "https://github.com/elegios/boxes-app.git";
    rev = "7ace57510a7a686b0efd96d240299315e899ba35";
  };
in

{
  imports = [
    "${boxes-app}/module.nix"
    ./tailscale-serve-temp.nix
  ];

  services.tailscale.enable = true;
  services.tailscale.serve-temp.enable = true;
  # services.tailscale.serve.enable = true;

  services.paperless = {
    enable = true;
    address = "::";
    port = 8080;
    environmentFile = pkgs.writeText "paperless-ocr-env" ''
      PAPERLESS_OCR_LANGUAGE=swe+eng
    '';
  };
  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.allowedUDPPorts = [ 8080 ];
  services.tailscale.serve-temp.paperless = ["http://localhost:8080" "--http" "80" "--https" "443"];
  services.tailscale.serve.services.paperless.endpoints = {
    "tcp:80" = "http://localhost:8080";
  };

  services.komga = {
    enable = true;
    settings.server.port = 8081;
    openFirewall = true;
  };
  services.tailscale.serve-temp.komga = ["http://localhost:8081" "--http" "80" "--https" "443"];
  services.tailscale.serve.services.komga.endpoints = {
    "tcp:80" = "http://localhost:8081";
  };

  services.boxes-app = {
    enable = true;
    settings.port = 8082;
    openFirewall = true;
  };
  services.tailscale.serve-temp.boxes = ["http://localhost:8082" "--http" "80" "--https" "443"];
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

  services.cook-cli = {
    enable = true;
    port = 8084;
    openFirewall = true;
    package = pkgs.cook-cli.overrideAttrs (old: {
      buildFeatures = (old.buildFeatures or [ ]) ++ [ "sync" "server" "import" "lsp" ];
      cargoBuildFeatures = (old.cargoBuildFeatures or [ ]) ++ [ "sync" "server" "import" "lsp" ];
    });
  };
  systemd.services.cook-cli.environment.COOK_CORS_ORIGIN = "http://food";
  services.tailscale.serve-temp.food = ["http://localhost:8084" "--http" "80" "--https" "443"];
  services.tailscale.serve.services.food.endpoints = {
    "tcp:80" = "http://localhost:8084";
  };

  services.actual = {
    enable = true;
    settings.port = 8085;
    openFirewall = true;
  };
  services.tailscale.serve-temp.actual = ["http://localhost:8085" "--http" "80" "--https" "443"];
  services.tailscale.serve.services.money.endpoints = {
    "tcp:443" = "http://localhost:8085"; # This should be https on the outside and http on the inside, but that can't be expressed this way right now, hence `tailscale.serve-temp`
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
      "/var/lib/cook-cli"
      "/var/lib/actual"
    ];
  };
}
