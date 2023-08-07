{ config, pkgs, lib, ... }:

{

  home = {
    username = "rvenutolo";
    homeDirectory = "/home/rvenutolo";
    stateVersion = "23.05";
    packages = with builtins; with pkgs.lib; map (name: getAttrFromPath (splitString "." name) pkgs) (fromJSON (readFile ./pkgs.json));
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  programs.home-manager.enable = true;

}
