if length != 1 or (.[0] | type) != "object" then
  error("Orca data must contain exactly one JSON object")
else .[0] end
| if (.settings | type) != "object" then
    error("Orca data must contain a settings object")
  else . end
| if ($patch | length) != 1 or ($patch[0] | keys) != ["settings"]
     or ($patch[0].settings | type) != "object" then
    error("Orca patch must contain only a settings object")
  else . end
| .settings as $existing
| $patch[0].settings as $incoming
| (if $existing | has("terminalCustomThemes") then
     $existing.terminalCustomThemes
   else [] end) as $themes
| if ($themes | type) != "array" or ($incoming.terminalCustomThemes | type) != "array" then
    error("Orca custom themes must be arrays")
  else . end
| ($incoming.terminalCustomThemes | map(.id)) as $ids
| .settings = ($existing + $incoming)
| .settings.terminalCustomThemes = (
    ($themes | map(select(.id as $id | $ids | index($id) | not)))
    + $incoming.terminalCustomThemes
  )
| if (.settings.terminalCustomThemes | length) > 200 then
    error("Orca supports at most 200 custom themes; remove an unused theme before applying")
  else . end
