{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.72.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-ZNYndHrYxYxA6i0fHDDq/SvbzJ1QsKgc93u15cIbxEk=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-l+Qy4c832SsH0uF2oSAywQDFTaNt6X256tooZdCq6Es=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-ue4jt5p/ROm7ksEmhBL7C0FAanA4Z+Q7Haq/3ymf6wA=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-5hCyiW4DH+JjLyDtHqUSDSIBInpJ2h2tq7mrBNDEjlg=";
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
