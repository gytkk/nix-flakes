{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Custom Scala 2.12.10 derivation
  scala_2_12_10 = pkgs.stdenv.mkDerivation rec {
    pname = "scala";
    version = "2.12.10";

    src = pkgs.fetchurl {
      url = "https://downloads.lightbend.com/scala/${version}/scala-${version}.tgz";
      sha256 = "sha256-OxK9ozAP7dkfZPx/kWX9RcWDKLG3YK8kym/+kuOwZWo=";
    };

    nativeBuildInputs = [ pkgs.makeWrapper ];
    buildInputs = [ pkgs.jre ];

    installPhase = ''
      mkdir -p $out
      cp -r . $out

      # Create wrapper scripts
      mkdir -p $out/bin
      for prog in fsc scala scalac scaladoc scalap; do
        if [[ -f $out/bin/$prog ]]; then
          wrapProgram $out/bin/$prog \
            --prefix PATH ":" ${pkgs.jre}/bin \
            --set JAVA_HOME ${pkgs.jre}
        fi
      done
    '';

    meta = with lib; {
      description = "Scala programming language";
      homepage = "https://scala-lang.org/";
      license = licenses.bsd3;
      platforms = platforms.all;
    };
  };
in
{
  home.packages = [
    scala_2_12_10
    pkgs.sbt # SBT from current nixpkgs
  ];

  # Set SCALA_HOME environment variable
  home.sessionVariables = {
    SCALA_HOME = "${scala_2_12_10}";
  };
}