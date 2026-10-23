{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.80.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-q6EtgJmUMlq9faCwZ6qLBctbTDuAPcX+rY+FlFMmBTY=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-dJ3KTkUTGJJ8rpSIbJvb0kP4xkeDhcfDbLrz+SmnIxg=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-PCnQyuJrtVvS9NF1zQR8GPNpMi7Ql+Pp9kfdpwPBUHY=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-SFbCxpv53MSWOY9LUMG4l+VGhi5pJ0ELuN5l1nRxo9s=";
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
