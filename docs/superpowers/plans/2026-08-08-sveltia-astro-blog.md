# Sveltia CMS + Astro 블로그 구현 계획

**목표:** Astro와 Sveltia CMS로 Git 기반 정적 블로그를 구축하고, 기존 nginx 및 Cloudflare Tunnel 경로를 통해 `pylv-sepia`에서 운영한다.

**권장 아키텍처:** 블로그 소스와 Markdown 콘텐츠는 별도 GitHub 저장소에서 관리하고 미디어는 Cloudflare R2에 저장한다. Astro는 불변 `dist/` 아티팩트를 빌드하고, Sveltia CMS는 GitHub 콘텐츠와 R2 미디어를 편집한다. `pylv-sepia`는 원자적으로 배포된 릴리스를 루프백 전용 nginx 오리진에서 제공한다. 이 Nix flake는 호스트 계정, 디렉터리, 배포 명령, nginx 설정, 운영 문서를 관리하며 편집 콘텐츠는 관리하지 않는다.

**초기 운영 방식:** 먼저 수동 배포를 검증한 다음 Tailscale 네트워크를 통한 GitHub Actions 배포를 활성화한다.

---

## 구현 상태 (2026-08-08)

### 확정된 경계

| 항목 | 확정 값 |
| --- | --- |
| 블로그 저장소 | 비공개 `gytkk/blog`; GitHub 저장소 생성 완료 |
| 공개 호스트명 | 스테이징 검증과 최종 공개 모두 `blog.pylv.dev` 사용 |
| CMS 인증 | 단독 기술 사용자가 GitHub PAT로 로그인 |
| 미디어 | Cloudflare R2의 `pylv-blog-media`, 공개 도메인 `media.pylv.dev`, prefix `blog/` |
| 발행 경로 | 수동 배포와 롤백을 먼저 검증한 뒤 GitHub Actions 자동화 |
| 오리진 | `127.0.0.1:12369`; NixOS 방화벽에는 추가하지 않음 |
| 배포 키 | 전용 Ed25519 키 사용; 공개키는 Nix에 포함하고 개인키는 로컬 `0600` 파일과 관리자·배포 Mac 전용 agenix 백업에 보관하며 서버는 복호화 대상에서 제외 |
| Cloudflare Access | 공개 블로그와 `media.pylv.dev`는 인증 없이 제공하고 `/admin/*`만 Access로 보호 |

### 완료된 구현과 검증

- 유실된 블로그 작업을 `~/development/blog`에서 재구성해 단계 1~2를 커밋 `82c75aa`로 구현하고 `gytkk/blog`의 `main`에 push했다. 정적 Astro, Markdown/MDX 컬렉션, frontmatter 검증, 초안 제외, 홈/게시물/태그/RSS/사이트맵/robots/404, 반응형 접근성 스타일과 전체 `dist/` smoke 검사를 포함한다.
- 단계 3의 자동화 가능한 부분을 커밋 `9d78429`로 구현하고 push했다. Sveltia CMS `0.181.1` 자체 호스팅, GitHub `main` 백엔드, Astro와 일치하는 필드, 안전한 초안 기본값, R2 공개 설정, 공식 JSON Schema 검증과 credential-shaped 값 검사를 포함한다. R2 Secret Access Key와 GitHub PAT는 저장하거나 출력하지 않았다.
- 블로그 저장소에서 Bun 1.3.13 기반 `bun ci`, 포맷 검사, CMS schema 검사, `astro check`, Bun 테스트 8개, 프로덕션 빌드, 산출물 smoke test, 로컬 `/admin/index.html` 및 자체 호스팅 CMS script 응답 검사와 `bun audit`를 통과했다.
- `pylv-sepia` 단계 4의 NixOS 코드와 운영 문서를 커밋 `180d680`으로 구현했다. 전용 강제 명령 계정, 제한된 아카이브 검증, 원자적 릴리스 전환/롤백, 보존 정책과 루프백 nginx 오리진을 포함한다.
- 새 배포 키를 생성하고 공개키 교체와 관리자·배포 Mac 전용 agenix 백업을 커밋 `3369718`로 push했다. 로컬 개인키 모드 `0600`, agenix 암복호화 round-trip, 서버 recipient 제외와 렌더된 강제 명령 공개키를 검증했다.
- 배포 명령 테스트 8개, `ruff`, `nix flake check --no-build`, 전체 `nix flake check`, `pylv-sepia` NixOS toplevel 빌드와 렌더된 계정/공개키/리스너/방화벽 값을 검증했다.
- Cloudflare R2 버킷 `pylv-blog-media`, `media.pylv.dev` 커스텀 도메인과 `https://blog.pylv.dev` 전용 `GET`/`PUT`/`HEAD` CORS 정책을 생성했다. 버킷 한정 Object Read & Write Access Key ID를 CMS 공개 설정에 반영했고, 커스텀 도메인의 소유권과 TLS 인증서 상태도 `active`로 확인했다.

