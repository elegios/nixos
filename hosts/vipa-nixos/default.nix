{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "vipa-nixos"; # Define your hostname.

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 20;

  powerManagement.cpuFreqGovernor = "ondemand";
}
