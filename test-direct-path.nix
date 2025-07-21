let
  # 직접 테스트 디렉토리 경로 사용
  testDir = /home/gytkk/development/nix-flakes/test-terraform-project;
  backendTf = testDir + "/backend.tf";
  
  parseRequiredVersion = content:
    let
      versionMatch = builtins.match ".*required_version[ ]*=[ ]*\"([^\"]+)\".*" content;
    in
      if versionMatch != null then
        let 
          versionSpec = builtins.head versionMatch;
          exactMatch = builtins.match "=[ ]*([0-9.]+)" versionSpec;
          minMatch = builtins.match ">=[ ]*([0-9.]+).*" versionSpec;
          rangeMatch = builtins.match "~>[ ]*([0-9.]+)" versionSpec;
        in
          if exactMatch != null then builtins.head exactMatch
          else if minMatch != null then builtins.head minMatch  
          else if rangeMatch != null then builtins.head rangeMatch
          else "1.12.2"
      else "1.12.2";

in {
  backendExists = builtins.pathExists backendTf;
  version = if builtins.pathExists backendTf 
            then parseRequiredVersion (builtins.readFile backendTf)
            else "no backend.tf";
}