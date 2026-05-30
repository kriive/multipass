{
  description = "Multipass package and NixOS module restored from nixpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      overlays.default = final: prev: {
        multipass = final.callPackage ./pkgs/multipass/package.nix { };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          default = pkgs.multipass;
          multipass = pkgs.multipass;
        }
      );

      nixosModules.default = self.nixosModules.multipass;

      nixosModules.multipass = {
        imports = [ ./nixos/modules/multipass.nix ];
        nixpkgs.overlays = [ self.overlays.default ];
      };

      checks = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };
        in
        {
          inherit (pkgs) multipass;
        }
      );
    };
}
