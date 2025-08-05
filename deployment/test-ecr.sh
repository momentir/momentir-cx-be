#!/bin/bash

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔍 ECR 스크립트 테스트${NC}"

# AWS CLI 확인
echo "AWS CLI 테스트..."
if aws sts get-caller-identity --no-cli-pager >/dev/null 2>&1; then
    echo -e "${GREEN}✅ AWS CLI 인증 성공${NC}"
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --no-cli-pager)
    echo "  - Account ID: $ACCOUNT_ID"
    echo "  - Region: ap-northeast-2"
else
    echo -e "${RED}❌ AWS CLI 인증 실패${NC}"
    exit 1
fi

# ECR 테스트
echo ""
echo "ECR 리포지토리 테스트..."
REPOSITORY_NAME="momentir-cx-be"
REGION="ap-northeast-2"

echo "리포지토리 확인: $REPOSITORY_NAME"
if aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $REGION --no-cli-pager >/dev/null 2>&1; then
    echo -e "${GREEN}✅ ECR 리포지토리 존재함${NC}"
    REPOSITORY_URI=$(aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $REGION --query 'repositories[0].repositoryUri' --output text --no-cli-pager)
    echo "  - Repository URI: $REPOSITORY_URI"
else
    echo -e "${YELLOW}⚠️  ECR 리포지토리가 존재하지 않음 (정상 - 첫 배포시)${NC}"
fi

echo ""
echo -e "${GREEN}🎉 기본 테스트 완료!${NC}"
echo "이제 bash deployment/deploy.sh를 실행할 수 있습니다."