### 진행 중 또는 차단된 항목

- 로컬 Tailscale은 시작했지만 `pylv-sepia` peer의 node key가 만료되어 offline 상태다. 서버 콘솔이나 LAN 경로에서 `sudo tailscale up`으로 인증을 갱신하기 전에는 SSH preflight와 실제 포트 `12369` 충돌 검사를 진행할 수 없다.
- `pylv-sepia`에 커밋 `3369718`의 NixOS 설정을 아직 적용하지 않았다. 따라서 nginx 응답, 계정·권한 경계, 수동 배포와 롤백은 런타임 검증 전이다.
- Sveltia의 GitHub PAT 로그인과 게시물 생성·편집·게시·삭제, 브라우저에만 입력하는 R2 Secret Access Key 기반 이미지 업로드는 배포 후 수동 검증이 필요하다.
- `blog.pylv.dev`와 `media.pylv.dev`는 현재 동일한 Cloudflare Access 로그인으로 HTTP 302 응답을 반환한다. 최종 정책은 공개 블로그·미디어와 `/admin/*` 전용 Access로 확정했지만 아직 대시보드에 반영하지 않았다.
- Wrangler 4.90.0으로 R2와 Tunnel 목록·상태는 관리할 수 있지만 기존 Tunnel public hostname/ingress와 Zero Trust Access 앱·정책은 변경할 수 없다. 이 변경은 Cloudflare Zero Trust 대시보드에서 수동으로 수행한다.
- GitHub Actions/Tailscale 자동 배포와 Ghost 제거는 수동 2회 배포·롤백 및 공개 경로 검증 뒤에만 시작한다.
- 프로비저닝에 사용한 Wrangler OAuth 세션은 남은 Cloudflare 설정과 최종 검증이 끝난 뒤 로그아웃한다.

### 다음 재개 순서

1. `pylv-sepia`에서 `sudo tailscale up`을 실행해 만료된 node key를 갱신하고 peer online 상태를 확인한다.
2. 배포 전에 SSH로 `127.0.0.1:12369` 리스너 충돌, nginx/cloudflared 상태와 `/srv/astro-blog` 미적용 상태를 읽기 전용으로 확인한다.
3. 사용자가 커밋 `3369718`의 `pylv-sepia` NixOS 구성을 switch하고 nginx, 배포 계정, 공개키와 루프백 listener를 확인한다.
4. 블로그 커밋 `9d78429`를 고정된 Bun 도구 체인으로 다시 빌드하고 `~/.ssh/astro-blog-deploy` 키로 첫 번째 수동 릴리스를 배포한다.
5. 루프백에서 홈, 게시물, 태그, RSS, sitemap, 404, asset, `/admin/`과 캐시 헤더를 검증한다.
6. Cloudflare Zero Trust 대시보드에서 `blog.pylv.dev`를 `http://127.0.0.1:12369`에 연결하고 공개 블로그·미디어 및 `/admin/*` 전용 Access 정책을 적용한다.
7. 공개 경로에서 Sveltia GitHub PAT CRUD와 R2 이미지 업로드를 시험하고 생성된 Git diff와 Astro 빌드를 확인한다.
8. 두 번째 검증된 릴리스를 배포한 뒤 첫 번째 릴리스로 롤백한다. 모두 통과한 후에만 단계 7 자동화와 단계 8 Ghost 제거를 시작한다.

## 1. 현재 상태와 제약 사항

- `pylv-sepia`는 이 flake에 정의된 x86_64 NixOS 호스트다.
- 호스트에서 이미 nginx와 토큰 기반 Cloudflare Tunnel을 실행하고 있다.
- 테스트용 Ghost 서비스가 남아 있으며 Astro 공개 경로 검증 후 제거할 대상이다.
- Cloudflare Tunnel 호스트명 매핑은 이 저장소가 아니라 Cloudflare Zero Trust 대시보드에서 관리한다.
- 정상 상태에서는 Tailscale 인터페이스와 LAN을 통해 SSH로 접근하고 비밀번호 로그인은 비활성화되어 있다. 현재는 `pylv-sepia`의 Tailscale node key 만료로 원격 접근이 차단되어 있다.
- 루프백 전용 nginx 오리진을 추가하기 위해 인바운드 방화벽 포트를 열 필요가 없다.

## 2. 구현 전에 결정할 사항

