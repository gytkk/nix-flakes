{
  lib,
  bash,
  buildNpmPackage,
  fetchurl,
  nodejs_22,
  python3,
}:

buildNpmPackage rec {
  pname = "qmd";
  version = "2.8.3";

  src = fetchurl {
    url = "https://registry.npmjs.org/@tobilu/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-LmCCmROgxkYjSpBc79YQQxZ6E5L9z9GbxU+JCvicoPA=";
  };

  sourceRoot = "package";

  # The published tarball contains dist/ but omits the prepare hook dependency.
  postPatch = ''
    substituteInPlace package.json \
      --replace-fail '"prepare": "node scripts/install-hooks.mjs && node scripts/build.mjs",' ""
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-1HJWDUpwXCP0U+IwaSAYfk+OpCElv0r4GESGDzIIt6Y=";

  nodejs = nodejs_22;
  dontNpmBuild = true;
  nativeBuildInputs = [ python3 ];

  postInstall = ''
    cat > $out/bin/qmd <<EOF
    #!${bash}/bin/bash
    exec ${nodejs_22}/bin/node "$out/lib/node_modules/@tobilu/qmd/dist/cli/qmd.js" "\$@"
    EOF
    chmod +x $out/bin/qmd
  '';

  meta = {
    description = "Query Markup Documents CLI";
    homepage = "https://github.com/tobi/qmd";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "qmd";
  };
}
