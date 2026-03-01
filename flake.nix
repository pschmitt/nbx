{
  description = "CLI for NetBox REST and GraphQL APIs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        version =
          let
            rev =
              if self ? shortRev then
                self.shortRev
              else if self ? dirtyShortRev then
                self.dirtyShortRev
              else
                "unknown-dirty";
          in
          "${pkgs.lib.substring 0 8 self.lastModifiedDate}-${rev}";
        nbx = pkgs.callPackage ./nix/package.nix { inherit version; };
      in
      {
        packages = {
          inherit nbx;
          default = nbx;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            zsh
            coreutils
            curl
            gawk
            gnugrep
            jq
            util-linux
          ];
        };
      }
    );
}
