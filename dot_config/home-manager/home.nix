{ config, pkgs, lib, ... }:
{
  imports = [
    ./user.nix
    ./packages.nix
    ./nixpkgs-config.nix
  ];
  home.stateVersion = "23.05";
  programs.home-manager.enable = true;
}
