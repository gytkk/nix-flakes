{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.71.1";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-tr6P5Lm0uu+9Y5l+x5X1lh/lPZMZ/KXreC3BzARY87Y=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-tzhbGdXwc7ks5izj5CY8+URD+q329mU40NYRDpJJ6YQ=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-Aw0X0ba1mTdGIGdRgQaXB3iwKrdNYZ4JmAwDueSkTZ8=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-hWKgKLnjBLyTS4MdGUv4TlKNnrXuWfcAgAqDeuXX2e0=";
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
