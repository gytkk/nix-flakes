# Agenix secrets configuration
# Reference: https://github.com/ryantm/agenix
#
# Usage:
#   1. Add your public key below
#   2. Create encrypted secrets: agx -e secret-name.age
#   3. Reference in NixOS config: age.secrets.secretName.file = ./secret-name.age;
#
# NixOS secrets are decrypted under /run/agenix. Home Manager consumers should
# use the path exposed by config.age.secrets.<name>.path.
let
  # Primary administrator SSH public key (for editing and recovery)
  agenixAdmin = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhE4Uakcz7usa0aetMqb99LYybOQ0I+sWKOiAidmBio";

  # Host SSH public keys (for host-specific secrets)
  pylv-sepia = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC6EAZczgXONlXiwh946SidpRKSMw7fehg0u2L5SkHmd";
  pylv-onyx = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8Iug3LblOeh1VqwAwzynFPo5PGkPBsmZBHTYIZxCsy";

  # Devsisters machine SSH public keys
  devsisters-macbook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDdeZoty0uKpSDJ8sUGFwsMEEBYcuajo30lHlUHh8RMi";
  devsisters-macstudio = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHGIGT6Zgg4TW74umgyjlpk1b056LXDoC1kbBfPcqRuz";

  # Key groups
  adminRecipients = [ agenixAdmin ];
  allHosts = [
    pylv-sepia
    pylv-onyx
  ];
  devsistersHosts = [
    devsisters-macbook
    devsisters-macstudio
  ];
  sepiaRecipients = adminRecipients ++ [ pylv-sepia ];
  onyxRecipients = adminRecipients ++ [ pylv-onyx ];
  devsistersRecipients = adminRecipients ++ devsistersHosts;
  allEnvironmentRecipients = adminRecipients ++ allHosts ++ devsistersHosts;
in
{
  # Cloudflare Tunnel token for pylv-sepia
  "cloudflare-tunnel-sepia-token.age".publicKeys = sepiaRecipients;

  # Cloudflare Tunnel token for the pylv-onyx Hermes Dashboard
  "cloudflare-tunnel-onyx-token.age".publicKeys = onyxRecipients;

  # Discord bot token for openclaw
  "discord-bot-token.age".publicKeys = onyxRecipients;

  # Databricks OTEL token (devsisters environments only)
  "databricks-token.age".publicKeys = devsistersRecipients;

  # OpenAI API key for Neovim Minuet
  "openai-api-key.age".publicKeys = allEnvironmentRecipients;
}
