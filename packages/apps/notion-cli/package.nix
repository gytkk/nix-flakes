{
  lib,
  mkTarballCli,
}:

let
  version = "0.23.21";
in
mkTarballCli {
  pname = "notion-cli";
  inherit version;
  platforms = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-hMpNCKtKopVi97LhrdyVTs9DRy+QUJGFTDxKwl7xUFU=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-9pSV4HkfLinlC1om3sqHJ9WNq1/KGsybcNb+BXN3ORQ=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-kxYbUrnR8yaBqxzuuC9TXt/zNvlazTl4vZTeToB1f8Y=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-QJHPQvEBTdhNKgLtM1L79t07qyLAjPJIfVweDkPjoz8=";
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
