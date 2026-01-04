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
  gyutak = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG8W9FHKr99lQs1+t8zjB3rCtCfgfbxbmmazj/R1BVb0";

  # Host SSH public keys (for host-specific secrets)
  pylv-sepia = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC6EAZczgXONlXiwh946SidpRKSMw7fehg0u2L5SkHmd";

  # Key groups
  allUsers = [ gyutak ];
  allHosts = [ pylv-sepia ];
in
{
  # Cloudflare Tunnel token for pylv-sepia
  "cloudflare-tunnel-token.age".publicKeys = allUsers ++ allHosts;
}
