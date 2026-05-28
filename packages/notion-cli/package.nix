{
  lib,
  fetchurl,
  stdenvNoCC,
}:

let
  version = "0.14.2";

  platforms = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-RB6ofRUEo+MP9CJk40uFCmWiAkEuvSPB5a8+QFHusUo=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-Is+VUJQLlT0c5yQ6UiXIZj7oG4ASDsfTSDCNRFGFpWk=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-azywrcrh8Lm2T71opDT6yDfQp0mI8CiRrFUV6ewbDPQ=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-FJqfIMtbj8mkGpr107VMZ6vjH2rQQnddNActvHDgBzc=";
    };
  };

  platform =
    platforms.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system for ntn: ${stdenvNoCC.hostPlatform.system}");

  src = fetchurl {
    url = "https://ntn.dev/releases/v${version}/ntn-${platform.target}.tar.gz";
    inherit (platform) hash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "notion-cli";
  inherit version src;

  sourceRoot = "ntn-${platform.target}";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 ntn "$out/bin/ntn"
    install -Dm644 README.md "$out/share/doc/notion-cli/README.md"
    install -Dm644 LICENSE.md "$out/share/licenses/notion-cli/LICENSE.md"

    runHook postInstall
  '';

  meta = {
    description = "Official Notion CLI for Workers and public API operations";
    homepage = "https://github.com/makenotion/cli";
    license = lib.licenses.mit;
    platforms = builtins.attrNames platforms;
    mainProgram = "ntn";
  };
}
