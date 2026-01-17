{ config, pkgs, lib, ... }:
let
  vars = import ./vars.nix;
in
{
  imports = [
    ./packages.nix
  ];
  home= {
    username = vars.username;
    homeDirectory = vars.homeDirectory;
    stateVersion = vars.stateVersion;
    activation = {
      linkDesktopApplications = {
        after = ["writeBoundary" "createXdgUserDirectories" ];
        before = [];
        # make .desktop files executable for KDE
        data = "find $HOME/.nix-profile/share/applications/ -iname '*.desktop' | xargs --no-run-if-empty --max-args=1 readlink | xargs --no-run-if-empty chmod +x";
      };
    };
  };
  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };
  programs.home-manager.enable = true;
  targets.genericLinux.enable = true;
  xdg.mime.enable = true;
}