다음 제품 및 보안 결정을 확정하기 전에는 구현을 시작하지 않는다.

| 결정 사항 | 권장 기본값 | 대안 및 영향 |
| --- | --- | --- |
| 블로그 소스 위치 | `gytkk/blog`와 같은 별도 GitHub 저장소 | 게시물을 `nix-flakes`에 두면 일반 콘텐츠 발행이 인프라 이력 및 배포와 결합된다. |
| 초기 호스트명 | `blog.pylv.dev`와 같은 스테이징 호스트명 | 먼저 스테이징에서 검증하면 최종 도메인 연결 전 문제를 발견하기 쉽다. |
| CMS 사용자 | MVP에서는 기술 사용자 한 명이 GitHub 토큰으로 로그인 | 여러 사용자 또는 비기술 사용자가 있다면 Sveltia CMS Authenticator를 통한 GitHub OAuth를 사용한다. |
| 발행 경로 | 수동 원자적 배포 검증 후 Tailscale 네트워크를 통한 GitHub Actions 자동화 | 수동 전용 워크플로는 단순하지만 Sveltia에서 저장한 변경이 자동으로 공개되지 않는다. |
| 미디어 저장소 | Cloudflare R2의 `pylv-blog-media`와 `media.pylv.dev` | 저장소 미디어는 단순하지만 저장소 크기와 콘텐츠 이력을 결합한다. |
| 검토 워크플로 | 단독 편집자는 `main`에 직접 커밋 | Sveltia의 editorial workflow는 현재 구현되지 않았으므로 팀 검토는 별도 Git/PR 절차를 사용해야 한다. |
| 댓글/뉴스레터/검색 | 첫 릴리스에서 제외 | 각 기능은 서비스, 개인정보 보호, 운영 검토 또는 런타임 의존성을 추가한다. |

GitHub 저장소, OAuth 애플리케이션, Cloudflare Worker, Tailscale ID, 배포 키, 공개 호스트명 또는 DNS 경로 생성은 외부 및 보안 영향을 동반하므로 구현 시 명시적인 승인을 받아야 한다.

## 3. 범위

### 첫 릴리스에 포함

- 홈, 게시물, 태그, RSS, 사이트맵, robots, 404 페이지를 포함한 정적 Astro 사이트
- Astro 빌드 타임 콘텐츠 컬렉션에 저장하는 Markdown 또는 MDX 게시물
- 타입 및 유효성이 검증되는 frontmatter
- 프로덕션 빌드의 초안 필터링
- 비밀정보가 없는 `/admin/`의 Sveltia CMS
- 버킷 범위 자격 증명과 제한된 CORS를 사용하는 Cloudflare R2 기반 이미지
- 다크/라이트 색상을 지원하는 반응형·접근성 기본 레이아웃
- NixOS가 관리하는 배포 계정, 릴리스 디렉터리, 배포 명령, nginx 오리진
- 수동 배포, 런타임 점검, 롤백, 운영 문서
- 수동 경로 검증 후 선택적으로 활성화하는 GitHub Actions 자동 배포

### 첫 릴리스에서 명시적으로 제외

- Astro SSR, Node 프로덕션 서버 또는 데이터베이스
- 댓글, 멤버십, 뉴스레터, 전문 검색, 분석 또는 문의 양식
- 사용자 정의 CMS 백엔드
- `pylv-sepia`의 self-hosted GitHub Actions runner

## 4. 목표 아키텍처

```text
편집자 브라우저
    |
    | /admin/을 열고 GitHub로 인증
    v
Sveltia CMS(블로그가 제공하는 정적 파일)
    |
    +-- 미디어 업로드 ----------------> Cloudflare R2
    |
    +-- Markdown/frontmatter --> 별도 GitHub 블로그 저장소
                                   |
                                   | CI: 설치 -> 검사 -> 테스트 -> 빌드
                                   | Tailscale OpenSSH로 검증된 dist 배포
                                   v
                               pylv-sepia
                                   /srv/astro-blog/releases/<git-sha>/
                                   /srv/astro-blog/current -> releases/<git-sha>/
                                   |
                                   v
                               nginx 루프백 오리진 127.0.0.1:12369
                                   |
                                   v
                               기존 Cloudflare Tunnel -> blog.pylv.dev
```

### 관리 경계

