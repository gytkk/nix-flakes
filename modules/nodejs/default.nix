{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Install global npm packages using nodePackages
  home.packages = with pkgs.nodePackages; [
    "@nestjs/cli"

    # Additional common global packages can be added here
    # typescript
    # ts-node
    # nodemon
    # prettier
    # eslint
  ];
}
