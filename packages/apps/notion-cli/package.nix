{
  lib,
  mkTarballCli,
}:

let
  version = "0.23.18";
in
mkTarballCli {
  pname = "notion-cli";
  inherit version;
  platforms = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-JJbhzGSS8XMdOYuQc+v4s3VSwpYvepHvEdaqlTRD1jU=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-VDLnKdkPh5kSHc20BjWEgxkrEleCMSrt64jU8+8d/7Q=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-e/lsfMAg38YtwrSlwtRn44hEuAbBQfw8bL4xkqkj6qE=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-+Cwdb0sLxCR9Ujs6krBJjmGkKkTzNujWTnGD91thGrk=";
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