| 항목 | 원본 데이터 |
| --- | --- |
| 페이지, 컴포넌트, 스타일, Astro 설정 | 별도 블로그 저장소 |
| 게시물 | 별도 블로그 저장소 |
| 미디어 | Cloudflare R2의 `pylv-blog-media` 버킷과 `media.pylv.dev` 공개 도메인 |
| CMS 컬렉션/필드 정의 | 블로그 저장소의 `public/admin/config.yml` |
| Bun 및 의존성 버전, 빌드 명령 | 블로그 저장소의 CI 설정, `bun.lock`, 패키지 스크립트 |
| 배포 계정, 디렉터리, nginx, 로컬 배포 명령 | 이 flake의 `hosts/pylv-sepia/` |
| 공개 호스트명과 선택적 `/admin/*` Access 정책 | Cloudflare 대시보드 |
| GitHub 토큰/OAuth 인가 | GitHub와 편집자 브라우저 |
| OAuth 클라이언트 비밀정보(OAuth 선택 시) | 암호화된 Cloudflare Worker secret |
| CI 배포 자격 증명 | GitHub Environment secret 또는 승인된 workload identity |
| 생성된 릴리스 | `pylv-sepia`의 `/srv/astro-blog/releases/` |

## 5. 제안 파일 구조

### 별도 블로그 저장소

```text
blog/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── deploy.yml
├── public/
│   ├── admin/
│   │   ├── index.html
│   │   └── config.yml
│   └── robots.txt
├── scripts/
│   └── smoke-built-site.mjs
├── src/
│   ├── assets/
│   ├── components/
│   ├── content/
│   │   └── blog/
│   │       └── welcome.md
│   ├── layouts/
│   │   ├── BaseLayout.astro
│   │   └── PostLayout.astro
│   ├── pages/
│   │   ├── 404.astro
│   │   ├── index.astro
│   │   ├── rss.xml.js
│   │   ├── posts/
│   │   │   └── [...id].astro
│   │   └── tags/
│   │       ├── index.astro
│   │       └── [tag].astro
│   ├── styles/
│   │   └── global.css
│   └── content.config.ts
├── astro.config.mjs
├── package.json
├── bun.lock
├── tsconfig.json
└── README.md
```

### 이 Nix flake

```text
hosts/pylv-sepia/
├── astro-blog.nix                 # 새 호스트 모듈
├── configuration.nix              # astro-blog.nix import
└── README.md                      # 배포, 롤백, 운영 안내
```

승인된 아키텍처에서 블로그를 이 저장소에 두기로 한다면 `sites/blog/` 아래에 배치한다. `hosts/pylv-sepia/` 내부에 혼합하지 않는다.

## 6. 콘텐츠 및 CMS 계약

`src/content/blog/**/*.{md,mdx}`를 기반으로 하는 Astro 빌드 타임 컬렉션 하나를 사용하고 Zod로 유효성을 검증한다. 첫 스키마는 다음과 같이 작게 유지한다.

| 필드 | 타입 | 필수 여부 | 설명 |
| --- | --- | --- | --- |
| `title` | string | 필수 | 사람이 읽는 제목 |
| `description` | string | 필수 | SEO 및 목록용 요약 |
| `publishedAt` | date | 필수 | 게시물 정렬 기준 |
| `updatedAt` | date | 선택 | 값이 있을 때만 표시 |
| `draft` | boolean | 필수 | 안전한 작성을 위해 Sveltia 기본값은 `true` |
| `tags` | string array | 필수 | 빈 배열 허용. 태그 경로 생성 시 정규화 |
| `cover` | string | 선택 | MVP에서는 공개 미디어 URL |
| `coverAlt` | string | 조건부 필수 | `cover`가 있으면 프로젝트 검증에서 필수 |

구현 규칙:

- 정적 게시물 경로에는 Astro의 `glob()` loader와 `getStaticPaths()`를 사용한다.
- 구체적인 사용자 정의 slug 요구사항이 없다면 콘텐츠 엔트리 ID/파일명에서 URL 식별자를 생성한다.
- 프로덕션 경로, 목록, 태그, RSS, 사이트맵에서 초안을 제외한다.
- 게시물은 `publishedAt`으로 명시적으로 정렬하며 파일시스템 또는 API 순서에 의존하지 않는다.
- Sveltia의 필드 이름, 날짜 형식, 기본값, 미디어 경로를 Astro 스키마와 정확히 일치시킨다.
- Sveltia 게시물 컬렉션에 `folder: src/content/blog`를 지정해 엔트리가 Astro의 `glob()` 컬렉션 안에 저장되게 한다.
- `media_libraries.cloudflare_r2`에 버킷 `pylv-blog-media`, 공개 URL `https://media.pylv.dev`, prefix `blog/`, 기본 jurisdiction과 공개 가능한 Account ID/Access Key ID를 지정한다.
- R2 Secret Access Key는 `public/admin/config.yml`에 넣지 않는다. Sveltia가 최초 사용 시 입력받아 편집자 브라우저 로컬 저장소에만 보관하게 한다.
- R2 업로드에는 브라우저 기반 파일명 slug 변환과 제한된 이미지 크기/형식 변환을 활성화한다.
- R2 CORS는 `https://blog.pylv.dev`에서 오는 `GET`, `PUT`, `HEAD`를 허용한다. SigV4 업로드를 위해 요청 헤더는 `*`로 허용하고 `ETag`를 노출한다.
- `public/admin/config.yml`은 공개적으로 읽을 수 있으므로 비밀번호, Secret Access Key, OAuth 클라이언트 secret, 배포 키 등 비밀정보를 넣지 않는다.
- Sveltia CMS 패키지/버전과 lockfile을 고정한다. 버전이 지정되지 않은 런타임 CDN URL보다 자체 호스팅하는 빌드 아티팩트를 우선한다.
- CMS 페이지에 `noindex`를 추가한다. `/admin/*`용 Cloudflare Access는 선택적인 방어 계층이며 GitHub 인가를 대체하지 않는다.

