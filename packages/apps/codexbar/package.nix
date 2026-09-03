{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.56.4";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-LaCVIoYOcCLTbiqWsoa3SbWCyJcQIV2cQzR+ynES020=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-yyx/S4W2iIhoTrTp93+k0MdKdiMAxp4sBiX1lPD7lP0=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-U55zNBUsBXoxgXSshyDAQck7Pvnff7mCNQqFhCfEBJM=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-rwIEfFJCavMsSyrM9eaWay6gp+t/AMG+l1Xkt2XRi3s=";
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
