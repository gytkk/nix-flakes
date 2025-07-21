#!/usr/bin/env bash

NEW_VERSION=$1
VERSION_SPEC=${2:-">="}  # =, >=, ~> 등

if [ -z "$NEW_VERSION" ]; then
  echo "Usage: $0 <terraform-version> [version-spec]"
  echo "Examples:"
  echo "  $0 1.10.2 =     # 정확한 버전"
  echo "  $0 1.10.2 >=    # 최소 버전 (기본값)"
  echo "  $0 1.10.0 ~>    # 범위 버전"
  exit 1
fi

# Terraform 설정 파일 찾기 및 업데이트
for tf_file in backend.tf versions.tf main.tf; do
  if [[ -f "$tf_file" ]]; then
    if grep -q "required_version" "$tf_file"; then
      # 기존 required_version 업데이트
      sed -i "s/required_version\\s*=\\s*\"[^\"]*\"/required_version = \"$VERSION_SPEC $NEW_VERSION\"/" "$tf_file"
      echo "✅ Updated required_version in $tf_file"
      break
    fi
  fi
done

# direnv 재로드
direnv reload

echo "✅ Switched to Terraform $VERSION_SPEC $NEW_VERSION"
echo "🔄 Environment will reload automatically"