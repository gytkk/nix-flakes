# Devsisters Module

This module provides authentication and access tools for Devsisters infrastructure, including Vault integration and SSH key signing capabilities.

## What it does

- Installs authentication tools (saml2aws, vault)
- Provides Eclair gem integration for Ruby-based tooling
- Creates custom authentication and SSH signing scripts
- Configures Vault environment for Devsisters cloud access

## Features

### Authentication Tools
- **saml2aws**: SAML-based AWS authentication
- **vault**: HashiCorp Vault client for secret management
- **Eclair Integration**: Ruby gem (ecl) with automatic installation and path management

### Custom Scripts
- **`login`**: Automated login script that combines Vault OIDC and SAML2AWS authentication
- **`sign`**: SSH key signing utility using Vault's SSH client signer

### Environment Configuration
- Sets `VAULT_ADDR=https://vault.devsisters.cloud` for Vault operations

## Requirements

- Nix package manager
- Home Manager
- Ruby 3.1 (automatically installed)
- tmux (for Eclair compatibility)
- Access to Devsisters Vault infrastructure

## Scripts Details

### Login Script (`login`)
Performs authentication to both Vault and AWS:
```bash
login
```
- Authenticates to Vault using OIDC method
- Logs into AWS via SAML with 12-hour session duration
- Disables keychain storage and forces fresh authentication

### Sign Script (`sign`)
Signs SSH keys using Vault's SSH client signer:

```bash
# Sign all keys in ~/.ssh/
sign

# Sign with specific TTL
sign -t 24h

# Sign specific key file
sign ./path/to/private_key

# Use specific role
sign -r developer
```

**Features:**
- Automatically discovers common SSH key types (RSA, Ed25519, ECDSA, DSA)
- Supports custom TTL (time-to-live) for certificates
- Configurable roles (defaults to 'developer')
- Sets valid principals for common system users
- Generates signed certificates with proper permissions (600)

### Eclair Integration
The module creates a wrapper script for the Eclair Ruby gem:
- Automatically installs ecl gem version 3.0.4 if not present
- Manages Ruby gem paths and environment
- Provides `ecl` command for Devsisters-specific tooling

## Usage

After applying this module:

1. **Initial Setup**: Run `login` to authenticate to both Vault and AWS
2. **SSH Access**: Use `sign` to sign your SSH keys for server access
3. **Eclair Tools**: Use `ecl` command for additional Devsisters tooling

## Environment Variables

- `VAULT_ADDR`: Set to `https://vault.devsisters.cloud`
- Ruby gem paths are automatically configured for Eclair integration

## Security Notes

- SSH certificates are created with 600 permissions for security
- SAML2AWS is configured to disable keychain storage for better security practices
- Vault tokens should be refreshed regularly using the login script