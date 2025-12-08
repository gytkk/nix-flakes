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
  gyutak = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhE4Uakcz7usa0aetMqb99LYybOQ0I+sWKOiAidmBio";

  # Host SSH public keys (optional, for host-specific secrets)
  # pylv-sepia = "ssh-ed25519 AAAA...";

  # Key groups
  allUsers = [ gyutak ];
in
{
  # Example: API token accessible by all users
  # "api-token.age".publicKeys = allUsers;

  # Example: Host-specific secret
  # "host-secret.age".publicKeys = [ gyutak pylv-sepia ];
}
