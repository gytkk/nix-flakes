# Terraform 모듈

[tenv](https://github.com/tofuutils/tenv)를 설치하고 프로젝트에 맞는 Terraform 버전을 실행한다. Devsisters 환경에서 활성화하며, Terraform 바이너리는 Nix로 빌드하지 않고 처음 실행할 때 tenv가 다운로드한다.

## 설정

```nix
modules.terraform = {
  enable = true;
  runEnv = {
    AWS_PROFILE = "saml";
  };
};
```

`enable`의 기본값은 `false`이고, `runEnv`의 기본값은 `{}`이다. `runEnv`는 `tf` alias에만 적용한다. 위 설정에서 `tf plan`은 `AWS_PROFILE=saml terraform plan`으로 실행된다.

## 버전 선택

`terraform`은 tenv proxy를 통해 실행된다. `.terraform-version` 같은 프로젝트 버전 파일이 있으면 해당 설정을 사용한다. 버전 파일이 없으면 `TFENV_TERRAFORM_DEFAULT_VERSION=latest-allowed`에 따라 현재 디렉터리의 `.tf` 및 `.tf.json` 파일에 있는 `required_version` 조건을 만족하는 버전을 선택한다. 이 기본 전략은 `tenv tf use`로 저장한 전역 기본값보다 우선하며, 명시적인 `TFENV_TERRAFORM_VERSION` 환경 변수는 프로젝트 버전 파일보다 우선한다.

```hcl
terraform {
  required_version = ">= 1.10.0, < 1.11.0, != 1.10.1"
}
```

tenv는 먼저 설치된 버전 중 조건을 만족하는 가장 높은 버전을 사용한다. 설치된 버전으로 조건을 만족하지 못하면 원격 목록에서 버전을 선택하며, `TENV_AUTO_INSTALL=true`에 따라 필요한 바이너리를 자동으로 설치한다. 처음 다운로드할 때는 네트워크가 필요하다. 프로젝트에 버전 파일과 제약 조건이 모두 없으면 같은 방식으로 최신 안정 버전을 선택한다.

정확한 버전을 고정하려면 프로젝트에 `.terraform-version`을 저장한다.

```text
1.10.5
```

명시한 버전과 `required_version` 조건이 충돌하면 Terraform 자체의 제약 조건 검사가 실패하므로 두 설정을 함께 관리한다. Terraform 버전과 tenv 상태는 기본적으로 `~/.tenv`에 저장된다. `TENV_ROOT`를 설정하면 저장 위치를 바꿀 수 있다.

## 기존 direnv 설정 전환

버전 선택은 각 `terraform` 실행 시 tenv가 처리하므로 새 프로젝트에는 Terraform 전용 `.envrc`가 필요하지 않다. 기존 `.envrc`는 그대로 사용할 수 있다.

```bash
use_terraform
```

이 함수는 tenv의 실행 파일 디렉터리를 PATH 앞에 추가한다. 이전 모듈이 생성한 `.direnv/bin/terraform`이 있어도 tenv proxy를 먼저 사용하며, 프로젝트 파일을 삭제하거나 임시 Nix flake를 생성하지 않는다. `home-manager switch` 후 기존 셸을 다시 시작하고, 이미 허용한 `.envrc`는 `direnv reload`로 다시 불러온다.

이전 `modules.terraform.defaultVersion` 옵션은 제거했다. 해당 설정이 있으면 삭제하고, 프로젝트 버전은 `.terraform-version`이나 `required_version`으로 지정한다. 버전 목록을 갱신하기 위한 별도 Terraform flake input도 필요하지 않다.
