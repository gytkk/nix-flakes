{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libcap,
  openssl,
  zlib,
}:

let
  version = "0.156.1";

  platformMap = {
    "aarch64-darwin" = {
      target = "aarch64-apple-darwin";
      codexHash = "sha256-K9ZK8U3t1HeV8va/1dElz3kZmswse6IiFE4IEnERpco=";
      codeModeHostHash = "sha256-JiXQI+K24D0rzEN6Pg4IMcJdPHItKFRjio50kh/3m9k=";
    };

    "x86_64-darwin" = {
      target = "x86_64-apple-darwin";
      codexHash = "sha256-VeNFht7lNyDdlEUQImMv/8njtVskcVrN2UU/01ZqVN8=";
      codeModeHostHash = "sha256-/JaNnnIS1/ux4VRtKDbzsHxfOIEJwFuEKMHz8wkdcgk=";
    };

    "x86_64-linux" = {
      target = "x86_64-unknown-linux-musl";
      codexHash = "sha256-r/RlOag6/4bjxixZK84sUNlTkfnfKJr68DpQwB0UUz0=";
      codeModeHostHash = "sha256-qSnaqfagvdwAwMnmQC3xF7ElrNlvnVVPbJnDLH5mxgg=";
    };

    "aarch64-linux" = {
      target = "aarch64-unknown-linux-musl";
      codexHash = "sha256-VY4SqqbayzNexHJAv5ch24pUdGgG1k8BGFpAP0T3m3I=";
      codeModeHostHash = "sha256-QBmBOLA3mP+owNpMgnqMpYlndOoQS3EQwqLAx1YMvpQ=";
    };
  };

  platform =
    platformMap.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

  mkSrc =
    name: hash:
    fetchurl {
      url = "https://github.com/openai/codex/releases/download/rust-v${version}/${name}-${platform.target}.tar.gz";
      inherit hash;
    };

  codexSrc = mkSrc "codex" platform.codexHash;
  codeModeHostSrc = mkSrc "codex-code-mode-host" platform.codeModeHostHash;
in
stdenvNoCC.mkDerivation {
  pname = "codex";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    libcap
    openssl
    zlib
    stdenv.cc.cc.lib
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    tar xzf ${codexSrc} -C $out/bin
    mv $out/bin/codex-${platform.target} $out/bin/codex
    tar xzf ${codeModeHostSrc} -C $out/bin
    mv $out/bin/codex-code-mode-host-${platform.target} $out/bin/codex-code-mode-host
    runHook postInstall
  '';

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames platformMap;
    mainProgram = "codex";
  };
}
