{
  lib,
  fetchurl,
  stdenvNoCC,
}:

let
  version = "0.14.2";
  src = fetchurl {
    url = "https://registry.npmjs.org/ntn/-/ntn-${version}.tgz";
    hash = "sha256-N/+UU+OmD4/BRxcEifOGdFABClzvZg0Sv5MSXDEoP00=";
  };

  platformSuffix =
    {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
      x86_64-darwin = "darwin-x64";
      aarch64-darwin = "darwin-arm64";
    }.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported system for ntn: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "notion-cli";
  inherit version src;

  sourceRoot = "package";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "dist/ntn-${platformSuffix}/ntn" "$out/bin/ntn"
    install -Dm644 README.md "$out/share/doc/notion-cli/README.md"
    install -Dm644 LICENSE.md "$out/share/licenses/notion-cli/LICENSE.md"

    runHook postInstall
  '';

  meta = {
    description = "Official Notion CLI for Workers and public API operations";
    homepage = "https://github.com/makenotion/cli";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "ntn";
  };
}
