{
  config,
  lib,
  username,
  ...
}:
{
  age.secrets."openai-api-key" = {
    file = ../../secrets/openai-api-key.age;
    owner = username;
    group = "users";
    mode = "0400";
  };
  age.secrets."jev-api-key" = lib.mkIf config.home-manager.users.${username}.modules.jev.enable {
    file = ../../secrets/jev-api-key.age;
    owner = username;
    group = "users";
    mode = "0400";
  };
}
