#!/bin/bash

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 환경변수 로드 (파일이 없으면 스킵)
if [ -f "deployment/env.sh" ]; then
    source deployment/env.sh
else
    echo -e "${RED}❌ deployment/env.sh 파일을 찾을 수 없습니다${NC}"
    echo "먼저 01-create-ecr-repository.sh를 실행해주세요."
    exit 1
fi

echo -e "${YELLOW}🔨 Docker 이미지 빌드 및 푸시 시작${NC}"

# Docker 이미지 태그
IMAGE_TAG="latest"
FULL_IMAGE_URI="$REPOSITORY_URI:$IMAGE_TAG"

# ECR 로그인
echo "ECR 로그인 중..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REPOSITORY_URI

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ECR 로그인 성공${NC}"
else
    echo -e "${RED}❌ ECR 로그인 실패${NC}"
    exit 1
fi

# Docker 이미지 빌드
echo "Docker 이미지 빌드 중..."
docker build -t $REPOSITORY_NAME:$IMAGE_TAG .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Docker 이미지 빌드 완료${NC}"
else
    echo -e "${RED}❌ Docker 이미지 빌드 실패${NC}"
    exit 1
fi

# 이미지 태그 추가
echo "이미지 태그 추가 중..."
docker tag $REPOSITORY_NAME:$IMAGE_TAG $FULL_IMAGE_URI

# ECR에 이미지 푸시
echo "ECR에 이미지 푸시 중..."
docker push $FULL_IMAGE_URI

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 이미지 푸시 완료${NC}"
    echo -e "${GREEN}📍 Image URI: $FULL_IMAGE_URI${NC}"
else
    echo -e "${RED}❌ 이미지 푸시 실패${NC}"
    exit 1
fi

# 환경변수 파일에 이미지 URI 추가
echo "IMAGE_URI=$FULL_IMAGE_URI" >> deployment/env.sh

echo -e "${GREEN}🎉 Docker 이미지 빌드 및 푸시 완료!${NC}"