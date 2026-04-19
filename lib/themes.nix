{ flakeDirectory }:

let
  flakeThemeExportsRoot = ../themes/exports;
  checkoutThemeExportsRoot = "${flakeDirectory}/themes/exports";
in
{
  dir = app: flakeThemeExportsRoot + "/${app}";
  file = app: fileName: (flakeThemeExportsRoot + "/${app}") + "/${fileName}";

  mutableDir = app: "${checkoutThemeExportsRoot}/${app}";
  mutableFile = app: fileName: "${checkoutThemeExportsRoot}/${app}/${fileName}";
}
