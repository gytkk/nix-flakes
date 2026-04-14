{
  pkgs,
  username,
  common,
  ...
}:
{
  age.secrets.discord-bot-token = {
    file = ../../secrets/discord-bot-token.age;
    owner = username;
    group = "users";
    mode = "0400";
  };

  environment.systemPackages = with pkgs; [
    common.openclawHybridCli
    bun
    libcap
    nodejs
  ];
}
