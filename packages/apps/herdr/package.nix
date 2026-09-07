{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.9.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-aarch64";
      hash = "sha256-MrU98JhyYoBZx4mmnwKmuOKeFN3yZxFCHzRj9wwa7xc=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-0MkgsqEmp0gJ+hSRQRyaCXpEeGysnCylG4GKmVWBzxY=";
    };

    "x86_64-linux" = {
      target = "linux-x86_64";
      hash = "sha256-T6GgEVjdgEPaktMbJweAsNzBBgMDjZthysTYGrY/tx8=";
    };

    "aarch64-linux" = {
      target = "linux-aarch64";
      hash = "sha256-nI2yD7fnQnsTjVNnET8WIf/TGfL2XW8AniWUApEV8NI=";
    };
  };

  platform =
    platformMap.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-${platform.target}";
    hash = platform.hash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "herdr";
  inherit version;

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ${src} $out/bin/herdr
    runHook postInstall
  '';

  meta = {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://herdr.dev";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames platformMap;
    mainProgram = "herdr";
  };
}
