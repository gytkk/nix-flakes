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
  version = "2.1.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@tobilu/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-TxsADFudqjb89dBSKNeWb9ffh2B69XL8ozYFl/ZChuY=";
  };

  sourceRoot = "package";

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-rBQm9/5SJ+Sroe98zgkGAr2zFDMEZzpW0UXtU+KIVgc=";

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