## 7. 구현 단계

### 단계 0: 경계 확정 및 이름 예약

- [x] 별도 블로그 저장소의 소유자, 이름, 공개 범위를 확정한다: 비공개 `gytkk/blog`.
- [x] 스테이징 및 최종 공개 호스트명을 확정한다: `blog.pylv.dev`.
- [x] 단독 사용자 토큰 로그인 또는 다중 사용자 OAuth를 선택한다: 단독 사용자 GitHub PAT.
- [x] Git 기반 미디어 또는 R2를 선택한다: Cloudflare R2.
- [x] 수동 전용 또는 자동 배포 목표를 선택한다: 수동 검증 후 GitHub Actions 자동화.
- [ ] 선택한 루프백 오리진 포트 `12369`가 실제 `pylv-sepia`에서 사용 중이지 않은지 확인한다. 선언상 충돌과 방화벽 미노출은 검증했다.

**완료 조건:** 보안, 공개 URL, 저장소 소유권 또는 배포 접근에 영향을 주는 placeholder가 남아 있지 않다.

### 단계 1: Astro 프로젝트 기본 구조 생성

- [ ] Bun 1.3.13과 `bun.lock`을 로컬에 고정했다. 단계 7에서 CI도 같은 버전으로 고정하면 완료한다.
- [x] 포맷, 타입/콘텐츠 검사, 테스트, 빌드, 빌드 결과 smoke test용 최소 스크립트를 추가한다.
- [x] Astro를 정적 출력으로 설정하고 승인된 canonical `site` URL을 지정한다.
- [x] 빌드 타임 콘텐츠 컬렉션과 대표 초안 및 게시 fixture를 각각 하나씩 추가한다.
- [x] 잘못된 frontmatter, 초안 노출, 누락된 생성 경로, 필수 메타데이터 누락에 대한 실패 검사를 추가한다.

**검증:** 깨끗한 환경에서 lockfile 기반 설치 후 의존성 설치 외 네트워크 접근 없이 검사와 `dist/` 생성을 완료할 수 있다.

### 단계 2: 최소 블로그 경험 구현

- [x] 시맨틱 기본 및 게시물 레이아웃을 구현한다.
- [x] 홈, 게시물, 태그 목록, 태그 상세, RSS, 사이트맵, robots, 404 동작을 구현한다.
- [x] canonical URL, Open Graph, 제목, 설명, 피드 메타데이터를 추가한다.
- [x] 반응형 타이포그래피와 키보드 포커스 표시 스타일을 추가한다.
- [x] 게시물 열람에 JavaScript가 필수가 되지 않게 하고 클라이언트 프레임워크를 추가하지 않는다.
- [x] 모든 프로덕션 출력에서 초안이 제외되는지 자동 검사한다.

**검증:** 빌드 아티팩트가 자동 링크/경로 smoke test와 수동 키보드·모바일 검토를 통과한다.

### 단계 3: Sveltia CMS 추가

**상태:** 코드, R2 공개 설정과 자동 검증은 커밋 `9d78429`로 완료했다. 실제 GitHub PAT CRUD와 R2 브라우저 업로드는 공개 배포 및 Access 정책 수정 후 수동 검증한다.

- [x] 고정된 버전의 자체 호스팅 Sveltia CMS를 `/admin/`에 추가한다.
- [x] GitHub 백엔드, 승인된 브랜치, 게시물 컬렉션, 필드, slug 동작, 미디어 경로를 설정한다.
- [x] 새 게시물의 기본 상태를 초안으로 지정하는 등 안전한 기본값을 설정한다.
- [x] Sveltia가 제공하는 JSON Schema로 `config.yml`을 검증한다.
- [ ] 프로덕션 자격 증명을 노출하지 않고 Sveltia가 지원하는 로컬/테스트 경로에서 콘텐츠 편집을 시험한다. 로컬 admin page와 CMS artifact 응답까지만 검증했다.
- [ ] 스테이징에서 승인된 GitHub 인증 경로를 시험한다.
- [ ] 테스트 게시물을 생성, 편집, 게시, 삭제한 다음 생성된 Git diff와 Astro 빌드를 검증한다.

