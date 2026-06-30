def as_object:
  if type == "object" then . else {} end;

def as_array:
  if type == "array" then . else [] end;

def merge_custom_themes($existing; $incoming):
  (($incoming // []) | as_array) as $incomingThemes
  | ($incomingThemes | map(.id? // empty)) as $ids
  | ((($existing // []) | as_array)
      | map(select(.id as $id | ($ids | index($id) | not))))
    + $incomingThemes;

($patch[0] // {}) as $patchData
| if ($patchData.settings? | type) == "object" then
    .settings = (
      ((.settings // {}) | as_object) as $settings
      | ($settings + $patchData.settings)
      | if ($patchData.settings.terminalCustomThemes? | type) == "array" then
          .terminalCustomThemes = merge_custom_themes(
            $settings.terminalCustomThemes;
            $patchData.settings.terminalCustomThemes
          )
        else
          .
        end
    )
  else
    .
  end
| if ($patchData.ui? | type) == "object" then
    .ui = (((.ui // {}) | as_object) + $patchData.ui)
  else
    .
  end
