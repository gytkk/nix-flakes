{
  lib,
  mkTarballCli,
}:

let
  version = "0.23.13";
in
mkTarballCli {
  pname = "notion-cli";
  inherit version;
  platforms = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-r5+O6GABVHNDg47d/Q7STGsJ6uTKTTLVRB9dmap3MMY=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-blkrR4FqEjIe2o96t9U5u1pE+YJwdODycymCeD/pf4s=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-FxelzPuI3R3LfuN+0O2TsUctyPbh6NaK+zOfkvilY98=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-3lZJFUqFicrU6pMui7uLFz7L5Q5yYVXjp67/+gZlxXI=";
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
