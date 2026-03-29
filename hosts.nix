{
  "pylv-sepia" = {
    system = "x86_64-linux";

    username = "gytkk";
    homeDirectory = "/home/gytkk";

    # Home Manager configuration for this host
    homeConfig = ./base/pylv/home.nix;

    # Extra home manager modules for this host
    extraHomeModules = [ ./base/pylv/sepia.nix ];
  };

  "pylv-onyx" = {
    system = "x86_64-linux";

    username = "gytkk";
    homeDirectory = "/home/gytkk";

    # Home Manager configuration for this host
    homeConfig = ./base/pylv/home.nix;

    extraHomeModules = [ ./base/pylv/onyx.nix ];
  };

  # Darwin hosts
  "devsisters-macbook" = {
    system = "aarch64-darwin";
    username = "gyutak";
    homeDirectory = "/Users/gyutak";
    homeConfig = ./base/devsisters/home.nix;
    isDarwin = true;
  };

  "devsisters-macstudio" = {
    system = "aarch64-darwin";
    username = "gyutak";
    homeDirectory = "/Users/gyutak";
    homeConfig = ./base/devsisters/home.nix;
    isDarwin = true;
  };
}