**검증:** Sveltia가 생성한 파일을 수동 frontmatter 수정 없이 Astro가 수용하며 저장소나 빌드 사이트에 비밀정보가 없다.

### 단계 4: `pylv-sepia` 정적 오리진 추가

**상태:** NixOS 코드와 빌드 검증은 완료했다. 커밋 `3369718`에서 실제 보관 중인 배포 키로 공개키를 교체하고 개인키의 agenix 복구 경로도 검증했다. 호스트 활성화와 런타임 검증은 Tailscale node key 갱신 후 단계 5에서 수행한다.

- [x] `hosts/pylv-sepia/astro-blog.nix`를 추가하고 `configuration.nix`에서 import한다.
- [x] `wheel`에 속하지 않고 공유 관리자 키가 없으며 제한 없는 대화형 세션을 열 수 없는 전용 비특권 배포 사용자/그룹을 생성한다.
- [x] 명시적인 소유권과 모드로 `/srv/astro-blog/releases` 및 초기 `current` 대상을 생성한다. nginx는 릴리스를 읽을 수 있지만 수정할 수 없어야 한다.
- [x] 표준 입력에서 아티팩트를 읽고 검증한 뒤 커밋별 디렉터리에 staging하고, 필수 파일을 확인하고, `current`를 원자적으로 전환하며, 소수의 이전 릴리스를 보존하는 제한된 배포 명령을 추가한다.
- [x] CI SSH 공개 키를 OpenSSH 강제 명령에 연결하고 해당 키의 PTY, agent, port, X11 forwarding을 비활성화한다.
- [x] 요청한 커밋 식별자를 `SSH_ORIGINAL_COMMAND`로 검증한다. 키가 임의 실행 파일이나 경로를 선택하게 해서는 안 된다.
- [x] 압축 해제 전에 안전하지 않은 아카이브 경로와 예상하지 않은 심볼릭 링크를 거부한다.
- [x] `127.0.0.1:12369`에만 바인딩하는 별도 nginx virtual host를 추가한다.
- [x] 정적 파일 fallback, 실제 404 응답, MIME 타입, 압축, 보안 헤더를 설정한다.
- [x] fingerprint가 포함된 Astro asset은 장기간 캐시하고 HTML, `/admin/`, `/admin/config.yml`은 장기 캐시하지 않는다.
- [x] NixOS 방화벽에서 오리진 포트를 열지 않는다.

**검증:** 로컬 `Host` 헤더 curl로 nginx를 통해 스테이징 블로그에 접근할 수 있고 오리진 포트는 외부에서 접근할 수 없다.

### 단계 5: 수동 배포와 롤백 검증

- [ ] 고정된 도구 체인으로 정확한 커밋을 빌드한다.
- [ ] 검증한 `dist/` 출력과 Git 커밋 메타데이터만 패키징한다.
- [ ] Tailscale 인터페이스에서 일반 OpenSSH로 아티팩트를 강제 배포 명령에 스트리밍한다. 이 호스트에서 Tailscale SSH 자체는 계속 비활성화한다.
- [ ] Nix가 관리하는 배포 명령으로 릴리스를 활성화한다.
- [ ] 루프백 오리진에서 홈, 게시물 하나, 태그 하나, RSS, 사이트맵, 404, 정적 asset, `/admin/`을 확인한다.
- [ ] 두 번째 릴리스를 배포하고 NixOS를 다시 빌드하지 않은 상태에서 첫 번째 릴리스로 롤백한다.

**완료 조건:** root shell 접근이나 nginx 재시작 없이 배포와 롤백을 반복할 수 있다.

### 단계 6: Cloudflare Tunnel 연결

**상태:** `pylv-sepia` Tunnel과 R2 custom domain은 존재하지만 현재 `blog.pylv.dev`와 `media.pylv.dev` 모두 광범위한 Access 앱에 의해 보호된다. Wrangler는 필요한 ingress/Access 수정을 지원하지 않으므로 배포 후 Zero Trust 대시보드에서 공개 경로와 `/admin/*` 전용 정책을 수동 적용한다.

