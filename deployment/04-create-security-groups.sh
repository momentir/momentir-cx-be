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
    echo "먼저 이전 단계의 스크립트들을 실행해주세요."
    exit 1
fi

echo -e "${YELLOW}🔐 보안 그룹 생성 시작${NC}"

# ALB 보안 그룹 생성
ALB_SG_NAME="momentir-cx-be-alb-sg"
ALB_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$ALB_SG_NAME" --query 'SecurityGroups[0].GroupId' --output text --no-cli-pager 2>/dev/null)

if [ "$ALB_SG_ID" != "None" ] && [ "$ALB_SG_ID" != "" ]; then
    echo -e "${GREEN}✅ ALB 보안 그룹이 이미 존재합니다: $ALB_SG_ID${NC}"
else
    echo "ALB 보안 그룹 생성 중..."
    ALB_SG_ID=$(aws ec2 create-security-group \
        --group-name $ALB_SG_NAME \
        --description "Security group for momentir-cx-be ALB" \
        --vpc-id $VPC_ID \
        --query 'GroupId' \
        --output text --no-cli-pager)
    
    # HTTP 트래픽 허용
    aws ec2 authorize-security-group-ingress \
        --group-id $ALB_SG_ID \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 --no-cli-pager
    
    # HTTPS 트래픽 허용
    aws ec2 authorize-security-group-ingress \
        --group-id $ALB_SG_ID \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 --no-cli-pager
    
    aws ec2 create-tags --resources $ALB_SG_ID --tags Key=Name,Value=$ALB_SG_NAME --no-cli-pager
    echo -e "${GREEN}✅ ALB 보안 그룹 생성 완료: $ALB_SG_ID${NC}"
fi

# ECS 서비스 보안 그룹 생성
ECS_SG_NAME="momentir-cx-be-ecs-sg"
ECS_SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$ECS_SG_NAME" --query 'SecurityGroups[0].GroupId' --output text --no-cli-pager 2>/dev/null)

if [ "$ECS_SG_ID" != "None" ] && [ "$ECS_SG_ID" != "" ]; then
    echo -e "${GREEN}✅ ECS 보안 그룹이 이미 존재합니다: $ECS_SG_ID${NC}"
else
    echo "ECS 서비스 보안 그룹 생성 중..."
    ECS_SG_ID=$(aws ec2 create-security-group \
        --group-name $ECS_SG_NAME \
        --description "Security group for momentir-cx-be ECS service" \
        --vpc-id $VPC_ID \
        --query 'GroupId' \
        --output text --no-cli-pager)
    
    # ALB에서의 트래픽만 허용 (포트 8081)
    aws ec2 authorize-security-group-ingress \
        --group-id $ECS_SG_ID \
        --protocol tcp \
        --port 8081 \
        --source-group $ALB_SG_ID --no-cli-pager
    
    aws ec2 create-tags --resources $ECS_SG_ID --tags Key=Name,Value=$ECS_SG_NAME --no-cli-pager
    echo -e "${GREEN}✅ ECS 서비스 보안 그룹 생성 완료: $ECS_SG_ID${NC}"
fi

# 환경변수 파일에 보안 그룹 정보 추가
echo "ALB_SG_ID=$ALB_SG_ID" >> deployment/env.sh
echo "ECS_SG_ID=$ECS_SG_ID" >> deployment/env.sh

echo -e "${GREEN}🎉 보안 그룹 설정 완료!${NC}"