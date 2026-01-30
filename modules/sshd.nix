{ config, pkgs, lib, ... }:

{
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "vipa" ];
    };
  };

  users.users.vipa.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICE1xDA67r/soyxVFJo9RnXpvasibCBgvWnwmxP0uSR/ vipa"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM2ZNWeQL5JkVx9FxhjC8LC/w37JQgWqsPZGH/WUKmzc vipa"
  ];
}
