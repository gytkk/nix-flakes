{
  lib,
  stdenvNoCC,
  bun,
  src,
  hash,
}:

assert lib.assertMsg (bun.version == "1.3.13") "trading-agent dependencies require Bun 1.3.13";
stdenvNoCC.mkDerivation {
  pname = "trading-agent-bun-deps";
  version = "1";
  src = builtins.path {
    path = "${src}/web-admin";
    name = "trading-agent-web-manifest";
    filter =
      path: type:
      type == "regular"
      && builtins.elem (baseNameOf path) [
        "package.json"
        "bun.lock"
      ];
  };

  nativeBuildInputs = [ bun ];
  dontConfigure = true;
  dontFixup = true;

  buildPhase = ''
    runHook preBuild
    export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
    mkdir -p "$BUN_INSTALL_CACHE_DIR"
    bun install --frozen-lockfile --ignore-scripts --no-progress --backend=copyfile
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R node_modules "$out/node_modules"
    runHook postInstall
  '';

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = hash;
}
