{
  lib,
  config,
  flakeDirectory,
  themeExports,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/vim/${path}";
  nvimThemeExports = config.lib.file.mkOutOfStoreSymlink (themeExports.mutableDir "nvim");
  openAIKeySecretName = "openai-api-key";
  openAIKeySecretFile = "${flakeDirectory}/secrets/${openAIKeySecretName}.age";
  hasOpenAIKeySecret = builtins.pathExists openAIKeySecretFile;
in
{
  age.secrets = lib.optionalAttrs hasOpenAIKeySecret {
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
      ${lib.optionalString hasOpenAIKeySecret ''
        vim.g.openai_api_key_path = ${builtins.toJSON config.age.secrets.${openAIKeySecretName}.path}
      ''}
      require('config')
    '';
  };
}
