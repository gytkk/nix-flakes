{
  config,
  flakeDirectory,
  lib,
  osConfig ? null,
  themeExports,
  ...
}:

let
  cfg = config.modules.vim;
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/vim/${path}";
  nvimThemeExports = config.lib.file.mkOutOfStoreSymlink (themeExports.mutableDir "nvim");
  openAIKeySecretName = "openai-api-key";
  openAIKeySecretFile = ../../secrets/openai-api-key.age;
  usesSystemAgenix = osConfig != null;
  openAIKeySecretPath =
    if usesSystemAgenix then
      osConfig.age.secrets.${openAIKeySecretName}.path
    else
      config.age.secrets.${openAIKeySecretName}.path;
in
{
  options.modules.vim.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Neovim module";
  };

  config = lib.mkIf cfg.enable {
    age.secrets = lib.mkIf (!usesSystemAgenix) {
      "${openAIKeySecretName}".file = builtins.toPath openAIKeySecretFile;
    };

    xdg.configFile."nvim/lua/config".source = mkSymlink "files/config";
    xdg.configFile."nvim/themes".source = nvimThemeExports;

    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;

      initLua = ''
        vim.g.nix_flakes_theme = ${builtins.toJSON config.modules.commonTheme}
        vim.g.openai_api_key_path = ${builtins.toJSON openAIKeySecretPath}
        require('config')
      '';
    };
  };
}
