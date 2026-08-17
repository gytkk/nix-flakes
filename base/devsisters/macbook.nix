{ pkgs, ... }:

let
  applyKeyboardMapping = pkgs.writeShellScript "apply-keyboard-mapping" ''
    exec /usr/bin/hidutil property --set '{
      "UserKeyMapping": [
        {
          "HIDKeyboardModifierMappingSrc": 0x700000039,
          "HIDKeyboardModifierMappingDst": 0x7000000E0
        },
        {
          "HIDKeyboardModifierMappingSrc": 0x7000000E7,
          "HIDKeyboardModifierMappingDst": 0x700000068
        }
      ]
    }'
  '';
in
{
  launchd.agents.hidutil-keyboard-mapping = {
    enable = true;
    config = {
      ProgramArguments = [ "${applyKeyboardMapping}" ];
      RunAtLoad = true;
      ProcessType = "Interactive";
    };
  };
}
