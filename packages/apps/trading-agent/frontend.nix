{
  lib,
  stdenv,
  bun,
  nodejs_24,
  autoPatchelfHook,
  callPackage,
  src,
  depsHash,
}:

let
  bunDeps = callPackage ./bun-deps.nix {
    inherit src;
    hash = depsHash;
  };
in
assert lib.assertMsg (
  stdenv.hostPlatform.system == "x86_64-linux"
) "trading-agent frontend is validated only on x86_64-linux";
stdenv.mkDerivation {
  pname = "trading-agent-web";
  version = "0.1.0";
  inherit src;

  nativeBuildInputs = [
    bun
    nodejs_24
    autoPatchelfHook
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
  dontConfigure = true;

  postUnpack = ''
    sourceRoot="$sourceRoot/web-admin"
    cp -R ${bunDeps}/node_modules "$sourceRoot/node_modules"
    chmod -R u+w "$sourceRoot/node_modules"
  '';

  buildPhase = ''
    runHook preBuild
    patchShebangs node_modules
    # Bun also installs musl variants; this package builds for glibc Linux.
    mapfile -d "" -t nativeAddons < <(find node_modules -path '*linux-x64-gnu*' -name '*.node' -print0)
    autoPatchelf "''${nativeAddons[@]}"
    bun run typecheck
    bun run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R dist/. "$out/"
    test -f "$out/index.html"
    test -z "$(find "$out" -type l -print -quit)"
    runHook postInstall
  '';

  passthru = { inherit bunDeps; };
}
