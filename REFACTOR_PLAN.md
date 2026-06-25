# Nix Flake Structure Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove unused nix-darwin structure, make Home Manager module enable boundaries explicit, split builder responsibilities, and separate reusable OpenClaw module logic from host-specific values.

**Architecture:** Keep `inventory.nix` as the host and environment source of truth. Keep all Home Manager module option definitions importable from `base/default.nix`, but gate every user-facing module behind `modules.<name>.enable` so profile files own activation. Move NixOS plumbing out of `lib/builders.nix` into common NixOS modules and host imports, leaving builders focused on assembling configurations.

**Tech Stack:** Nix flakes, Home Manager modules, NixOS modules, agenix, project-local shell/Python helpers.

---

## Constraints

- Do not use git worktrees in this repository.
- Do not add test automation in this refactor. Verification uses Nix formatting and evaluation commands only.
- Preserve standalone Home Manager support for macOS hosts.
- Remove nix-darwin configuration and inputs because nix-darwin is no longer a supported target.
- Keep commits small and rollbackable.
- Do not push.

## Target File Map

### Remove nix-darwin structure

- Modify: `flake.nix`
  - Remove the `nix-darwin` input.
  - Keep `aarch64-darwin` package and Home Manager evaluation support.
- Delete: `hosts/devsisters-macbook/configuration.nix`
- Delete: `hosts/devsisters-macstudio/configuration.nix`
- Modify: `README.md`
  - Remove nix-darwin from the project description and commands.
  - Clarify that macOS is managed through standalone Home Manager.
- Modify: `AGENTS.md`
  - Remove nix-darwin architecture references.
  - Keep macOS Home Manager environment references.
- Modify: `CLAUDE.md`
  - Mirror the updated architecture wording from `AGENTS.md`.
- Modify: `docs/cleanup-targets.md`
  - Mark the nix-darwin host cleanup as resolved or remove those entries.

### Home Manager module enable boundaries

- Modify: `base/default.nix`
  - Continue importing Home Manager module definitions.
  - Set default enable values for the base profile in one visible block.
- Modify: `base/pylv/sepia.nix`
  - Keep server overrides such as `modules.zed.enable = false`.
- Modify: `modules/aerospace/default.nix`
- Modify: `modules/claude/default.nix`
- Modify: `modules/ghostty/default.nix`
- Modify: `modules/git/default.nix`
- Modify: `modules/k9s/default.nix`
- Modify: `modules/opencode/default.nix`
- Modify: `modules/tmux/default.nix`
- Modify: `modules/vim/default.nix`
- Modify: `modules/wezterm/default.nix`
- Modify: `modules/zellij/default.nix`
- Modify: `modules/zsh/default.nix`
  - Add `options.modules.<name>.enable`.
  - Wrap existing config in `lib.mkIf cfg.enable`.
- Review only: modules that already have enable options:
  - `modules/agent-session-record/default.nix`
  - `modules/cmux/default.nix`
  - `modules/codex/default.nix`
  - `modules/lsp/default.nix`
  - `modules/omnigent/default.nix`
  - `modules/terraform/default.nix`
  - `modules/zed/default.nix`

### Builder responsibility split

- Create: `lib/pkgs.nix`
  - Own `commonOverlays`, pre-evaluated `systemPkgs`, `mkPkgs`, and `mkSystemPkgs`.
- Create: `lib/home-configurations.nix`
  - Own `mkHomeConfig` and Home Manager `extraSpecialArgs`.
- Create: `lib/nixos-configurations.nix`
  - Own `mkNixOSConfig` and only the minimal NixOS assembly.
- Modify: `lib/builders.nix`
  - Become a compatibility aggregation layer that re-exports functions from the new files.
- Modify: `lib/default.nix`
  - Import the new library files and preserve `lib.builders.*` for `flake.nix`.
- Modify: `modules/nixos/default.nix`
  - Import common system modules that are truly common to all NixOS hosts.
- Create: `modules/nixos/secrets.nix`
  - Move common NixOS agenix secret declarations out of `lib/builders.nix`.
- Modify: `hosts/pylv-sepia/configuration.nix`
  - Import host-needed input modules such as Disko and Copyparty directly.
- Modify: `hosts/pylv-onyx/configuration.nix`
  - Import host-needed input modules such as niri and DankMaterialShell directly.

