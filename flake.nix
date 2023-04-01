{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    base16 = {
      url = "github:SenchoPens/base16.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Used for documentation
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    { nixpkgs, base16, self, ... }@inputs:
    {
      overlays = {
          fix-codesign-allocate = selfp: superp: {
            darwin = superp.darwin.overrideScope (self: super: {
              postLinkSignHook = selfp.writeTextFile {
              name = "post-link-sign-hook";
              executable = true;
              text = ''
                CODESIGN_ALLOCATE=${self.cctools}/bin/${self.cctools.targetPrefix}codesign_allocate \
                  ${self.sigtool}/bin/codesign -f -s - "$linkerOutput"
              '';
            };
            });
          };
        };

      packages = nixpkgs.lib.genAttrs [
        "aarch64-darwin"
        "aarch64-linux"
        "i686-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ] (
        system:
        let pkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlays.fix-codesign-allocate
            ];
          };
        in {
          docs = import ./docs {
            inherit pkgs inputs;
            inherit (nixpkgs) lib;
          };

          palette-generator = pkgs.callPackage ./palette-generator { };
        }
      );

      nixosModules.stylix = { pkgs, ... }@args: {
        imports = [
          (import ./stylix/nixos {
            inherit (self.packages.${pkgs.system}) palette-generator;
            base16 = base16.lib args;
            homeManagerModule = self.homeManagerModules.stylix;
          })
        ];
      };

      homeManagerModules.stylix = { pkgs, ... }@args: {
        imports = [
          (import ./stylix/hm {
            inherit (self.packages.${pkgs.system}) palette-generator;
            base16 = base16.lib args;
          })
        ];
      };

      darwinModules.stylix = { pkgs, ... }@args: {
        imports = [
          (import ./stylix/darwin {
            inherit (self.packages.${pkgs.system}) palette-generator;
            base16 = base16.lib args;
            homeManagerModule = self.homeManagerModules.stylix;
          })
        ];
      };
    };
}
