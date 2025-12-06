{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    code-server

    nginx
  ];
}
