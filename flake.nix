{
  description = "Structify - Generate init/cleanup/print/equal/hash functions for C structs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        haskellPackages = pkgs.haskell.packages.ghc96;
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Haskell toolchain
            haskellPackages.ghc
            haskellPackages.cabal-install
            haskellPackages.haskell-language-server
            haskellPackages.hlint
            haskellPackages.ormolu

            # C toolchain (for testing generated code)
            gcc
            clang
            valgrind

            # Development tools
            git
            zlib
          ];

          shellHook = ''
            echo "Structify development environment"
            echo "GHC version: $(ghc --version)"
            echo "Cabal version: $(cabal --version | head -n1)"
            echo ""
            echo "Available commands:"
            echo "  cabal build    - Build the project"
            echo "  cabal test     - Run tests"
            echo "  cabal install  - Install locally"
          '';
        };

        packages.default = haskellPackages.callCabal2nix "structify" ./. {};
      }
    );
}
