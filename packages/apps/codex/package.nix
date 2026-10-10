{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  jq,
  libcap,
  ncurses,
  openssl,
  zlib,
}:

let
  version = "0.162.1";

  platformMap = {
    "aarch64-darwin" = {
      target = "aarch64-apple-darwin";
      hash = "sha256-iON8zd9aD06p3BvhPGaiqU+cLRoE86zpBT1xs5OeiF0=";
    };

    "x86_64-darwin" = {
      target = "x86_64-apple-darwin";
      hash = "sha256-iUrCCv6BnU+ipL6M0nxU/WBjOLhgNujtm2yZeMLceu0=";
    };

    "x86_64-linux" = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-pnb1ciquDYbL43ZDMvCOqx/didwKMAs61P+/SGEfo+M=";
    };

    "aarch64-linux" = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-U6nOC5S+snpj/esvdwTZUZnheziYqjO2BGGhqTrA2Is=";
    };
  };

  platform =
    platformMap.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit version;

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-${platform.target}.tar.gz";
    inherit (platform) hash;
  };

  dontUnpack = true;

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    libcap
    ncurses
    openssl
    zlib
    stdenv.cc.cc.lib
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    tar xzf "$src" -C "$out"
    runHook postInstall
  '';

  preFixup = lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
    addAutoPatchelfSearchPath "$out/codex-resources/voice/lib"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ jq ];
  installCheckPhase = ''
    runHook preInstallCheck
    bash ${./check-package.sh} "$out" "$src" "${version}" "${platform.target}"
    runHook postInstallCheck
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames platformMap;
    mainProgram = "codex";
  };
}
