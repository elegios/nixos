{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "viktpalm-linux"; # Define your hostname.

  powerManagement.cpuFreqGovernor = "ondemand";

  # services.printing.enable = true;
  # hardware.pulseaudio.enable = false;
  # security.rtkit.enable = true
  # services.pipewire.alsa.support32Bit = true;
}
