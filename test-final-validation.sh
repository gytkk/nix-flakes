#!/usr/bin/env bash

echo "🧪 Testing terraform-direnv integration..."

# 1. 테스트 디렉토리로 이동
cd test-terraform-project || exit 1

echo "📁 Current directory: $(pwd)"
echo "📄 backend.tf contents:"
cat backend.tf

echo ""
echo "🔍 Testing direnv integration..."

# direnv 다시 허용 및 로드
direnv allow
direnv reload

echo ""
echo "✅ Integration test completed!"
echo "💡 If you see Terraform environment loaded, it's working correctly!"