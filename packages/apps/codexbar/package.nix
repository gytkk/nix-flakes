{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.60.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-Dv39npL8f8tLX47PC/Er7wAVfGdj88VAQ+7zxmAK2gE=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-Mr6DeEhAMK77MYKe/rhYADTzmw41ucxHODnDlh+kue4=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-VA8yfW0FQ7NcaKpxWASf3eAJ+hpUA4+w8KQSDa6Y1fk=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-AeBqHN0eyl8ygu1p9QlFp9xjGRTQrwkOd+zJYZBjHrE=";
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
