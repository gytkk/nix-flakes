{
  lib,
  buildNpmPackage,
  src,
  version,
}:

# 고정된 src의 ap-web SPA를 buildNpmPackage로 오프라인 빌드한다.
# package.nix가 결과를 server/static/web-ui에 주입해 서버에서 제공한다.
buildNpmPackage {
  pname = "omnigent-web-ui";
  inherit version;

  # The SPA is the ``ap-web`` subtree of the omnigent checkout.
  src = "${src}/ap-web";

  npmDepsHash = "sha256-zgrihNaPy7vRs2PlCsHf3LWorPDU1784+tqv+eufpag=";

  # 런타임 번들과 무관한 tsc 버전 차이로 빌드가 실패하지 않도록 Vite만 실행한다.
  # 패키지 루트 밖을 가리키는 기본 outDir 대신 로컬 dist에 출력한다.
  buildPhase = ''
    runHook preBuild
    ./node_modules/.bin/vite build --outDir dist --emptyOutDir
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r dist/. $out/
    runHook postInstall
  '';

  meta = {
    description = "Omnigent browser web UI (ap-web SPA) prebuilt for the Nix sandbox";
    homepage = "https://omnigent.ai";
    license = lib.licenses.asl20;
    platforms = lib.platforms.unix;
  };
}