### OpenClaw reusable boundary

- Modify: `modules/openclaw/default.nix`
  - Add `options.modules.openclaw`.
  - Move host-specific constants into options with defaults only where a default is generic.
  - Keep reusable wrapper, bootstrap, state sync, and nginx composition in the module.
- Modify: `modules/openclaw/nginx-proxy.nix`
  - Read ports and interface values from the module `common` record built from `cfg`.
- Modify: `modules/openclaw/state-sync.nix`
  - Read state path and token path from the module `common` record built from `cfg`.
- Modify: `hosts/pylv-onyx/configuration.nix`
  - Set `modules.openclaw.enable = true`.
  - Provide `lanInterface = "wlo1"` and onyx-specific ports, paths, and package choices.
- Modify: `modules/openclaw/README.md`
  - Document which values are reusable module options and which values are set by `pylv-onyx`.

### Documentation refresh

- Modify: `README.md`
  - Update project scope.
  - Update module boundary explanation.
  - Remove stale nix-darwin references.
- Modify: `AGENTS.md`
  - Update architecture table.
  - Update module pattern to mention explicit enable gates.
  - Keep theme pipeline guidance.
- Modify: `CLAUDE.md`
  - Bring architecture and module wording in sync with `AGENTS.md`.
- Modify: `docs/cleanup-targets.md`
  - Remove resolved nix-darwin cleanup findings and keep unresolved cleanup items clearly scoped.

---

## Task 1: Remove nix-darwin Configuration Surface

**Files:**

- Modify: `flake.nix`
- Delete: `hosts/devsisters-macbook/configuration.nix`
- Delete: `hosts/devsisters-macstudio/configuration.nix`
- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `docs/cleanup-targets.md`
- Modify: `flake.lock`

- [ ] **Step 1: Confirm nix-darwin references before editing**

Run:

```bash
rg -n "nix-darwin|darwinConfigurations|hosts/devsisters|devsisters-macbook/configuration|devsisters-macstudio/configuration" flake.nix README.md AGENTS.md CLAUDE.md docs hosts lib base modules
```

Expected:

- `flake.nix` contains the `nix-darwin` input.
- `hosts/devsisters-macbook/configuration.nix` and `hosts/devsisters-macstudio/configuration.nix` exist.
- No live flake output imports those host files.

- [ ] **Step 2: Remove nix-darwin flake input and host files**

Edit `flake.nix` and remove this input block:

```nix
    # nix-darwin - macOS system configuration
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
```

Delete:

```bash
git rm hosts/devsisters-macbook/configuration.nix hosts/devsisters-macstudio/configuration.nix
```

- [ ] **Step 3: Refresh the lock file after removing the input**

Run:

```bash
nix flake lock
```

Expected:

- `flake.lock` no longer contains an active `nix-darwin` root input.
- Existing pinned inputs are otherwise preserved unless Nix removes now-unreachable lock nodes.

- [ ] **Step 4: Update public docs for supported targets**

Update `README.md` first line from:

```markdown
Nix flake configuration for Home Manager, nix-darwin, and NixOS.
```

to:

```markdown
Nix flake configuration for standalone Home Manager and NixOS.
```

Update `AGENTS.md` and `CLAUDE.md` architecture text so the supported layers are:

```text
flake.nix                         # Main flake configuration
inventory.nix                     # All Home Manager environments and NixOS hosts
base/default.nix                  # Common Home Manager configuration
base/<profile>/home.nix           # Profile-specific Home Manager extensions
modules/<name>/default.nix        # Reusable Home Manager or NixOS module
hosts/<name>/configuration.nix    # NixOS host configuration
lib/builders.nix                  # Compatibility exports for configuration builders
overlays/default.nix              # nixpkgs version overlays
secrets/secrets.nix               # Agenix recipient configuration
```

Update `docs/cleanup-targets.md` by removing the `hosts/devsisters-*` dead-code entries from the active findings section and adding a short resolved note:

```markdown
### Resolved

- `hosts/devsisters-macbook/configuration.nix` and
  `hosts/devsisters-macstudio/configuration.nix` were removed with the unused
  nix-darwin input.
```

- [ ] **Step 5: Format and evaluate**

Run:

```bash
nixfmt flake.nix
nix flake check --no-build --all-systems
```

Expected:

