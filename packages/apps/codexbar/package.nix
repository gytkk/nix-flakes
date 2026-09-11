{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.59.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-echiyfpITq6He9qBbSgKrXQJObTuZSuQFKZSj8yuQXE=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-UZZsTADsTH62/JI7viwRu+pasj4Z5xPnB7kYFpBueUk=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-ryGIHKdUYyzOXQCaugzkbq+eNgGydhZqTJx+uZdYYuY=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-v3WSrUVY2WiempKq9l8rq/Pv4FR5yMi3zeTN1juy4D8=";
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
