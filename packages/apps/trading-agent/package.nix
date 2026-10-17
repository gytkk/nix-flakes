{
  lib,
  rustPlatform,
  callPackage,
  src,
  version,
  revision,
  frontendDepsHash ? "sha256-QJOhvR1JKfM1jQFQQybNYQ6ib+jjgppJJYmYDay+O8U=",
}:

let
  frontend = callPackage ./frontend.nix {
    inherit src;
    depsHash = frontendDepsHash;
  };
in
rustPlatform.buildRustPackage {
  pname = "trading-agent";
  inherit version src;

  cargoLock.lockFile = "${src}/Cargo.lock";
  cargoBuildFlags = [
    "-p"
    "trade-engine"
    "--bins"
  ];
  cargoTestFlags = [ "--workspace" ];

  postInstall = ''
    mkdir -p "$out/share/trading-agent/web"
    cp -R ${frontend}/. "$out/share/trading-agent/web/"
    test -f "$out/share/trading-agent/web/index.html"
    test -z "$(find "$out/share/trading-agent/web" -type l -print -quit)"
  '';

  passthru = { inherit frontend revision; };

  meta = {
    description = "Auditable trading runtime and read-only web administration";
    license = lib.licenses.unfree;
    mainProgram = "trade-engine";
    platforms = [ "x86_64-linux" ];
  };
}