- `nixfmt` exits 0.
- `nix flake check --no-build --all-systems` exits 0.
- Existing non-blocking warnings may remain, but no nix-darwin related evaluation errors remain.

- [ ] **Step 6: Commit**

Run:

```bash
git status --short
git add flake.nix flake.lock README.md AGENTS.md CLAUDE.md docs/cleanup-targets.md hosts/devsisters-macbook/configuration.nix hosts/devsisters-macstudio/configuration.nix
git commit -m "refactor: remove unused nix-darwin config"
```

Expected:

- Commit succeeds.
- The commit contains only nix-darwin removal and related documentation updates.

---

## Task 2: Add Explicit Home Manager Enable Boundaries

**Files:**

- Modify: `base/default.nix`
- Modify: `base/pylv/sepia.nix`
- Modify: `modules/aerospace/default.nix`
- Modify: `modules/claude/default.nix`
- Modify: `modules/ghostty/default.nix`
- Modify: `modules/git/default.nix`
- Modify: `modules/k9s/default.nix`
- Modify: `modules/opencode/default.nix`
- Modify: `modules/tmux/default.nix`
- Modify: `modules/vim/default.nix`
- Modify: `modules/wezterm/default.nix`
- Modify: `modules/zellij/default.nix`
- Modify: `modules/zsh/default.nix`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Confirm which Home Manager modules lack enable options**

Run:

```bash
rg --files-without-match "options\\.modules\\." modules/*/default.nix | sort
```

Expected before editing:

```text
modules/aerospace/default.nix
modules/claude/default.nix
modules/ghostty/default.nix
modules/git/default.nix
modules/k9s/default.nix
modules/nixos/default.nix
modules/openclaw/default.nix
modules/opencode/default.nix
modules/tmux/default.nix
modules/vim/default.nix
modules/wezterm/default.nix
modules/zellij/default.nix
modules/zsh/default.nix
```

`modules/nixos/default.nix` and `modules/openclaw/default.nix` are NixOS-side modules and are handled in later tasks.

- [ ] **Step 2: Apply the standard enable-option shape to unguarded Home Manager modules**

Use this shape in each Home Manager module, adapted to the local module name:

```nix
let
  cfg = config.modules.<moduleName>;
in
{
  options.modules.<moduleName>.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable <human readable module name> module";
  };

  config = lib.mkIf cfg.enable {
    # existing module config moves here
  };
}
```

For `modules/aerospace/default.nix`, preserve the Darwin platform guard inside the enable gate:

```nix
config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
  # existing AeroSpace config
};
```

For modules whose file currently lacks `lib`, add it to the function argument list.

- [ ] **Step 3: Set base profile defaults in one block**

In `base/default.nix`, keep the current `imports` list and add a single visible default block under `config = {`:

```nix
    modules = {
      agentSessionRecord.enable = lib.mkDefault true;
      aerospace.enable = lib.mkDefault pkgs.stdenv.isDarwin;
      claude.enable = lib.mkDefault true;
      cmux.enable = lib.mkDefault true;
      codex.enable = lib.mkDefault true;
      ghostty.enable = lib.mkDefault true;
      git.enable = lib.mkDefault true;
      k9s.enable = lib.mkDefault true;
      lsp.enable = lib.mkDefault true;
      omnigent.enable = lib.mkDefault true;
      opencode.enable = lib.mkDefault true;
      tmux.enable = lib.mkDefault true;
      vim.enable = lib.mkDefault true;
      wezterm.enable = lib.mkDefault true;
      zed.enable = lib.mkDefault true;
      zellij.enable = lib.mkDefault true;
      zsh.enable = lib.mkDefault true;
    };
```

Remove the existing standalone line:

```nix
    modules.agentSessionRecord.enable = lib.mkDefault true;
```

Keep `modules.terraform.enable` absent from the base defaults because the Devsisters profile enables it explicitly.

- [ ] **Step 4: Keep server override behavior intact**

Verify `base/pylv/sepia.nix` still disables Zed:

```nix
  modules.zed.enable = false;
```

Add comments only if a module default now makes the override harder to understand.

- [ ] **Step 5: Update agent docs for the new module rule**

In `AGENTS.md` and `CLAUDE.md`, update the module pattern from:

