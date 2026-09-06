{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.56.7";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-J4jxy2WujrbWl6+qZAhW/Jx+kXEC/XSiiLxJftVhRMg=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-+bzuhfoDi1icGCI6m8B/dYmNqTt9kXwwRoYslbmnEVk=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-eEtvnZ4+T9NeLQ/27oP6sE0aMvOhMjtfvuRXqQTGLNA=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-u6CMUJlm7NbDMYUauVO3Alz5VNHQebrkY1GUN7BXQQw=";
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
