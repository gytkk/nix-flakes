{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  nodejs_24,
  jq,
  autoPatchelfHook,
  versionCheckHook,
}:

buildNpmPackage rec {
  pname = "cf";
  version = "1.0.0-beta.5";

  src = fetchurl {
    url = "https://registry.npmjs.org/cf/-/cf-${version}.tgz";
    hash = "sha512-IKGKDAQNs8hbu7jOt3qSWKxDjmJTS+hcHCJ5B0IkF7gZ3RmEfMTUxZ0Fi7GRftjag04J127u8Nk8uppXx3OBZw==";
  };

  sourceRoot = "package";
  npmDepsHash = "sha256-Fc7Kia/Tppa1BnVoYrHoGLceZITEqq/cXYfggUd3JdY=";
  nodejs = nodejs_24;
  dontNpmBuild = true;
  npmFlags = [ "--ignore-scripts" ];
  npmInstallFlags = [ "--omit=dev" ];

  postPatch = ''
    # The published bundle lists development-only file: dependencies absent from npm.
    ${lib.getExe jq} 'del(.devDependencies)' package.json > package.json.tmp
    mv package.json.tmp package.json
    cp ${./package-lock.json} package-lock.json
  '';

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/cf";
  versionCheckProgramArg = "--version";

  meta = {
    description = "Official Cloudflare CLI for resource management and Workers";
    homepage = "https://developers.cloudflare.com/cf/";
    license = with lib.licenses; [
      mit
      asl20
    ];
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    mainProgram = "cf";
  };
}
