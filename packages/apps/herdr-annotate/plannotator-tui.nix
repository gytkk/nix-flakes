{
  lib,
  rustPlatform,
  fetchzip,
  sources ? builtins.fromJSON (builtins.readFile ./sources.json),
}:

rustPlatform.buildRustPackage {
  pname = "plannotator-tui";
  version = sources.plannotatorTui.version;

  src = fetchzip {
    url = "https://github.com/plannotator/plannotator-tui/archive/refs/tags/v${sources.plannotatorTui.version}.tar.gz";
    hash = sources.plannotatorTui.sourceHash;
  };

  cargoHash = sources.plannotatorTui.cargoHash;

  patches = [ ./selection-background.patch ];

  preCheck = ''
    export PLANNOTATOR_DATA_DIR="$TMPDIR/plannotator-test-data"
  '';

  meta = {
    description = "Markdown review TUI with configurable review colors";
    homepage = "https://github.com/plannotator/plannotator-tui";
    license = lib.licenses.mit;
    mainProgram = "plannotator-tui";
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
  };
}