- [ ] 승인된 스테이징 공개 호스트명을 기존 sepia tunnel에 추가한다.
- [ ] `http://127.0.0.1:12369`로 라우팅한다.
- [ ] 공개 사이트에 인증 없이 접근할 수 있고 캐시 동작이 올바른지 확인한다.
- [ ] 선택했다면 `/admin/*`에만 적용되는 좁은 범위의 Cloudflare Access 정책을 추가한다.
- [ ] Access가 게시물, asset, RSS, 사이트맵, robots, 404 페이지를 보호하지 않는지 확인한다.
- [ ] TLS/공개 오리진 검사를 rollout 체크리스트에 추가한다.

**검증:** 공개 요청이 Cloudflare를 통해 정상적으로 전달되고 직접 접근 가능한 인바운드 오리진 포트가 없다.

### 단계 7: 배포 자동화

수동 배포와 롤백 경로를 통과한 후에만 시작한다.

- [ ] `bun ci` 기반 설치, 포맷, Astro/콘텐츠 검사, 테스트, 빌드, 아티팩트 smoke test를 수행하는 CI를 추가한다.
- [ ] 빌드와 배포 job을 분리하여 서버에서 다시 빌드하지 않고 프로덕션에 검증된 동일 아티팩트를 배포한다.
- [ ] GitHub Environment로 프로덕션 배포를 보호하고 승인된 브랜치로 제한한다.
- [ ] 승인된 Tailscale workload identity 또는 최소 권한 임시 자격 증명으로 hosted runner를 tailnet에 연결한다.
- [ ] CI tailnet ID는 `pylv-sepia`의 TCP 22번 포트에만 접근하도록 제한한다. Tailscale SSH가 비활성화되어 있으므로 Unix 계정과 명령 경계는 Tailscale SSH 사용자 규칙이 아니라 OpenSSH에서 강제한다.
- [ ] 전용 SSH 개인 키는 승인된 GitHub secret 경계에만 저장한다. Nix에는 강제 명령이 설정된 공개 키 엔트리만 둔다.
- [ ] 배포 사용자에게 비밀번호 없는 sudo, 저장소 쓰기 권한 또는 agenix secret 접근 권한을 부여하지 않는다.
- [ ] 이전 배포가 더 새로운 릴리스를 덮어쓰지 않도록 동시성 제어를 추가한다.
- [ ] 배포된 커밋 SHA를 기록하고 간결한 배포/롤백 진단 정보를 출력한다.

**검증:** Sveltia에서 작성한 테스트 커밋이 CI를 통과하고 정확히 한 번 배포되며 이전 릴리스로 롤백할 수 있다.

### 단계 8: 테스트용 Ghost 구성 제거

Astro의 공개 경로와 릴리스 롤백을 검증한 후 기존 테스트 구성을 제거한다.

- [ ] `hosts/pylv-sepia/configuration.nix`에서 `./ghost.nix` import를 제거한다.
- [ ] `hosts/pylv-sepia/ghost.nix`와 Ghost 전용 운영 문서를 제거한다.
- [ ] NixOS 설정을 적용하고 Ghost 컨테이너, nginx 오리진, timer unit이 사라졌는지 확인한다.
- [ ] Cloudflare Zero Trust 대시보드에서 `ghost.pylv.dev` 공개 호스트명 경로를 제거한다.
- [ ] Ghost 테스트 데이터 디렉터리는 삭제 직전에 경로와 내용을 다시 확인하고 명시적으로 제거한다.
- [ ] Ghost 제거 후에도 Astro 사이트와 Cloudflare 공개 경로가 정상인지 확인한다.

## 8. 검증 명령

정확한 블로그 명령은 커밋된 `package.json`에서 정의하되, 다음 검사를 목표로 한다.

```bash
bun ci
bun run format:check
bun run check
bun run test
bun run build
bun run smoke
```

Nix flake 검사:

```bash
nixfmt hosts/pylv-sepia/astro-blog.nix hosts/pylv-sepia/configuration.nix
nix flake check --no-build
nix build .#nixosConfigurations.pylv-sepia.config.system.build.toplevel
git diff --check
```

`pylv-sepia` 런타임 검사:

```bash
sudo systemctl status nginx.service
sudo nginx -t
curl --fail --head \
  --header 'Host: blog.pylv.dev' \
  http://127.0.0.1:12369/
curl --fail http://127.0.0.1:12369/rss.xml \
  --header 'Host: blog.pylv.dev'
readlink -f /srv/astro-blog/current
```

추가 검증 항목:

