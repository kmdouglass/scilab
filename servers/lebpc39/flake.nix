{
  description = "lebpc39 NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Host-specific settings that must stay out of this public repo (e.g.
    # real network addresses). Points at a private, local-only git repo;
    # see README.md for how to set it up.
    scilab-private.url = "git+file:///home/kmd/src/scilab-private";
    scilab-private.flake = false;
  };

  outputs = { self, nixpkgs, scilab-private, ... }@inputs: {
    nixosConfigurations.lebpc39 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit scilab-private; };
      modules = [
        ./configuration.nix
      ];
    };
  };
}
