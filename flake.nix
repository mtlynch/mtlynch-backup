{
  description = "Nix environment";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    # 3.12.5 release
    python-nixpkgs.url = "github:NixOS/nixpkgs/5ed627539ac84809c78b2dd6d26a5cebeb5ae269";

    # 0.17.3 release
    restic-nixpkgs.url = "github:NixOS/nixpkgs/566e53c2ad750c84f6d31f9ccb9d00f823165550";
  };

  outputs = { self, flake-utils, python-nixpkgs, restic-nixpkgs }@inputs :
    {
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.services.restic-backup;
        in {
          options.services.restic-backup = {
            enable = lib.mkEnableOption "Restic backup service";

            passwordFile = lib.mkOption {
              type = lib.types.str;
              description = "Path to restic password file";
            };

            backupPathsFile = lib.mkOption {
              type = lib.types.str;
              description = "Path to backup paths file";
            };

            reposFile = lib.mkOption {
              type = lib.types.str;
              description = "Path to repos config file";
            };

            excludeFile = lib.mkOption {
              type = lib.types.str;
              description = "Path to excludes file";
            };

            keepDaily = lib.mkOption {
              type = lib.types.int;
              default = 7;
              description = "Number of daily snapshots to keep";
            };

            keepWeekly = lib.mkOption {
              type = lib.types.int;
              default = 4;
              description = "Number of weekly snapshots to keep";
            };

            keepMonthly = lib.mkOption {
              type = lib.types.int;
              default = 5;
              description = "Number of monthly snapshots to keep";
            };

            keepYearly = lib.mkOption {
              type = lib.types.int;
              default = 10;
              description = "Number of yearly snapshots to keep";
            };

            influxHost = lib.mkOption {
              type = lib.types.str;
              description = "InfluxDB host";
            };

            influxPort = lib.mkOption {
              type = lib.types.int;
              description = "InfluxDB port";
            };

            influxDatabase = lib.mkOption {
              type = lib.types.str;
              description = "InfluxDB database name";
            };

            timer = lib.mkOption {
              type = lib.types.str;
              default = "daily";
              description = "Systemd calendar expression for backup frequency";
            };
          };

          config = lib.mkIf cfg.enable {
            systemd.services.restic-backup = {
              description = "Restic Backup Service";
              after = [ "network.target" ];
              wants = [ "network.target" ];

              environment = {
                PASSWORD_FILE = cfg.passwordFile;
                BACKUP_PATHS_FILE = cfg.backupPathsFile;
                REPOS_FILE = cfg.reposFile;
                EXCLUDE_FILE = cfg.excludeFile;
                KEEP_DAILY = toString cfg.keepDaily;
                KEEP_WEEKLY = toString cfg.keepWeekly;
                KEEP_MONTHLY = toString cfg.keepMonthly;
                KEEP_YEARLY = toString cfg.keepYearly;
                INFLUX_HOST = cfg.influxHost;
                INFLUX_PORT = toString cfg.influxPort;
                INFLUX_DATABASE = cfg.influxDatabase;
              };

              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${self.packages.${pkgs.system}.default}/bin/backup";
              };
            };

            systemd.timers.restic-backup = {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnCalendar = cfg.timer;
                Persistent = true;
              };
            };
          };
        };
    } // (flake-utils.lib.eachDefaultSystem (system:
    let
      python-nixpkgs = inputs.python-nixpkgs.legacyPackages.${system};
      restic-nixpkgs = inputs.restic-nixpkgs.legacyPackages.${system};

      packages = [
        python-nixpkgs.python3
        python-nixpkgs.python312Packages.pip
        python-nixpkgs.python312Packages.virtualenv
        restic-nixpkgs.restic
      ];

      script = python-nixpkgs.writeShellScript "backup" ''
        #!/usr/bin/env bash
        set -eux

        readonly VIRTUALENV_DIR='.venv'

        # Set up virtualenv if it doesn't exist.
        if [ ! -d "$VIRTUALENV_DIR" ]; then
          virtualenv "$VIRTUALENV_DIR"
        fi

        . "$VIRTUALENV_DIR/bin/activate"
        pip install -r requirements.txt

        ./backup.py \
          --password-file "$PASSWORD_FILE" \
          --backup-paths-file "$BACKUP_PATHS_FILE" \
          --repos-file "$REPOS_FILE" \
          --exclude-file "$EXCLUDE_FILE" \
          --exclude '~$*' \
          --keep-daily "$KEEP_DAILY" \
          --keep-weekly "$KEEP_WEEKLY" \
          --keep-monthly "$KEEP_MONTHLY" \
          --keep-yearly "$KEEP_YEARLY" \
          --influx-host "$INFLUX_HOST" \
          --influx-port "$INFLUX_PORT" \
          --influx-database "$INFLUX_DATABASE"
      '';
    in
    {
      devShells.default = python-nixpkgs.mkShell {
        inherit packages;
        shellHook = ''
          python --version
          pip --version
          virtualenv --version
          restic version
        '';
      };

      packages.default = python-nixpkgs.symlinkJoin {
        name = "backup-env";
        paths = packages;
        buildInputs = [ python-nixpkgs.makeWrapper ];
        postBuild = ''
          makeWrapper ${script} $out/bin/backup \
            --prefix PATH : ${python-nixpkgs.lib.makeBinPath packages}
        '';
      };

      apps.default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/backup";
      };
    }));
}
