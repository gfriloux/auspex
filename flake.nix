{
  description = ''
    auspex — widget de supervision Zabbix pour Quickshell / DankMaterialShell.
    Badge d'état + cockpit des problèmes actifs, notifications. Données via l'API
    JSON-RPC de Zabbix 7.0 (lecture seule, polling). Un Nagstamon repensé en plugin DMS.
  '';

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # Module home-manager : installe auspex comme plugin DankMaterialShell.
      flake.homeModules.default = import ./nix/hm-module.nix;

      perSystem = {pkgs, ...}: let
        # Launcher d'instance DMS isolée pour tester le worktree (cf. scripts/auspex-dev).
        auspex-dev = pkgs.writeShellApplication {
          name = "auspex-dev";
          runtimeInputs = [pkgs.jq];
          text = builtins.readFile ./scripts/auspex-dev;
        };
      in {
        formatter = pkgs.alejandra;

        packages.dev-bar = auspex-dev;
        apps.dev-bar = {
          type = "app";
          program = "${auspex-dev}/bin/auspex-dev";
        };

        devShells.default = pkgs.mkShell {
          name = "auspex";
          packages = with pkgs; [
            # Runtime / cible (bless via quickshell, lint/format/test via Qt6)
            quickshell
            qt6.qtdeclarative # qmllint, qmlformat, qmltestrunner
            qt6.qtbase

            # Runtime du service (poll HTTP de l'API Zabbix)
            curl

            # Dev : mock d'API Zabbix (just mock) + instance DMS isolée (just dev-bar)
            python3
            jq

            # Outillage projet
            just
            git
            git-cliff # changelog depuis les Conventional Commits (just changelog)

            # Portes Nix (cf. .pre-commit-config.yaml)
            alejandra
            deadnix
          ];

          shellHook = ''
            echo ""
            echo "  auspex — widget de supervision Zabbix pour Quickshell / DankMaterialShell"
            echo "  qmllint/qmlformat/qmltestrunner prêts."
            echo "  just ci"
            echo ""
          '';
        };
      };
    };
}
