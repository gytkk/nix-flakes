{
  lib,
  python3Packages,
}:

python3Packages.buildPythonApplication {
  pname = "agent-core";
  version = "1.0.0";
  pyproject = true;

  src = lib.cleanSource ../.;

  build-system = [ python3Packages.hatchling ];
  nativeCheckInputs = [ python3Packages.pytestCheckHook ];

  pythonImportsCheck = [ "agent_core" ];
  postCheck = ''
    "$out/bin/agent-core" check
  '';

  meta = {
    description = "Portable instructions, skills, and renderers for coding-agent runtimes";
    mainProgram = "agent-core";
    platforms = lib.platforms.unix;
  };
}
