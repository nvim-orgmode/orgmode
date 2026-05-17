{
  description = "nvim-orgmode";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    np = {
      url = "github:ar-at-localhost/np/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    git-hooks,
    nixvim,
    np,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};

        _nixvim = import ./nix/nixvim.nix {
          inherit system pkgs nixvim np;
        };
      in {
        checks = {
          pre-commit-check = git-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              alejandra.enable = true;
              stylua.enable = true;
            };
          };
        };

        formatter = let
          inherit (self.checks.${system}.pre-commit-check) config;
          inherit (config) package configFile;
          script = ''
            ${pkgs.lib.getExe package} run --all-files --config ${configFile}
          '';
        in
          pkgs.writeShellScriptBin "pre-commit-run" script;

        packages._nixvim = _nixvim;

        devShells.default = let
          inherit (self.checks.${system}.pre-commit-check) shellHook;
        in
          pkgs.mkShell {
            packages = with pkgs; [
              gnumake
              neovim
              _nixvim
              stylua
              alejandra
            ];

            shellHook = ''
              ${shellHook}
              echo "Nvim Orgmode development environment"
            '';
          };
      }
    )
    // {
      nixvimModules = {
        # Expose nixvim modules for consumers
      };
    };
}
