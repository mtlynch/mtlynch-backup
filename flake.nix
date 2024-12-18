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
    flake-utils.lib.eachDefaultSystem (system:
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

        . venv/bin/activate
        pip install -r requirements.txt

        . .env.prod

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
    });
}