```text
let cfg = config.modules.name; in { options.modules.name = { enable = lib.mkOption { ... }; }; config = lib.mkIf cfg.enable { ... }; }
```

to:

```text
Home Manager modules expose `options.modules.<name>.enable` and gate runtime config with `lib.mkIf cfg.enable`. `base/default.nix` owns common default enable values; profile files override with `lib.mkForce` or plain assignments when needed.
```

- [ ] **Step 6: Format and evaluate targeted Home Manager configs**

Run:

```bash
nixfmt base/default.nix base/pylv/sepia.nix modules/aerospace/default.nix modules/claude/default.nix modules/ghostty/default.nix modules/git/default.nix modules/k9s/default.nix modules/opencode/default.nix modules/tmux/default.nix modules/vim/default.nix modules/wezterm/default.nix modules/zellij/default.nix modules/zsh/default.nix
nix eval .#homeConfigurations.pylv-denim.activationPackage.drvPath
nix eval .#homeConfigurations.devsisters-macbook.activationPackage.drvPath
```

Expected:

- `nixfmt` exits 0.
- Both `nix eval` commands print store derivation paths.
- `pylv-sepia` still evaluates through the full flake check in a later task.

- [ ] **Step 7: Commit**

Run:

```bash
git status --short
git add base/default.nix base/pylv/sepia.nix modules/aerospace/default.nix modules/claude/default.nix modules/ghostty/default.nix modules/git/default.nix modules/k9s/default.nix modules/opencode/default.nix modules/tmux/default.nix modules/vim/default.nix modules/wezterm/default.nix modules/zellij/default.nix modules/zsh/default.nix AGENTS.md CLAUDE.md
git commit -m "refactor: add home module enable boundaries"
```

Expected:

- Commit succeeds.
- No NixOS builder split or OpenClaw behavior changes are mixed into this commit.

---

## Task 3: Split Builder Responsibilities

**Files:**

- Create: `lib/pkgs.nix`
- Create: `lib/home-configurations.nix`
- Create: `lib/nixos-configurations.nix`
- Modify: `lib/builders.nix`
- Modify: `lib/default.nix`
- Modify: `modules/nixos/default.nix`
- Create: `modules/nixos/secrets.nix`
- Modify: `hosts/pylv-sepia/configuration.nix`
- Modify: `hosts/pylv-onyx/configuration.nix`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Move package-set construction into `lib/pkgs.nix`**

Create `lib/pkgs.nix` with the overlay and system package logic currently in `lib/builders.nix`.

The file should expose:

```nix
{
  commonOverlays = commonOverlays;
  mkPkgs = system: systemPkgs.${system};
  mkSystemPkgs =
    systems:
    builtins.listToAttrs (
      map (system: {
        name = system;
        value = systemPkgs.${system};
      }) systems
    );
}
```

Keep the existing systems:

```nix
"x86_64-linux"
"aarch64-darwin"
```

- [ ] **Step 2: Move Home Manager assembly into `lib/home-configurations.nix`**

Create `lib/home-configurations.nix`.

Inputs:

```nix
{
  inputs,
  systemPkgs,
}:
```

Expose:

```nix
{
  mkFlakeDirectory = homeDirectory: "${homeDirectory}/development/nix-flakes";
  mkHomeConfig =
    { baseModules }:
    name: config:
    # existing mkHomeConfig body from lib/builders.nix
}
```

Keep Home Manager responsibilities here:

- required inventory field validation
- `base/<profile>/home.nix` discovery
- `inputs.home-manager.lib.homeManagerConfiguration`
- Home Manager `extraSpecialArgs`
- `inputs.agenix.homeManagerModules.default`

- [ ] **Step 3: Move NixOS assembly into `lib/nixos-configurations.nix`**

Create `lib/nixos-configurations.nix`.

Inputs:

```nix
{
  inputs,
  nixpkgs,
  commonOverlays,
  mkFlakeDirectory,
}:
```

Expose:

```nix
{
  mkNixOSConfig = name: config: # reduced mkNixOSConfig body
}
```

Keep only these builder-level NixOS concerns:

- required inventory field validation
- `specialArgs`
- `nixpkgs.lib.nixosSystem`
- `inputs.home-manager.nixosModules.home-manager`
- host config import
- `home-manager.useGlobalPkgs`
- `home-manager.useUserPackages`
- Home Manager user wiring

