# 🧪 Terraform Direnv 테스트 지침

## 현재 상황

- 파싱 로직은 정상 작동 확인됨 ✅
- `backend.tf`에서 `= 1.10.2` 올바르게 감지됨 ✅
- 하지만 실제 환경에서 1.12.2가 로드됨 ❌

## 테스트 단계

### 1. 디버그 정보 확인

```bash
cd ~/development/nix-flakes/test-terraform-project
direnv reload
```

다음과 같은 출력을 확인하세요:

```
🚀 Terraform X.X.X environment loaded from terraform config
📁 Project: /home/gytkk/development/nix-flakes/test-terraform-project
🔍 Debug: PWD=/home/gytkk/development/nix-flakes/test-terraform-project
🔍 Debug: backend.tf exists: yes
```

### 2. 예상 출력과 비교

**예상**: `🚀 Terraform 1.10.2 environment loaded`
**실제**: `🚀 Terraform 1.12.2 environment loaded`

### 3. 디버그 정보 확인 포인트

1. **PWD가 올바르게 설정되었는가?**
   - `🔍 Debug: PWD=`에서 올바른 경로가 나오는지 확인

2. **backend.tf가 감지되었는가?**
   - `🔍 Debug: backend.tf exists: yes`가 나오는지 확인

3. **만약 PWD가 비어있다면**
   - direnv가 아닌 다른 방법으로 실행 중일 가능성

### 4. 문제 해결 방법

PWD가 올바르게 설정되지 않는다면:

#### 방법 1: direnv 재시작

```bash
direnv disallow
direnv allow
```

#### 방법 2: 수동으로 PWD 확인

```bash
cd ~/development/nix-flakes/test-terraform-project
echo $PWD
```

#### 방법 3: flake 직접 테스트

```bash
# 현재 디렉토리에서
nix develop ~/.config/nix-direnv/terraform-flake --command bash -c 'echo "PWD in nix: $PWD"; terraform version'
```

### 5. 결과 보고

어떤 출력을 받았는지 알려주시면 정확한 문제를 진단할 수 있습니다:

1. PWD 값
2. backend.tf 감지 여부
3. 실제 로드된 Terraform 버전

## 임시 해결책

만약 계속 문제가 발생한다면, 환경 변수로 디렉토리를 전달하는 방식으로 수정할 수 있습니다:

```bash
cd ~/development/nix-flakes/test-terraform-project
TF_PROJECT_DIR=$PWD direnv reload
```
