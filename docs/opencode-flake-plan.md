# OpenCode 전용 Flake 계획

## 배경

현재 opencode는 `nixpkgs-master` overlay를 통해 lazy-loading으로 설치됩니다.
nixpkgs의 PR 리뷰 프로세스(수일 소요)로 인해 upstream 릴리스와 항상 격차가 발생합니다.

- upstream 최신: **v1.1.60** (2026-02-12 릴리스)
- nixpkgs-master 현재: **v1.1.53** (2026-02-06 머지)
- 대기 중 PR: [#489459](https://github.com/NixOS/nixpkgs/pull/489459) (1.1.53 → 1.1.59)

## 목표

anomalyco/opencode GitHub Releases에서 pre-built 바이너리를 직접 가져오는 별도 flake를
만들어, nixpkgs PR 리뷰 대기 없이 최신 버전을 즉시 사용할 수 있도록 합니다.

## 접근 방식: Pre-built Binary Fetch

### 왜 소스 빌드가 아닌 바이너리인가

| 방식 | 장점 | 단점 |
|------|------|------|
| **소스 빌드** | 순수 nix 빌드, 패치 가능 | bun + node_modules FOD 해시 관리 복잡, 플랫폼별 해시 필요 |
| **Pre-built 바이너리** | 단순, 빠른 설치, 해시 1개/플랫폼 | 공식 빌드에 의존, 패치 불가 |

anomalyco/opencode는 매 릴리스마다 4개 플랫폼 바이너리를 GitHub Releases에 게시합니다:

- `opencode-darwin-arm64.zip` (~33MB) → aarch64-darwin
- `opencode-darwin-x64.zip` (~35MB) → x86_64-darwin
- `opencode-linux-x64.zip` → x86_64-linux
- `opencode-linux-arm64.zip` → aarch64-linux

각 zip에는 단일 `opencode` 바이너리(Bun single-file executable)가 포함됩니다.
claude-code-nix의 native binary 모드와 동일한 접근 방식입니다.

## 구현 계획

### 1단계: 별도 GitHub 레포 생성

`gytkk/opencode-flake` (또는 원하는 이름)으로 새 레포를 만듭니다.

#### 레포 구조

```text
opencode-flake/
├── flake.nix          # Flake 정의 (packages, overlays)
├── flake.lock         # 자동 생성
├── package.nix        # 패키지 빌드 로직
├── scripts/
│   └── update.sh      # 버전 + 해시 업데이트 스크립트
└── .github/
    └── workflows/
        └── update.yml # 자동 업데이트 GitHub Actions
```

#### package.nix 핵심 구조

```nix
{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  autoPatchelfHook,
  makeWrapper,
  ripgrep,
}:

let
  version = "1.1.60";  # 자동 업데이트 대상

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-arm64.zip";
      hash = "sha256-...";  # nix-prefetch-url --unpack으로 계산
    };
    "x86_64-darwin" = {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-darwin-x64.zip";
      hash = "sha256-...";
    };
    "x86_64-linux" = {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-x64.zip";
      hash = "sha256-...";
    };
    "aarch64-linux" = {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-linux-arm64.zip";
      hash = "sha256-...";
    };
  };

  src = fetchurl sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version src;

  nativeBuildInputs = [ unzip makeWrapper ]
    ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];

  # Linux에서 libstdc++ 동적 링크 필요 (Bun 바이너리)
  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    stdenvNoCC.cc.cc.lib
  ];

  unpackPhase = "unzip $src";

  installPhase = ''
    install -Dm755 opencode $out/bin/opencode
    wrapProgram $out/bin/opencode \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}
  '';

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = lib.licenses.mit;
    platforms = builtins.attrNames sources;
    mainProgram = "opencode";
  };
}
```

#### flake.nix 핵심 구조

```nix
{
  description = "OpenCode - pre-built binary from GitHub Releases";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forEachSystem = f: nixpkgs.lib.genAttrs systems (system:
        f { pkgs = nixpkgs.legacyPackages.${system}; inherit system; }
      );
    in {
      packages = forEachSystem ({ pkgs, system }: {
        opencode = pkgs.callPackage ./package.nix {};
        default = self.packages.${system}.opencode;
      });

      overlays.default = final: prev: {
        opencode = final.callPackage ./package.nix {};
      };
    };
}
```

### 2단계: 자동 업데이트 시스템

#### scripts/update.sh

GitHub API로 최신 릴리스를 확인하고, 버전 + 플랫폼별 해시를 자동 업데이트합니다.

```bash
#!/usr/bin/env bash
set -euo pipefail

LATEST=$(curl -s https://api.github.com/repos/anomalyco/opencode/releases/latest \
  | jq -r '.tag_name' | sed 's/^v//')

CURRENT=$(grep 'version = ' package.nix | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ "$LATEST" = "$CURRENT" ]; then
  echo "Already at latest version: $LATEST"
  exit 0
fi

echo "Updating $CURRENT -> $LATEST"

# 플랫폼별 해시 계산
for platform in darwin-arm64 darwin-x64 linux-x64 linux-arm64; do
  url="https://github.com/anomalyco/opencode/releases/download/v${LATEST}/opencode-${platform}.zip"
  hash=$(nix-prefetch-url --unpack "$url" 2>/dev/null)
  sri_hash=$(nix hash to-sri --type sha256 "$hash")
  echo "$platform: $sri_hash"
  # sed로 package.nix의 해당 해시 업데이트
done

# version 업데이트
sed -i "s/version = \"$CURRENT\"/version = \"$LATEST\"/" package.nix
```

#### .github/workflows/update.yml

```yaml
name: Update OpenCode
on:
  schedule:
    - cron: '15 */3 * * *'  # 3시간마다
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v30
      - run: ./scripts/update.sh
      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add package.nix
          git diff --staged --quiet || {
            VERSION=$(grep 'version = ' package.nix | head -1 | sed 's/.*"\(.*\)".*/\1/')
            git commit -m "opencode: update to v${VERSION}"
            git tag "v${VERSION}"
            git push && git push --tags
          }
```

### 3단계: nix-flakes 레포에 통합

#### flake.nix 변경

```nix
inputs = {
  # 기존 inputs...

  # 추가: opencode 전용 flake
  opencode-flake = {
    url = "github:gytkk/opencode-flake";
    inputs.nixpkgs.follows = "nixpkgs";  # nixpkgs 공유로 evaluation 최적화
  };
};
```

#### overlays/default.nix 변경

```nix
# Before: nixpkgs-master에서 opencode + claude-code 가져옴
master = mkLazyPkgs inputs.nixpkgs-master [
  "opencode"
  "claude-code"
];

# After: opencode 제거, claude-code만 남김
master = mkLazyPkgs inputs.nixpkgs-master [
  "claude-code"
];
```

#### modules/opencode/default.nix 변경

```nix
# Before
home.packages = [
  pkgs.master.opencode
];

# After (Option A: overlay 사용)
# lib/builders.nix의 commonOverlays에 inputs.opencode-flake.overlays.default 추가
home.packages = [
  pkgs.opencode
];

# After (Option B: 직접 참조)
home.packages = [
  inputs.opencode-flake.packages.${pkgs.system}.default
];
```

## nixpkgs-master 제거 가능성

현재 `nixpkgs-master`에서 가져오는 패키지는 `opencode`과 `claude-code` 두 개뿐입니다.

| 시나리오 | nixpkgs-master | 효과 |
|----------|---------------|------|
| opencode만 분리 | 유지 (claude-code용) | 버전 최신성 개선만 |
| opencode + claude-code 분리 | **제거 가능** | `nix flake update` 속도 대폭 개선 |

claude-code도 `claude-code-nix` flake로 전환하면 nixpkgs-master input을 완전히 제거할 수 있습니다.
이는 후속 작업으로 검토합니다.

## 예상 효과

| 항목 | Before | After |
|------|--------|-------|
| 버전 지연 | 수일 (nixpkgs PR 리뷰) | 수시간 (GitHub Actions) |
| 업데이트 방법 | `nix flake update` (nixpkgs-master 전체) | `nix flake update opencode-flake` (수 KB) |
| 빌드 시간 | 소스 빌드 (bun + Go) | 바이너리 다운로드 + 패치 (수초) |
| 안정성 | nixpkgs 메인테이너 검증 | 공식 릴리스 바이너리에 의존 |
| 유지보수 | 없음 (nixpkgs에 위임) | GitHub Actions 자동 (수동 개입 거의 불필요) |

## 리스크 및 대응

| 리스크 | 대응 |
|--------|------|
| upstream 릴리스 바이너리 형식 변경 | update.sh에서 감지 → CI 실패 알림 |
| GitHub Releases 다운로드 제한 | Nix substituter가 캐시하므로 1회만 다운로드 |
| 바이너리에 보안 문제 | nixpkgs 소스 빌드와 동일한 upstream 코드 기반 |
| Bun 런타임 호환성 (Linux) | autoPatchelfHook + libstdc++ 래핑으로 해결 |

## 작업 순서

1. GitHub에 `gytkk/opencode-flake` 레포 생성
2. `flake.nix`, `package.nix`, `scripts/update.sh` 작성
3. 로컬에서 `nix build` 테스트 (aarch64-darwin)
4. GitHub Actions workflow 설정
5. nix-flakes 레포에 input 추가 및 overlay/module 수정
6. `home-manager build --flake .#devsisters-macbook`으로 검증
7. (후속) claude-code-nix 전환 검토 → nixpkgs-master 완전 제거