Remove these from the builder-level module list:

```nix
../modules/codex/system.nix
inputs.disko.nixosModules.disko
inputs.agenix.nixosModules.default
inputs.copyparty.nixosModules.default
inputs.niri.nixosModules.niri
inputs.dms.nixosModules.dank-material-shell
inputs.dms.nixosModules.greeter
```

- [ ] **Step 4: Move common NixOS secrets into `modules/nixos/secrets.nix`**

Create `modules/nixos/secrets.nix`:

```nix
{ username, ... }:
{
  age.secrets."openai-api-key" = {
    file = ../../secrets/openai-api-key.age;
    owner = username;
    group = "users";
    mode = "0400";
  };
}
```

Modify `modules/nixos/default.nix` so it imports:

```nix
[
  ./baseline.nix
  ./remote-access.nix
  ./secrets.nix
  ./user.nix
  ../codex/system.nix
]
```

Also import `inputs.agenix.nixosModules.default` here if this module receives `inputs` through `specialArgs`. The import entry should be:

```nix
inputs.agenix.nixosModules.default
```

Add `inputs` to the argument list for `modules/nixos/default.nix`.

- [ ] **Step 5: Move host-specific NixOS input modules to host configs**

Modify `hosts/pylv-sepia/configuration.nix` argument list to include `inputs`:

```nix
{
  inputs,
  modulesPath,
  pkgs,
  ...
}:
```

Add these imports:

```nix
inputs.disko.nixosModules.disko
inputs.copyparty.nixosModules.default
```

Modify `hosts/pylv-onyx/configuration.nix` argument list to include `inputs`:

```nix
{
  config,
  inputs,
  pkgs,
  username,
  ...
}:
```

Add these imports:

```nix
inputs.disko.nixosModules.disko
inputs.niri.nixosModules.niri
inputs.dms.nixosModules.dank-material-shell
inputs.dms.nixosModules.greeter
```

- [ ] **Step 6: Keep `lib.builders.*` compatibility**

Rewrite `lib/builders.nix` as an aggregation layer:

```nix
{ inputs, nixpkgs }:
let
  pkgsLib = import ./pkgs.nix { inherit inputs nixpkgs; };
  homeLib = import ./home-configurations.nix {
    inherit inputs;
    systemPkgs = pkgsLib.systemPkgs;
  };
  nixosLib = import ./nixos-configurations.nix {
    inherit inputs nixpkgs;
    inherit (pkgsLib) commonOverlays;
    inherit (homeLib) mkFlakeDirectory;
  };
in
pkgsLib // homeLib // nixosLib
```

Expose `systemPkgs` from `lib/pkgs.nix` if this aggregation needs it.

- [ ] **Step 7: Update docs for builder responsibilities**

Update `AGENTS.md` and `CLAUDE.md` architecture lines:

```text
lib/pkgs.nix                      # Overlay and per-system package-set construction
lib/home-configurations.nix       # Home Manager configuration builder
lib/nixos-configurations.nix      # NixOS configuration builder
lib/builders.nix                  # Backward-compatible builder aggregation
```

- [ ] **Step 8: Format and evaluate all systems**

Run:

```bash
nixfmt lib/pkgs.nix lib/home-configurations.nix lib/nixos-configurations.nix lib/builders.nix lib/default.nix modules/nixos/default.nix modules/nixos/secrets.nix hosts/pylv-sepia/configuration.nix hosts/pylv-onyx/configuration.nix
nix flake check --no-build --all-systems
```

Expected:

- `nixfmt` exits 0.
- `nix flake check --no-build --all-systems` exits 0.
- No missing option errors for `age.secrets`, Disko, Copyparty, niri, or DankMaterialShell.

- [ ] **Step 9: Commit**

Run:

```bash
git status --short
git add lib/pkgs.nix lib/home-configurations.nix lib/nixos-configurations.nix lib/builders.nix lib/default.nix modules/nixos/default.nix modules/nixos/secrets.nix hosts/pylv-sepia/configuration.nix hosts/pylv-onyx/configuration.nix AGENTS.md CLAUDE.md
git commit -m "refactor: split flake builder responsibilities"
```

Expected:

- Commit succeeds.
- The commit contains builder decomposition and directly required host import moves only.

---

## Task 4: Separate OpenClaw Module Options From Onyx Values

