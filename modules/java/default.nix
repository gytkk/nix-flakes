{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:

let
  # Java 버전별 패키지 정의
  jdk8 = pkgs.jdk8;
  jdk17 = pkgs.jdk17;

  # Java 버전 전환 스크립트
  javaSwitch = pkgs.writeShellScriptBin "java-switch" ''
    case "$1" in
      8)
        export JAVA_HOME="${jdk8}/lib/openjdk"
        export PATH="${jdk8}/bin:$PATH"
        echo "Switched to Java 8 (OpenJDK 8)"
        java -version
        ;;
      17)
        export JAVA_HOME="${jdk17}/lib/openjdk"
        export PATH="${jdk17}/bin:$PATH"
        echo "Switched to Java 17 (OpenJDK 17)"
        java -version
        ;;
      *)
        echo "Usage: java-switch [8|17]"
        echo "Available versions:"
        echo "  8  - OpenJDK 8"
        echo "  17 - OpenJDK 17"
        exit 1
        ;;
    esac
  '';

in
{
  # Java 패키지 설치 (기본적으로 Java 17만 전역 설치, Java 8은 direnv를 통해서만)
  home.packages = with pkgs; [
    jdk17  # 기본 Java 버전
    javaSwitch  # 버전 전환 스크립트
  ];

  # 기본 Java 환경 (Java 17)
  home.sessionVariables = {
    JAVA_HOME = "${jdk17}/lib/openjdk";
  };

  # direnv용 Java 함수들을 별도 파일로 설치
  home.file.".config/direnv/lib/use_java.sh" = {
    text = ''
      # Java 8 환경 설정
      use_java_8() {
        export JAVA_HOME="${jdk8}/lib/openjdk"
        PATH_add "${jdk8}/bin"
        echo "direnv: using Java 8"
      }

      # Java 17 환경 설정
      use_java_17() {
        export JAVA_HOME="${jdk17}/lib/openjdk"
        PATH_add "${jdk17}/bin"
        echo "direnv: using Java 17"
      }
    '';
  };

  # 셸 별칭 추가
  home.shellAliases = {
    java8 = "java-switch 8";
    java17 = "java-switch 17";
  };
}