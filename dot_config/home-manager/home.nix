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
  home.activation = {
    linkDesktopApplications = {
      after = ["writeBoundary" "createXdgUserDirectories" ];
      before = [];
      # make .desktop files executable for KDE
      data = "find $HOME/.nix-profile/share/applications/ -iname '*.desktop' | xargs --no-run-if-empty --max-args=1 readlink | xargs chmod +x";
    };
  };
}
