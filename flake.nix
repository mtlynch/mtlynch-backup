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
    in
    {
      devShells.default = python-nixpkgs.mkShell {
        packages = [
          python-nixpkgs.python3
          python-nixpkgs.python312Packages.pip
          python-nixpkgs.python312Packages.virtualenv
          restic-nixpkgs.restic
        ];

        shellHook = ''
          python --version
          pip --version
          virtualenv --version
          restic version
        '';
      };
    });
}
