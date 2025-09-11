{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "viktpalm-linux"; # Define your hostname.

  boot.kernelParams = [ "i915.force_probe=7d55" ];

  # TODO(vipa, 2025-07-23): In theory this should be correct, but it
  # seems like there's no support for what I actually have, and some
  # service it starts fails, so I'm turning it off for the moment
  # https://github.com/NixOS/nixpkgs/issues/225743 for reference
  # hardware.ipu6 = { enable = true; platform = "ipu6epmtl"; };

  powerManagement.cpuFreqGovernor = "ondemand";

  # NOTE(vipa, 2024-11-18): The built-in monitor has a weird
  # resolution where scale=2 is too large and scale=1 is much too
  # small. 1.5 seems to be a good sweet-spot, and while non-integral
  # scaling isn't great, it seems to render well enough for the
  # moment.
  home-manager.users.vipa.wayland.windowManager.sway.config.output."eDP-1".scale = "1.5";

  # services.printing.enable = true;
  # hardware.pulseaudio.enable = false;
  # security.rtkit.enable = true
  # services.pipewire.alsa.support32Bit = true;
}
