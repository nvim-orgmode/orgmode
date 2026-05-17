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
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    git-hooks,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
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

        devShells.default = let
          inherit (self.checks.${system}.pre-commit-check) shellHook;
        in
          pkgs.mkShell {
            packages = with pkgs; [
              gnumake
              neovim
              stylua
              alejandra
            ];

            shellHook = ''
              ${shellHook}
              echo "Nvim Orgmode development environment"
            '';
          };
      }
    );
}
