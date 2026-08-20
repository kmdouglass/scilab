{
  description = "lebpc39 NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Host-specific settings that must stay out of this public repo (e.g.
    # real network addresses). Points at a private, local-only git repo;
    # see README.md for how to set it up.
    scilab-private.url = "git+file:///home/kmd/src/scilab-private";
    scilab-private.flake = false;

    focus-field-viewer.url = "github:LEB-EPFL/focus-field-viewer";
  };

  outputs = { self, nixpkgs, scilab-private, focus-field-viewer, ... }@inputs: {
    nixosConfigurations.lebpc39 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit scilab-private; };
      modules = [
        ./configuration.nix

        focus-field-viewer.nixosModules.default
        {
          services.focus-field-viewer = {
            enable = true;
            port = 8501;          # default
            address = "0.0.0.0";  # default; binds to all interfaces for LAN access
            # Reached only through the Caddy reverse proxy on port 80
            # (reverse-proxy.nix), not directly.
            openFirewall = false;
          };
        }
      ];
    };
  };
}
