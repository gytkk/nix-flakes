# Agenix secrets configuration
# Reference: https://github.com/ryantm/agenix
#
# Usage:
#   1. Add your public key below
#   2. Create encrypted secrets: agenix -e secret-name.age
#   3. Reference in NixOS config: age.secrets.secretName.file = ./secret-name.age;
#
# The decrypted secret will be available at /run/agenix/secretName
let
  # User SSH public keys (for encrypting secrets)
  gytkk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhE4Uakcz7usa0aetMqb99LYybOQ0I+sWKOiAidmBio";
  gytkkCurrent = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH4fQ+YuQEWjtoSxCYydHbmerei0EQ2QC/z7GQZWjZmU";

  # Host SSH public keys (for host-specific secrets)
  pylv-sepia = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC6EAZczgXONlXiwh946SidpRKSMw7fehg0u2L5SkHmd";
  pylv-onyx = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8Iug3LblOeh1VqwAwzynFPo5PGkPBsmZBHTYIZxCsy";

  # Devsisters machine SSH public keys
  devsisters-macbook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDdeZoty0uKpSDJ8sUGFwsMEEBYcuajo30lHlUHh8RMi";
  devsisters-macstudio = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHGIGT6Zgg4TW74umgyjlpk1b056LXDoC1kbBfPcqRuz";

  # Key groups
  allUsers = [ gytkk ];
  allHosts = [
    pylv-sepia
    pylv-onyx
  ];
  devsistersHosts = [
    devsisters-macbook
    devsisters-macstudio
  ];
in
{
  # Cloudflare Tunnel token for pylv-sepia
  "cloudflare-tunnel-sepia-token.age".publicKeys = allUsers ++ allHosts;

  # Cloudflare Tunnel token for pylv-onyx Open WebUI
  "cloudflare-tunnel-onyx-token.age".publicKeys = allUsers ++ allHosts;

  # Discord bot token for openclaw
  "discord-bot-token.age".publicKeys = allUsers ++ allHosts;

  # Discord user token for discordo terminal client
  "discordo-token.age".publicKeys = [
    gytkk
    gytkkCurrent
  ] ++ allHosts ++ devsistersHosts;

  # Open WebUI initial admin environment file
  "open-webui-env.age".publicKeys = [
    gytkk
    gytkkCurrent
  ]
  ++ allHosts;

  # Google Workspace CLI credentials for obsidian-maintenance calendar sync
  "gws-credentials.age".publicKeys = allUsers ++ allHosts;

  # Databricks OTEL token (devsisters environments only)
  "databricks-token.age".publicKeys = allUsers ++ devsistersHosts;
}
