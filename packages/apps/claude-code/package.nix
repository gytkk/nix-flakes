{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  procps,
  ripgrep,
  bubblewrap,
  socat,
}:

let
  version = "2.1.296";

  baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  platformMap = {
    "aarch64-darwin" = {
      suffix = "darwin-arm64";
      hash = "sha256-ybU0Fje+y9Qj3f/FslSvtkVoKjhoy3CLvGzA57tBmTc=";
    };

    "x86_64-darwin" = {
      suffix = "darwin-x64";
      hash = "sha256-pr9PML4kEFOpI/OCCtI8WZHS9awpNbOo3WTaIY2cxgM=";
    };

    "x86_64-linux" = {
      suffix = "linux-x64";
      hash = "sha256-JJcuO8hZ+rK0btTB5R99YTDwbTvVUIEaEUZA3jNw0N4=";
    };

    "aarch64-linux" = {
      suffix = "linux-arm64";
      hash = "sha256-8fbpbg2DQrnb9B1+iCVTl6alLOPYc2rWpMa1nJti/vo=";
    };
  };

  platform =
    platformMap.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

  src = fetchurl {
    url = "${baseUrl}/${version}/${platform.suffix}/claude";
    hash = platform.hash;
  };

  runtimePath = lib.makeBinPath (
    [
      procps
      ripgrep
    ]
    ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [
      bubblewrap
      socat
    ]
  );
in
stdenvNoCC.mkDerivation {
  pname = "claude-code";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ${src} $out/bin/claude
    wrapProgram $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --prefix PATH : "${runtimePath}"
    runHook postInstall
  '';

  meta = {
    description = "AI coding assistant in your terminal (native binary)";
    homepage = "https://www.anthropic.com/claude-code";
    license = lib.licenses.unfree;
    platforms = builtins.attrNames platformMap;
    mainProgram = "claude";
  };
}
