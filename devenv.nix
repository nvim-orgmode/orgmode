{
  pkgs,
  lib,
  inputs,
  config,
  ...
}: {
  # To enable: set `use-nvim = true` in `devenv.local.nix`
  options.use-nvim = lib.mkOption {
    type = lib.types.bool;
    description = "Configure an in-repo Nvim instance";
    default = false;
  };

  config = let
    inherit (pkgs.stdenv.hostPlatform) system;
    use-nvim = config.use-nvim or false;
  in {
    packages = with pkgs;
      [gnumake lemmy-help stylua alejandra]
      ++ (
        if use-nvim
        then [
          (import ./nix/nixvim.nix {
            inherit system pkgs;
            inherit (inputs) nixvim np;
          })
        ]
        else [neovim]
      );

    git-hooks = {
      hooks = {
        alejandra.enable = true;
        stylua.enable = true;
      };
    };

    enterShell = ''
      echo " Nvim Orgmode development environment"
      echo " $(nvim --version | head -n1)"
    '';

    enterTest = ''
      export LUA_PATH="$(pwd)/lua/?.lua;$(pwd)/lua/?/init.lua;$(pwd)/tests/?.lua;$(pwd)/tests/?/init.lua;;"
      make test
    '';

    tasks."orgmode:gen-api-docs" = {
      exec = "make api_docs";
    };
  };
}
