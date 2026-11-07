{ config, lib, ... }:
let
  cfg = config.services.tailscale.serve-temp;
  tailscale = lib.getExe config.services.tailscale.package;
  serveCommands = lib.mapAttrsToList
    (name: args: "${tailscale} serve --yes --service=svc:${name} ${lib.escapeShellArgs args}")
    cfg;
in
{
  options.services.tailscale.serve-temp = lib.mkOption {
    type = with lib.types; attrsOf (listOf str);
    default = { };
    example = { service1 = [ "--https" "443" "http://localhost:8085" ]; };
    description = ''
      Temporary workaround for tailscale/tailscale#18381.
      Each attribute is a Service name (without svc:); the value is the
      list of arguments passed after `tailscale serve --service=svc:<name>`.
      The host's entire serve config is reset and re-applied from this.
    '';
  };

  config = lib.mkIf (cfg != { }) {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "services.tailscale.serve-temp requires services.tailscale.enable";
      }
      {
        # `or false` so this still evaluates on nixpkgs without the upstream module
        assertion = !(config.services.tailscale.serve.enable or false);
        message = "services.tailscale.serve-temp and services.tailscale.serve would overwrite each other";
      }
    ];

    systemd.services.tailscale-serve-temp = {
      description = "Declarative Tailscale Serve via CLI (workaround for #18381)";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      startLimitIntervalSec = 0;  # keep retrying if tailscaled is slow at boot
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = 5;
        ExecStop = "${tailscale} serve reset";
      };
      script = ''
        ${tailscale} serve reset
        ${lib.concatStringsSep "\n" serveCommands}
      '';
    };
  };
}
