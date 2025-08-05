#!/bin/bash

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 변수 설정
REGION="ap-northeast-2"
REPOSITORY_NAME="momentir-cx-be"

echo -e "${YELLOW}🚀 ECR 리포지토리 생성 시작${NC}"

# ECR 리포지토리 존재 확인
echo "ECR 리포지토리 확인 중..."
REPO_CHECK_RESULT=$(aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $REGION --no-cli-pager 2>&1)
REPO_CHECK_EXIT_CODE=$?

if [ $REPO_CHECK_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ ECR 리포지토리가 이미 존재합니다: $REPOSITORY_NAME${NC}"
else
    echo "ECR 리포지토리 생성 중..."
    CREATE_RESULT=$(aws ecr create-repository \
        --repository-name $REPOSITORY_NAME \
        --region $REGION \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256 \
        --no-cli-pager 2>&1)
    CREATE_EXIT_CODE=$?
    
    if [ $CREATE_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✅ ECR 리포지토리 생성 완료: $REPOSITORY_NAME${NC}"
    else
        echo -e "${RED}❌ ECR 리포지토리 생성 실패${NC}"
        echo "오류 내용: $CREATE_RESULT"
        exit 1
    fi
fi

# 리포지토리 URI 가져오기
REPOSITORY_URI=$(aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $REGION --query 'repositories[0].repositoryUri' --output text --no-cli-pager)
echo -e "${GREEN}📍 Repository URI: $REPOSITORY_URI${NC}"

# 환경변수 파일에 저장
echo "REPOSITORY_URI=$REPOSITORY_URI" > deployment/env.sh
echo "REGION=$REGION" >> deployment/env.sh
echo "REPOSITORY_NAME=$REPOSITORY_NAME" >> deployment/env.sh

echo -e "${GREEN}🎉 ECR 리포지토리 설정 완료!${NC}"