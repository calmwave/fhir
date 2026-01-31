  {
      inputs = {
        nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
      };

      outputs = { self, nixpkgs }:
        let
          systems = [
            "aarch64-darwin"
            "x86_64-linux"
            "aarch64-linux"
          ];

          forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
            pkgs = import nixpkgs { inherit system; };
          });
        in
        {
          devShells = forAllSystems ({ pkgs }: {
            default = pkgs.mkShell {
              packages = with pkgs; [
                beam28Packages.elixir_1_19
                beam28Packages.erlang
              ];

              shellHook = ''
                export MIX_HOME=$PWD/.nix-mix
                export HEX_HOME=$PWD/.nix-hex
                export ERL_AFLAGS="-kernel shell_history enabled"
              '';
            };
          });
        };
    }
