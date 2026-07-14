{
  lib,
  fetchurl,
  stdenvNoCC,
}:

let
  version = "1.7.0";

  platforms = {
    x86_64-linux = {
      name = "linux_amd64";
      hash = "sha256-cffqoN3kaNcQXrtAtvQLoEokHnZw/Tk2Z825tMCG1jY=";
    };
    aarch64-linux = {
      name = "linux_arm64";
      hash = "sha256-p0e6TsEGvqU/AbKfTB1t9fZ/4o/LGLXysg+pN+XWb80=";
    };
    x86_64-darwin = {
      name = "darwin_amd64";
      hash = "sha256-w07txSEG9QbNF/VgSZk9w6BvyaK9y1lCkwv/qaGAbjI=";
    };
    aarch64-darwin = {
      name = "darwin_arm64";
      hash = "sha256-vUfNLye5PxDjc6/rWXFYBbzXZ5CV0IIk7cXguZj/6dk=";
    };
  };

  platform =
    platforms.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system for databricks-cli: ${stdenvNoCC.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/databricks/cli/releases/download/v${version}/databricks_cli_${version}_${platform.name}.tar.gz";
    inherit (platform) hash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "databricks-cli";
  inherit version src;

  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 databricks "$out/bin/databricks"

    runHook postInstall
  '';

  meta = {
    description = "Databricks CLI for the Databricks platform (Go implementation)";
    homepage = "https://github.com/databricks/cli";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames platforms;
    mainProgram = "databricks";
  };
}
