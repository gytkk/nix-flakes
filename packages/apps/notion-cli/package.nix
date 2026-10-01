{
  lib,
  mkTarballCli,
}:

let
  version = "0.23.14";
in
mkTarballCli {
  pname = "notion-cli";
  inherit version;
  platforms = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-/EneGHbNhvruBv4UzCQq0hXg9SEBiJgCA+SwCYIcQsA=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-YcPeE+j9qk0+mIknNU19Wf2lZALjwVYXUEOOX1BmDeA=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-5s/EAJ98Vpv90UfeR9vO4YLLXZvmnWgYFslxXs174pg=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-4X/tCEN7rGsHyoU7vpMHYVwJJOHRRmY1nhqQprHneGQ=";
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
