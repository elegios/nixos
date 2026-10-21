{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "vipa-homeserver"; # Define your hostname.

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/disk/by-id/ata-KINGSTON_SA400S37960G_50026B738122EAD4";
  boot.loader.grub.useOSProber = true;

  powerManagement.cpuFreqGovernor = "ondemand";
}
