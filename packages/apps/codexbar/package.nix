{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.56.6";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-1Br0JnxwdNJAJD32dZsjpvAFy7v5QSvevGOT24xohdQ=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-/eOC7tOd0XiPEeSICg3tOi26djA/cKnrvlvqi46W8qQ=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-WjXhgSqum32fYFIIveMwiBAuVmMlfHwg+bELQKvSbNc=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-QBXyhuCkIS1hcjhOBlzkg8zAhpcS8XLz9OykfZNK8Kk=";
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
