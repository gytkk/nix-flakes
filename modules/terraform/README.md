# Terraform Module

This module provides Terraform version management using [stackbuilders/nixpkgs-terraform](https://github.com/stackbuilders/nixpkgs-terraform).

## Features

- **Reproducible builds**: Terraform versions are locked in flake.lock
- **Multiple versions**: Support for installing multiple terraform versions
- **Binary cache**: Faster installations through stackbuilders' binary cache
- **Automatic updates**: Leverage upstream CI for version tracking
- **Shell aliases**: Convenient access to specific terraform versions

## Configuration

### Basic Usage

```nix
modules.terraform = {
  enable = true;
  defaultVersion = "1.12.2";
};
```

### Multiple Versions

```nix
modules.terraform = {
  enable = true;
  versions = [ "1.10.2" "1.12.2" "latest" ];
  defaultVersion = "1.12.2";
  installAll = true;
};
```

## Options

### `enable`

- **Type**: `bool`
- **Default**: `false`
- **Description**: Enable terraform module

### `versions`

- **Type**: `list of strings`
- **Default**: `[ "1.12.2" ]`
- **Description**: List of terraform versions to install
- **Available versions**: `"1.10.2"`, `"1.12.2"`, `"latest"`

### `defaultVersion`

- **Type**: `string`
- **Default**: `"1.12.2"`
- **Description**: Default terraform version to use

### `installAll`

- **Type**: `bool`
- **Default**: `false`
- **Description**: Install all configured terraform versions

## Shell Aliases

When multiple versions are installed, the module creates aliases for each version:

- `terraform-1.10.2` → terraform version 1.10.2
- `terraform-1.12.2` → terraform version 1.12.2
- `terraform-latest` → latest terraform version
