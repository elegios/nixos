{ config, pkgs, lib, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "vipa-nixos"; # Define your hostname.

  powerManagement.cpuFreqGovernor = "ondemand";
}
