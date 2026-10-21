{
  lib,
  mkTarballCli,
}:

let
  version = "0.23.23";
in
mkTarballCli {
  pname = "notion-cli";
  inherit version;
  platforms = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-EeaRpDKOtZ1pJTBpdQLHXmclOB8YqZxabPkIqPXVZjc=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-k4vQi31HG015fmN4u1DPdNprJ8ACYS3yQ0zxuu6SN40=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-HYPri58cGJaU/+7G42IgDHdFDg9IZEUd7Ertn6OkRgg=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-3MBYpBroZUFwEHPCkC7C7FtVVYEK+lILnzlbDpAr2/0=";
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
