# theme-toggle.nix
#
# Fast light/dark toggle for stylix, using a home-manager specialisation
# so no nixos-rebuild is needed to flip between them.
#
# Assumes:
#   - home-manager is used as a NixOS module (no separate HM profile/
#     generations; the activation path is read from the
#     home-manager-$USER.service systemd unit instead).
#   - sway is configured via home-manager's wayland.windowManager.sway.
#   - the default configuration already configures a dark mode.
#
# Import into your home-manager config, e.g.:
#   home-manager.users.<you> = {
#     imports = [ ./theme-toggle.nix ];
#     ...
#   };

{ config, lib, pkgs, ... }:

let
  ##############################################################
  ## Fill these in.
  ##############################################################

  lightScheme = "${pkgs.base16-schemes}/share/themes/solarized-light.yaml";

  # e.g. "$mod+Shift+t"
  toggleKeybind = "Mod4+v";

  ##############################################################

  # Name of the marker file under $XDG_DATA_HOME that records which
  # polarity is currently active. Written by both the base config and
  # the specialisation, so whichever one you last activated leaves an
  # accurate record behind.
  markerFile = "theme-polarity";

  toggleTheme = pkgs.writeShellApplication {
    name = "toggle-theme";
    runtimeInputs = [ pkgs.coreutils pkgs.gnugrep pkgs.systemd ];
    text = ''
      marker="''${XDG_DATA_HOME:-$HOME/.local/share}/${markerFile}"

      # The base (no-specialisation) activation path. This is only ever
      # rewritten by nixos-rebuild switch/boot, never by manually running
      # an activate script, so it's a stable way to get back to "no
      # specialisation" regardless of which one is currently active.
      #
      # NOTE: the "home-manager-[a-z]+" suffix (generation vs files etc.)
      # has changed across home-manager versions before. If this stops
      # matching after an upgrade, check
      # `systemctl cat "home-manager-$USER.service"` and adjust the
      # pattern below.
      base="$(systemctl cat "home-manager-$USER.service" \
        | grep -oE '/nix/store/[a-z0-9]+-home-manager-[a-z]+' \
        | head -1)"

      if [ -z "$base" ]; then
        echo "toggle-theme: could not find home-manager-$USER.service activation path" >&2
        exit 1
      fi

      current="$(cat "$marker" 2>/dev/null || echo dark)"

      if [ "$current" = "light" ]; then
        "$base/activate" --driver-version 1
      else
        "$base/specialisation/light/activate" --driver-version 1
      fi

      emacsclient --eval '(ele/load-theme-from-marker)' >/dev/null 2>&1 || true
    '';
  };
in
{
  # --- Base (dark) configuration -----------------------------------------

  xdg.dataFile.${markerFile}.text = "dark";

  wayland.windowManager.sway.config.keybindings = {
    ${toggleKeybind} = "exec ${toggleTheme}/bin/toggle-theme";
  };

  # --- Light specialisation ------------------------------------------------
  # Everything not overridden here (the script, the keybind, etc.) is
  # inherited from the base config above.

  specialisation.light.configuration = {
    stylix.polarity = lib.mkForce "light";
    stylix.base16Scheme = lib.mkForce lightScheme;

    xdg.dataFile.${markerFile}.text = lib.mkForce "light";
  };
}
