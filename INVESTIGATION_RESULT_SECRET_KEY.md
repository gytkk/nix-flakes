# Secret Key Investigation Result

작성일: 2026-04-13 UTC

## 대상

- 파일: `secrets/secrets.nix`
- 조사 키: `gytkkCurrent`

## 요약

현재 상태는 키 교체가 완전히 끝난 상태가 아니다.

- `gytkkCurrent`는 2026-04-12에 추가되었다.
- 현재 로컬 머신의 `~/.ssh/id_ed25519.pub`는 `gytkkCurrent`와 일치한다.
- 하지만 `allUsers`는 아직 `gytkk`만 포함한다.
- 결과적으로 `gytkkCurrent`는 일부 WebUI 관련 secret에만 예외적으로 추가되어 있다.

## 확인 결과

### 1. `gytkkCurrent`가 추가된 시점

처음 추가된 커밋:

- 커밋: `5cac86c2e4a2415206f20e7e6ff2873cd2376f3c`
- 날짜: `2026-04-12 01:47:06 +0000`
- 메시지: `fix(pylv-onyx): wire open-webui to openclaw`

이 커밋에서 일어난 일:

- `secrets/secrets.nix`에 `gytkkCurrent` 공개키 정의 추가
- `open-webui-env.age` recipient에 `gytkkCurrent` 추가
- `open-webui-env.age` 자체도 재암호화됨

이후 재사용된 커밋:

- 커밋: `1c8e13f71e1244c62e96a7ee6b865b871eea84ca`
- 날짜: `2026-04-12 23:48:52 +0000`
- 메시지: `feat: add hermes webui host service`

이 커밋에서는 새 파일 `hermes-webui-env.age`가 생성되면서 `gytkkCurrent`가 recipient에 포함되었다.

### 2. `gytkk`의 히스토리

`gytkk`는 원래부터 기본 사용자 키였다.

중요한 변경:

- 커밋: `59b9dc311f3a8a8c7823bea7f481c2377a5de164`
- 날짜: `2026-03-25 21:42:04 +0900`
- 메시지: `fix(secrets): add pylv-onyx host key and update user key`

이 커밋 메시지에는 다음 의미가 직접 들어 있다.

- `Update gytkk user key to current WSL key`
- `Rekey required after this commit (from pylv-sepia)`

즉 2026-03-25 시점에는 `gytkk` 자체가 당시의 최신 사용자 키로 교체되었다.

바로 다음 커밋:

- 커밋: `dc619e0e3b31de5b0de50419357713fa38ab1500`
- 날짜: `2026-03-25 21:45:53 +0900`
- 메시지: `fix: Replace agenix secrets`

이 커밋에서 기존 secret 파일들이 재암호화되었다.

## 현재 코드 상태

현재 `secrets/secrets.nix`는 다음 의미를 가진다.

- `gytkk`: 기존 기본 사용자 키
- `gytkkCurrent`: 나중에 추가된 새 사용자 키
- `allUsers = [ gytkk ];`

따라서 기본 recipient 집합은 아직 `gytkkCurrent`로 전환되지 않았다.

`gytkkCurrent`가 포함된 파일은 현재 두 개뿐이다.

- `open-webui-env.age`
- `hermes-webui-env.age`

반면 아래 파일들은 여전히 `allUsers ++ allHosts` 또는 `allUsers ++ devsistersHosts`를 사용하므로 `gytkk` 기준이다.

- `cloudflare-tunnel-sepia-token.age`
- `cloudflare-tunnel-onyx-token.age`
- `discord-bot-token.age`
- `hermes-discord-bot-token.age`
- `gws-credentials.age`
- `databricks-token.age`

## 로컬 머신 기준 검증 결과

현재 로컬 `~/.ssh/id_ed25519.pub`는 다음 공개키와 일치한다.

- `gytkkCurrent = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH4fQ+YuQEWjtoSxCYydHbmerei0EQ2QC/z7GQZWjZmU"`

일치하지 않는 키:

- `gytkk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhE4Uakcz7usa0aetMqb99LYybOQ0I+sWKOiAidmBio"`

실제 복호화 확인 결과:

- 성공: `secrets/open-webui-env.age`
- 성공: `secrets/hermes-webui-env.age`
- 실패: `secrets/cloudflare-tunnel-onyx-token.age`
- 실패: `secrets/hermes-discord-bot-token.age`
- 실패: `secrets/gws-credentials.age`

이 결과는 현재 로컬 개인키가 `gytkkCurrent`에 대응하고, 대부분의 secret은 아직 그 키로 재암호화되지 않았음을 보여준다.

## 결론

현재 해석은 다음과 같다.

- `gytkkCurrent`는 현재 로컬 머신에서 실제로 사용하는 사용자 키다.
- `gytkk`는 repo에서 아직 기본 recipient로 남아 있는 이전 사용자 키다.
- 키 전환은 전체 완료가 아니라 WebUI 관련 secret 두 개에만 부분 적용된 상태다.

## 메모

사용자 추정:

- `gytkkCurrent`는 기존 머신에서 추가하지 않았을 가능성이 높다.

현재 문서는 조사 결과만 기록한다.
키 정리나 rekey 작업은 이후 별도 수행한다.
