{
  lib,
  stdenvNoCC,
  callPackage,
  fetchFromGitHub,
  makeWrapper,
  python312,
  # Runtime tools omnigent shells out to (harness install, git ops, terminals).
  # Added with --suffix so the user's own claude/codex/etc. still take priority.
  nodejs,
  git,
  tmux,
  uv,
  ripgrep,
  # uv2nix build infrastructure, threaded in from flake inputs by the overlay.
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}:

let
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "omnigent-ai";
    repo = "omnigent";
    rev = "v${version}";
    hash = "sha256-Caypds51+SbeaQYLnbWtfNXbG12eL1KpZQEL/Vdw+l8=";
  };

  # Load the uv workspace (pyproject.toml + uv.lock, including the sibling
  # sdks/* path members) and turn the lockfile into a nixpkgs python overlay.
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src; };
  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  # Per-package build fixups.
  pyprojectOverrides = _final: prev: {
    # omnigent's setuptools build shells out to `npm` to bundle the browser web
    # UI, which needs network access unavailable in the nix sandbox. Build the
    # API-only server (CLI + terminal sessions work; no localhost:6767 web UI).
    omnigent = prev.omnigent.overrideAttrs (old: {
      env = (old.env or { }) // {
        OMNIGENT_SKIP_WEB_UI = "true";
      };
    });
  };

  python = python312;

  pythonSet = (callPackage pyproject-nix.build.packages { inherit python; }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.default
      overlay
      pyprojectOverrides
    ]
  );

  venv = pythonSet.mkVirtualEnv "omnigent-${version}-env" workspace.deps.default;

  runtimePath = lib.makeBinPath [
    nodejs
    git
    tmux
    uv
    ripgrep
  ];
in
stdenvNoCC.mkDerivation {
  pname = "omnigent";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    for bin in omnigent omni; do
      makeWrapper ${venv}/bin/$bin $out/bin/$bin \
        --suffix PATH : "${runtimePath}"
    done
    runHook postInstall
  '';

  passthru = {
    inherit venv pythonSet workspace;
  };

  meta = {
    description = "Open-source AI agent framework and meta-harness over Claude Code, Codex, and more";
    homepage = "https://omnigent.ai";
    license = lib.licenses.asl20;
    mainProgram = "omnigent";
    platforms = lib.platforms.unix;
  };
}