- 존재하지 않는 URL이 의도한 404 페이지와 HTTP 상태 404를 반환한다.
- 초안 제목과 URL이 `dist/` 어디에도 나타나지 않는다.
- `/admin/config.yml`에 비밀정보가 없으며 장기 캐시되지 않는다.
- fingerprint가 포함된 asset에 immutable 캐시 헤더가 적용된다.
- CMS에서 생성한 이미지와 게시물이 배포 후 올바르게 렌더링된다.
- RSS와 사이트맵이 최종 HTTPS canonical 호스트명을 사용한다.
- 배포 사용자가 `/run/agenix`를 읽거나 nginx 설정을 변경하거나 제한 없는 sudo를 실행할 수 없다.

## 9. 채택하지 않은 대안

- **프로덕션에서 Astro preview 서버 실행:** Astro는 preview를 로컬 미리보기 도구로 정의한다. nginx 정적 제공은 필요한 런타임 구성요소가 더 적다.
- **즉시 SSR 사용:** 초기 콘텐츠와 CMS 워크플로는 Git/빌드 기반이며 요청 시점 렌더링이 필요하지 않다.
- **기본적으로 이 인프라 저장소에 게시물 저장:** 편집 이력과 권한이 높은 인프라 이력을 혼합하고 모든 콘텐츠 발행을 인프라 이벤트로 만든다.
- **게시물마다 NixOS 재빌드:** 재현 가능하지만 편집 발행과 호스트 활성화를 불필요하게 결합한다. Nix는 배포 경계를 관리하고 릴리스 전환이 콘텐츠 아티팩트를 관리해야 한다.
- **`pylv-sepia`에서 임의의 새 커밋을 root로 직접 빌드:** 의존성이나 콘텐츠 빌드가 침해되면 프로덕션 호스트에서 과도한 권한으로 코드가 실행된다.
- **서버에서 상시 self-hosted GitHub runner 사용:** 호스트에 광범위한 원격 코드 실행 공격 표면을 추가한다.
- **버전이 지정되지 않은 Sveltia CDN 스크립트 사용:** 검토된 커밋 없이 upstream 변경이 관리자 애플리케이션을 변경할 수 있다.

## 10. 문서화 결과물

구현 후 다음 문서를 갱신한다.

- 블로그 저장소 `README.md`: 로컬 작성, 스키마, CMS 로그인, 빌드, 미디어 정책, CI 동작
- `hosts/pylv-sepia/README.md`: 서비스 구조, 수동 배포, 상태 검사, Cloudflare 오리진, 롤백
- 루트 `README.md`: 필요한 경우에만 호스트별 블로그 운영 섹션으로 연결하는 간단한 링크
- 실제 토큰, OAuth secret, 개인 키, tunnel token 또는 비밀 값을 문서화하지 않는다.

## 11. 주요 참고 자료

2026-08-08 확인:

- Astro 콘텐츠 컬렉션: <https://docs.astro.build/en/guides/content-collections/>
- Astro 설정(`site`, 정적 출력, `outDir`): <https://docs.astro.build/en/reference/configuration-reference/>
- Astro 배포 안내: <https://docs.astro.build/en/guides/deploy/>
- Bun 패키지 설치 및 CI: <https://bun.sh/docs/pm/cli/install>
- Sveltia CMS 시작 안내: <https://sveltiacms.app/en/docs/start>
- Sveltia CMS 기본 설정: <https://sveltiacms.app/en/docs/config-basics>
- Sveltia CMS GitHub 백엔드: <https://sveltiacms.app/en/docs/backends/github>
- Sveltia CMS 미디어 저장소: <https://sveltiacms.app/en/docs/media>
- Sveltia CMS editorial workflow 상태: <https://sveltiacms.app/en/docs/workflows/editorial>
- Sveltia CMS Authenticator: <https://github.com/sveltia/sveltia-cms-auth>
- Cloudflare Tunnel: <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/>
- Tailscale GitHub Action: <https://github.com/tailscale/github-action>

## 12. 완료 정의

- Astro 프로젝트를 고정된 의존성 집합에서 재현 가능하게 빌드할 수 있다.
- Sveltia가 수동 수정 없이 Astro 스키마를 통과하는 콘텐츠를 생성하고 편집할 수 있다.
- 프로덕션 출력에 초안이나 비밀정보가 없다.
- `pylv-sepia`가 선택한 정적 릴리스만 루프백 nginx 오리진을 통해 제공한다.
- Cloudflare가 새로운 인바운드 방화벽 포트를 열지 않고 공개 호스트명을 노출한다.
- 배포가 원자적이고 최소 권한이며 관찰 및 롤백 가능하다.
- 정상적인 Sveltia 콘텐츠 커밋이 CI를 통과하고 승인된 발행 경로를 통해 스테이징에 도달할 수 있다.
- 테스트용 Ghost 서비스와 공개 호스트명 경로가 제거되어 있다.
