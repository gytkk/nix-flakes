{
  lib,
  stdenv,
  buildNpmPackage,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  nodejs_22,
  zlib,
}:

let
  version = "0.85.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
    hash = "sha512-INxVkLAVfAMju5MojJpmyu/0bMP+r+ffZuS7UqVv32E2JwHBRbcHfELDfmFNvapEbgYfKN2r9OYO1p3TqDBR+g==";
  };
in
buildNpmPackage {
  pname = "pi";
  inherit version src;

  npmDepsHash = "sha256-XZYXKhgq3vxyZkQ2X7lpWBdcDV2grg895GyMsI1Ms6g=";
  sourceRoot = "package";
  makeCacheWritable = true;
  npmInstallFlags = [
    "--omit=dev"
    "--ignore-scripts"
  ];
  dontNpmBuild = true;
  nodejs = nodejs_22;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];

  postPatch = ''
    cp ${./npm-shrinkwrap.json} npm-shrinkwrap.json
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/pi" "$out/bin"
    cp -R . "$out/libexec/pi/"

    find "$out/libexec/pi/node_modules/.bin" -xtype l -delete 2>/dev/null || true

    makeWrapper ${nodejs_22}/bin/node "$out/bin/pi" \
      --add-flags "$out/libexec/pi/dist/cli.js"

    runHook postInstall
  '';

  meta = {
    description = "Coding agent CLI with read, bash, edit, write tools and session management";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "pi";
  };
}
