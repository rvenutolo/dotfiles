{ config, pkgs, lib, vars, ... }:
{
  imports = [
    ./packages-stable.nix
    ./packages-unstable.nix
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
  nixpkgs.config.allowUnfree = true;
  programs = {
    home-manager.enable = true;
    nix-index = {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      enableZshIntegration = true;
    };
    command-not-found.enable = false;
  };
  targets.genericLinux.enable = true;
  xdg.mime.enable = true;
}
