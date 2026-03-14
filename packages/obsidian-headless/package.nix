{
  lib,
  buildNpmPackage,
  fetchurl,
  nodejs_22,
  python3,
}:

buildNpmPackage rec {
  pname = "obsidian-headless";
  version = "0.0.6";

  src = fetchurl {
    url = "https://registry.npmjs.org/${pname}/-/${pname}-${version}.tgz";
    hash = "sha256-cBDDxUsprBspTBYDym6CQ4aEP4Rwdh4tSZEdCYRXhNQ=";
  };

  sourceRoot = "package";

  # GitHub repo에 pnpm-lock.yaml만 있으므로, 별도 생성한 package-lock.json 사용
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-U7pJX8DEPq9bOBm7pZ1hR41A+I4xoUYkQp63a5kKeSU=";

  nodejs = nodejs_22;
  dontNpmBuild = true;

  # better-sqlite3 네이티브 빌드 시 node-gyp에 python3 필요
  nativeBuildInputs = [ python3 ];

  meta = {
    description = "Headless client for Obsidian Sync";
    homepage = "https://github.com/obsidianmd/obsidian-headless";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    mainProgram = "ob";
  };
}