**Files:**

- Modify: `modules/openclaw/default.nix`
- Modify: `modules/openclaw/nginx-proxy.nix`
- Modify: `modules/openclaw/state-sync.nix`
- Modify: `hosts/pylv-onyx/configuration.nix`
- Modify: `modules/openclaw/README.md`

- [ ] **Step 1: Add `modules.openclaw` options**

In `modules/openclaw/default.nix`, add:

```nix
  cfg = config.modules.openclaw;
```

Add options:

```nix
  options.modules.openclaw = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the OpenClaw hybrid gateway module";
    };
    gatewayPort = lib.mkOption {
      type = lib.types.port;
      default = 18789;
      description = "Loopback OpenClaw gateway port";
    };
    lanProxyPort = lib.mkOption {
      type = lib.types.port;
      default = 18790;
      description = "LAN nginx proxy port for OpenClaw";
    };
    publicProxyPort = lib.mkOption {
      type = lib.types.port;
      default = 18791;
      description = "Loopback public-origin nginx proxy port for OpenClaw";
    };
    lanInterface = lib.mkOption {
      type = lib.types.str;
      description = "Network interface that receives LAN OpenClaw traffic";
    };
    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "${homeDirectory}/.openclaw";
      description = "OpenClaw state directory";
    };
  };
```

Do not set a generic default for `lanInterface`.

- [ ] **Step 2: Build `common` from `cfg`**

Replace hard-coded local bindings:

```nix
gatewayPort = 18789;
lanProxyPort = 18790;
publicProxyPort = 18791;
lanInterface = "wlo1";
stateDir = "${homeDirectory}/.openclaw";
```

with values from `cfg`:

```nix
gatewayPort = cfg.gatewayPort;
lanProxyPort = cfg.lanProxyPort;
publicProxyPort = cfg.publicProxyPort;
lanInterface = cfg.lanInterface;
stateDir = toString cfg.stateDir;
```

Wrap the module config in:

```nix
config = lib.mkIf cfg.enable (lib.mkMerge [
  # existing config blocks
]);
```

- [ ] **Step 3: Add an assertion for `lanInterface`**

Inside the enabled config, add:

```nix
assertions = [
  {
    assertion = cfg.lanInterface != "";
    message = "modules.openclaw.lanInterface must be set when modules.openclaw.enable is true.";
  }
];
```

- [ ] **Step 4: Set Onyx-specific values in the host**

In `hosts/pylv-onyx/configuration.nix`, keep importing `../../modules/openclaw` and add:

```nix
  modules.openclaw = {
    enable = true;
    gatewayPort = 18789;
    lanProxyPort = 18790;
    publicProxyPort = 18791;
    lanInterface = "wlo1";
    stateDir = "/home/${username}/.openclaw";
  };
```

- [ ] **Step 5: Keep submodules consuming `common` only**

Verify `modules/openclaw/nginx-proxy.nix` still reads:

```nix
networking.firewall.interfaces.${common.lanInterface}.allowedTCPPorts = [ common.lanProxyPort ];
```

Verify `modules/openclaw/state-sync.nix` still reads state paths through `common`.

- [ ] **Step 6: Update OpenClaw docs**

In `modules/openclaw/README.md`, add a short option section:

```markdown
## NixOS Module Boundary

`modules/openclaw` owns reusable OpenClaw gateway wiring: wrapper creation,
seed config rendering, state sync, secret bootstrap, nginx proxy config, and
firewall wiring.

Host-specific values are set by the importing host through `modules.openclaw`:

- `lanInterface`
- `gatewayPort`
- `lanProxyPort`
- `publicProxyPort`
- `stateDir`

`pylv-onyx` is the current consumer.
```

- [ ] **Step 7: Format and evaluate Onyx**

Run:

```bash
nixfmt modules/openclaw/default.nix modules/openclaw/nginx-proxy.nix modules/openclaw/state-sync.nix hosts/pylv-onyx/configuration.nix
nix eval .#nixosConfigurations.pylv-onyx.config.system.build.toplevel.drvPath
```

Expected:

- `nixfmt` exits 0.
- `nix eval` prints a store derivation path.
- The OpenClaw assertion does not fire for `pylv-onyx`.

- [ ] **Step 8: Commit**

Run:

