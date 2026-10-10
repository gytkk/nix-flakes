{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.74.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-mqsbkin10dd94huZqoh6YKR5Ib/Ztm5LlBoOip1uOOg=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-TSObdBJoPx61KdVbhR/pIrtGJSeFC3Z9bJuJuhS+P9s=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-57C9xtaTGk5v1c5AN+ESWgc+xs84zXLxs72K7s/eUfU=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-nas58Rl9nMxQHR9ngjTPFflOi4Sqc0m6hxA6WGbdeTs=";
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
