{
  description = "pomo - A Pomodoro timer with shell integrations";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          default = self.packages.${system}.pomo;

          pomo = pkgs.stdenvNoCC.mkDerivation {
            pname = "pomo";
            version = "0.1.0";

            src = self;

            installPhase = ''
              mkdir -p $out/share/zsh/plugins/pomo
              cp -r . $out/share/zsh/plugins/pomo/
            '';

            meta = with pkgs.lib; {
              description = "A Pomodoro timer with shell integrations";
              homepage = "https://github.com/10xdevclub/pomo";
              license = licenses.mit;
              platforms = platforms.all;
            };
          };
        };

        # For development
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zsh
            zsh-powerlevel10k
          ];
        };
      }
    ) // {
      # Overlay for easy integration
      overlays.default = final: prev: {
        pomo = self.packages.${prev.system}.pomo;
      };

      # Home-manager module
      homeManagerModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.zsh.pomodoro;
        in
        {
          options.programs.zsh.pomodoro = {
            enable = mkEnableOption "pomo plugin";

            workDuration = mkOption {
              type = types.int;
              default = 1500;
              description = "Work session duration in seconds (default: 25 minutes)";
            };

            shortBreak = mkOption {
              type = types.int;
              default = 300;
              description = "Short break duration in seconds (default: 5 minutes)";
            };

            longBreak = mkOption {
              type = types.int;
              default = 900;
              description = "Long break duration in seconds (default: 15 minutes)";
            };

            cyclesBeforeLong = mkOption {
              type = types.int;
              default = 4;
              description = "Number of work sessions before a long break";
            };

            soundEnabled = mkOption {
              type = types.bool;
              default = true;
              description = "Enable sound alerts";
            };

            notifyEnabled = mkOption {
              type = types.bool;
              default = true;
              description = "Enable desktop notifications";
            };
          };

          config = mkIf cfg.enable {
            programs.zsh.plugins = [
              {
                name = "pomo";
                src = self.packages.${pkgs.system}.pomo + "/share/zsh/plugins/pomo";
                file = "pomo.plugin.zsh";
              }
            ];

            programs.zsh.initExtra = ''
              # pomo configuration
              export POMODORO_WORK_DURATION=${toString cfg.workDuration}
              export POMODORO_SHORT_BREAK=${toString cfg.shortBreak}
              export POMODORO_LONG_BREAK=${toString cfg.longBreak}
              export POMODORO_CYCLES_BEFORE_LONG=${toString cfg.cyclesBeforeLong}
              export POMODORO_SOUND_ENABLED=${if cfg.soundEnabled then "true" else "false"}
              export POMODORO_NOTIFY_ENABLED=${if cfg.notifyEnabled then "true" else "false"}
            '';
          };
        };
    };
}
