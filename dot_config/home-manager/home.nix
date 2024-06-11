{ config, pkgs, lib, ... }:
{
  imports = [
    ./user.nix
    ./packages.nix
    ./nixpkgs-config.nix
  ];
  programs.home-manager.enable = true;
  targets.genericLinux.enable = true;
  xdg.mime.enable = true;
}
