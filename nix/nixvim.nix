{
  system,
  pkgs,
  nixvim,
  np,
  ...
}: (nixvim.legacyPackages.${system}.makeNixvimWithModule {
  inherit pkgs;

  module = {
    imports = [
      np.nixvimModules.base
      np.nixvimModules.xtras.orgmode
    ];
  };

  extraSpecialArgs = {
    inherit (pkgs) stdenv;
    inherit np;
  };
})
