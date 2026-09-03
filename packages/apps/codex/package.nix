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
  version = "0.153.1";

  platformMap = {
    "aarch64-darwin" = {
      target = "aarch64-apple-darwin";
      codexHash = "sha256-gY88ZcaXOuVFhrpS+ON8dnPz9bjgnHSFjBniXHRHkiY=";
      codeModeHostHash = "sha256-SoeqiaGYl268aKhQF7NiNO3RsSbftj2UwQog/Pq4FHk=";
    };

    "x86_64-darwin" = {
      target = "x86_64-apple-darwin";
      codexHash = "sha256-GCG6qa9idGFIGnY//Ibj90+WFmH+iaaWXDA24W28SyI=";
      codeModeHostHash = "sha256-GE2wHxD2oC2t8ka5FEDMFtdaC9tA/0kcSW+IBTiJqSI=";
    };

    "x86_64-linux" = {
      target = "x86_64-unknown-linux-musl";
      codexHash = "sha256-CBiM3sQMKQnoSznYTtGtAPA6m/4DRv1CLvWQ+n0jSH8=";
      codeModeHostHash = "sha256-RTnhBlluIDyfburyD+MoqXUUR9fWVhviWWieoHlfg7A=";
    };

    "aarch64-linux" = {
      target = "aarch64-unknown-linux-musl";
      codexHash = "sha256-fCbp9uQkv2GMM66CY/OzocHMMsgr+/1fJ7bIFAJhhmQ=";
      codeModeHostHash = "sha256-JeIWCBhwbkjFEVUB1ZhvuMPoWsciZ/YZxJRLXhRlzEA=";
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
