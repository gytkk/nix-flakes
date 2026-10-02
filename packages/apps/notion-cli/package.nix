{
  lib,
  mkTarballCli,
}:

let
  version = "0.23.15";
in
mkTarballCli {
  pname = "notion-cli";
  inherit version;
  platforms = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-MQR0rI4GuO12QazP9Q1KnABD7P002XRRcX8a1VsRjkI=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-noIkLOj7IH+8x9LhixDfqoTKEB1NNmZu9wDhTNmVoT0=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-E65Hy2BwNwD0/fprb7A6HhxG2Qs8OX0a/BRhZ3vQg80=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-PwznfMk7EPwCYZIfYd0XfuU61QqYPRGaPpblukMyMu0=";
    };
  };

  url = platform: "https://ntn.dev/releases/v${version}/ntn-${platform.target}.tar.gz";
  sourceRoot = platform: "ntn-${platform.target}";

  extraInstall = ''
    install -Dm644 README.md "$out/share/doc/notion-cli/README.md"
    install -Dm644 LICENSE.md "$out/share/licenses/notion-cli/LICENSE.md"
  '';

  meta = {
    description = "Official Notion CLI for Workers and public API operations";
    homepage = "https://github.com/makenotion/cli";
    license = lib.licenses.mit;
    mainProgram = "ntn";
  };
}
