# valheim.nix
{config, pkgs, lib, utils, ...}:
let
	# Set to {id}-{branch}-{password} for betas.
	steam-app = "896660";
  cfg = config.services.valheim;
  inherit (lib) mkEnableOption mkOption mkDefault mkPackageOption;
  inherit (lib.types) str port bool;
in {
	imports = [
		./steam.nix
	];

  # TODO(vipa, 2026-04-21): Wrap this so the configuration is nicely
  # available in homeserver.nix instead, so I can easily see what's
  # setup there

  options.services.valheim = {
    enable = mkEnableOption "Run a Valheim server";

    user = mkOption {
      type = str;
      default = "valheim";
      description = "User account under which valheim runs.";
    };

    group = mkOption {
      type = str;
      default = "valheim";
      description = "Group under which valheim runs.";
    };

    stateDir = mkOption {
      type = str;
      default = "/var/lib/valheim";
      description = "State and configuration directory Valheim will use.";
    };

    name = mkOption {
      type = str;
      description = "Name of the server";
    };

    world = mkOption {
      type = str;
      description = "Name of the world";
    };

    first-port = mkOption {
      type = port;
      default = 2456;
      description = "The first port used for the server. The server will _also_ use port+1.";
    };

    public = mkOption {
      type = bool;
      default = false;
      description = "Advertise the server in the public listing.";
    };

    password = mkOption {
      type = str;
      default = "password";
      description = "Password to use for connecting to the server.";
    };

    openFirewall = mkOption {
      type = bool;
      default = false;
      description = "Open the appropriate ports in the firewall.";
    };
  };
  config = let inherit (lib) mkIf getExe; in mkIf cfg.enable {
    users.users.valheim = mkIf (cfg.user == "valheim") {
      isSystemUser = true;
      # Valheim puts save data in the home directory.
      home = cfg.stateDir;
      createHome = true;
      homeMode = "750";
      group = cfg.group;
    };

    users.groups = mkIf (cfg.group == "valheim") { valheim = {}; };

    networking.firewall.allowedUDPPorts = mkIf cfg.openFirewall [ cfg.first-port (cfg.first-port + 1) ];

    systemd.services.valheim = {
      wantedBy = [ "multi-user.target" ];

      # Install the game before launching.
      wants = [ "steam@${steam-app}.service" ];
      after = [ "steam@${steam-app}.service" ];

      serviceConfig = {
        ExecStart = utils.escapeSystemdExecArgs [
          "/var/lib/steam-app-${steam-app}/valheim_server.x86_64"
          "-nographics"
          "-batchmode"
          # "-crossplay" # This is broken because it looks for "party" shared library in the wrong path.
          "-savedir" "${cfg.stateDir}/save"
          "-name" "${cfg.name}"
          "-port" "${cfg.first-port}"
          "-world" "${cfg.world}"
          "-password" "${cfg.password}"
          "-public" "${if cfg.public then 1 else 0}" # Valheim now supports favourite servers in-game which I am using instead of listing in the public registry.
          "-backups" "0" # I take my own backups, if you don't you can remove this to use the built-in basic rotation system.
        ];
        Nice = "-5";
        PrivateTmp = true;
        Restart = "always";
        User = "valheim";
        WorkingDirectory = "~";
      };
      environment = {
        # linux64 directory is required by Valheim.
        LD_LIBRARY_PATH = "/var/lib/steam-app-${steam-app}/linux64:${pkgs.glibc}/lib";
        SteamAppId = "892970";
      };
    };
  };

	# This is my custom backup machinery. Substitute your own 🙂
	kevincox.backup.valheim = {
		paths = [
			"/var/lib/valheim/save/"
		];
	};
}
