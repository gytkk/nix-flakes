let
  content = builtins.readFile ./test-terraform-project/backend.tf;
  
  parseRequiredVersion = content:
    let
      # required_version 매치
      versionMatch = builtins.match ".*required_version[ ]*=[ ]*\"([^\"]+)\".*" content;
    in
      if versionMatch != null then
        let 
          versionSpec = builtins.head versionMatch;
          # 정확한 버전 (= 1.10.2)
          exactMatch = builtins.match "=[ ]*([0-9.]+)" versionSpec;
          # 최소 버전 (>= 1.10.2)
          minMatch = builtins.match ">=[ ]*([0-9.]+).*" versionSpec;
          # 범위 버전 (~> 1.10.0)
          rangeMatch = builtins.match "~>[ ]*([0-9.]+)" versionSpec;
        in
          {
            versionSpec = versionSpec;
            exactMatch = exactMatch;
            minMatch = minMatch;
            rangeMatch = rangeMatch;
            result = if exactMatch != null then builtins.head exactMatch
                     else if minMatch != null then builtins.head minMatch  
                     else if rangeMatch != null then builtins.head rangeMatch
                     else "1.12.2";
          }
      else { error = "no match"; };
          
in {
  content = content;
  parsing = parseRequiredVersion content;
}