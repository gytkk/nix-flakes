{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.78.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-Mn/wUcfoaqPMXI7EoZE8uIMyZ22TO6T9zwBf2ALjqEI=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-dbLey5l4ijPI/azXQv9PBQFeIEqLjWDHTzgKz6pYNQw=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-DMXDb3V18mpoDHI6eiF7b5QtVdYvhIrwAEzytmYu1Xs=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-SFbvkATLLApaklSlgvEm+CfBe05T4rBbT8SZRox0428=";
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
