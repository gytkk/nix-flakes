{
  lib,
  mkTarballCli,
}:

let
  version = "0.23.19";
in
mkTarballCli {
  pname = "notion-cli";
  inherit version;
  platforms = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-i6nqY5gdgiZUKGB98bXAjFQa/sQPfRVqKsf6vNBtTOA=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-xpXV49iQeCUwKCYxMR4iYBCe05BZ70bzfS8g4AcMk+0=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-Qwif6bWj5QsNG1g7XhEDz8j+9rWFhY6b6Xc6FD0PM5I=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-sL+DvlpRi4TdvQs3JOmiabOoDSATPk974UM+4TuLUzA=";
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