```bash
git status --short
git add modules/openclaw/default.nix modules/openclaw/nginx-proxy.nix modules/openclaw/state-sync.nix hosts/pylv-onyx/configuration.nix modules/openclaw/README.md
git commit -m "refactor: parameterize openclaw host settings"
```

Expected:

- Commit succeeds.
- The commit contains only OpenClaw module boundary changes.

---

## Task 5: Final Documentation Reconciliation

**Files:**

- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`
- Modify: `docs/cleanup-targets.md`

- [ ] **Step 1: Align root README with final architecture**

Update `README.md` so:

- the project description says standalone Home Manager and NixOS
- macOS hosts are described as Home Manager only
- NixOS hosts are described as system plus Home Manager
- builder split files are listed where architecture is described
- OpenClaw is described as a parameterized NixOS module consumed by `pylv-onyx`

- [ ] **Step 2: Align agent instructions**

Update `AGENTS.md` and `CLAUDE.md` so both files agree on:

- no nix-darwin support
- Home Manager modules expose `modules.<name>.enable`
- `base/default.nix` owns common Home Manager defaults
- NixOS common modules live under `modules/nixos`
- host-specific NixOS imports live in `hosts/<name>/configuration.nix`
- OpenClaw host values live in `hosts/pylv-onyx/configuration.nix`

- [ ] **Step 3: Reconcile cleanup document**

Update `docs/cleanup-targets.md` so resolved work is not listed as active cleanup.

Keep unresolved cleanup items that are outside this refactor, including:

- `modules/vscode/`
- `modules/hermes-agent/README.md`
- `docs/superpowers/plans/*.md`
- uninstalled one-shot helper scripts
- stale or unlinked README files

- [ ] **Step 4: Run final reference scan**

Run:

```bash
rg -n "nix-darwin|darwinConfigurations|hosts/devsisters|modules\\.openclaw|modules\\.[A-Za-z0-9]+\\.enable|lib/pkgs\\.nix|lib/home-configurations\\.nix|lib/nixos-configurations\\.nix" README.md AGENTS.md CLAUDE.md docs/cleanup-targets.md flake.nix inventory.nix lib base modules hosts
```

Expected:

- No active docs claim nix-darwin support.
- `modules.openclaw` appears in `hosts/pylv-onyx/configuration.nix`, `modules/openclaw/*`, and docs.
- New library files are mentioned in architecture docs.

- [ ] **Step 5: Run final evaluation**

Run:

```bash
nix flake check --no-build --all-systems
```

Expected:

- Command exits 0.
- Existing upstream warnings may remain.
- No errors from missing modules, missing options, or stale file paths.

- [ ] **Step 6: Commit**

Run:

```bash
git status --short
git add README.md AGENTS.md CLAUDE.md docs/cleanup-targets.md
git commit -m "docs: update architecture after refactor"
```

Expected:

- Commit succeeds.
- The commit contains documentation reconciliation only.

---

## Final Verification

Run after all task commits:

```bash
git status --short
nix flake check --no-build --all-systems
```

Expected:

- `git status --short` prints no tracked changes.
- `nix flake check --no-build --all-systems` exits 0.

Manual switch commands remain user-run:

```bash
home-manager switch --flake .#devsisters-macbook
home-manager switch --flake .#pylv-denim
nixos-rebuild switch --flake .#pylv-onyx
nixos-rebuild switch --flake .#pylv-sepia
```

## Out Of Scope

- Adding flake `checks`.
- Adding new unit tests.
- Removing non-darwin cleanup targets such as `modules/vscode/`.
- Changing generated theme exports.
- Changing package versions.

## Self-Review

- Spec coverage:
  - nix-darwin removal is covered by Task 1.
  - Home Manager enable boundaries are covered by Task 2.
  - `lib/builders.nix` responsibility split is covered by Task 3.
  - OpenClaw reusable versus host-specific separation is covered by Task 4.
  - Documentation updates are covered by Task 5.
  - Test automation is explicitly out of scope.
- Placeholder scan:
  - No placeholder sections are intentionally left for the implementer.
  - Every task lists exact files and verification commands.
- Type and option consistency:
  - Home Manager module options use `modules.<name>.enable`.
  - NixOS OpenClaw options use `modules.openclaw`.
  - Builder compatibility preserves `lib.builders.*` for the existing `flake.nix`.
