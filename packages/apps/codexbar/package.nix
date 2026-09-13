{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.60.1";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-/muojSl78da1dM0INEj2UhIBJvZyINWkttzFBATnxMk=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-uautZZ6Mpp1E1ERLYljOeuDj4vFferUW87Sl4sHD5Uw=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-gBn4UTsd+2cEMhb31rtWovMyUWRhaXlMsxFHJ0CiovM=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-+ulzd+RanROK5hfpR/2Atq8ER2wUl3fST8d7CkceWNg=";
    };
  };

  platform =
    platformMap.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/steipete/CodexBar/releases/download/v${version}/CodexBarCLI-v${version}-${platform.target}.tar.gz";
    hash = platform.hash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "codexbar";
  inherit version src;

  dontStrip = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/codexbar
    cp -R ./* $out/lib/codexbar/
    ln -s $out/lib/codexbar/CodexBarCLI $out/bin/codexbar
    runHook postInstall
  '';

  meta = {
    description = "CLI for Codex and Claude usage and cost data";
    homepage = "https://codex.bar";
    license = lib.licenses.mit;
    platforms = builtins.attrNames platformMap;
    mainProgram = "codexbar";
  };
}
