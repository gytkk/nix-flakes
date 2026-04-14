{
  lib,
  buildNpmPackage,
}:

let
  src = lib.cleanSourceWith {
    src = ../../apps/openclaw-cron-dashboard/frontend;
    filter =
      path: _type:
      let
        baseName = baseNameOf (toString path);
      in
      !(baseName == "dist" || baseName == "node_modules");
  };
in
buildNpmPackage {
  pname = "openclaw-cron-dashboard-frontend";
  version = "0.1.0";

  inherit src;

  npmDepsHash = "sha256-7Y9xMuEXQFvuF+niDDQxrQvH6SOlCnqQbxJbLEKqS5o=";

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r dist/. $out/
    runHook postInstall
  '';

  meta = {
    description = "Frontend bundle for the OpenClaw cron dashboard";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
