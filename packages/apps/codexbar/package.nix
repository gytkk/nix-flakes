{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.79.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-JpKf1LxaYmh9FJjdpsxHmHYRkuQ9XdNCz39/E1droz4=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-lmTI4UaSbn5DeWdE7Ge79+mHw6vsOF4bDyiT9ElZkQ8=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-+zn2ZWV7fAFsBWVvkbG166B+tkkAnbWhXh8c4Ch9Gts=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-47gTcDiZ4nwrgiRnvzLnP4oX38M06+5BZLZi3ZweIJ0=";
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
