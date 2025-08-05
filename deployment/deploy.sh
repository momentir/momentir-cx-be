#!/bin/bash

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 현재 디렉토리가 프로젝트 루트인지 확인
if [ ! -f "go.mod" ] || [ ! -f "Dockerfile" ]; then
    echo -e "${RED}❌ 프로젝트 루트 디렉토리에서 실행해주세요${NC}"
    exit 1
fi

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    🚀 MOMENTIR-CX-BE 배포                    ║"
echo "║                     AWS ECS Fargate 배포                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 환경변수 파일 초기화
rm -f deployment/env.sh
touch deployment/env.sh

# 스크립트 실행 함수
run_script() {
    local script=$1
    local description=$2
    
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}🔄 $description${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    if [ -f "deployment/$script" ]; then
        chmod +x "deployment/$script"
        bash "deployment/$script"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ $description 완료${NC}"
        else
            echo -e "${RED}❌ $description 실패${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ 스크립트를 찾을 수 없습니다: deployment/$script${NC}"
        exit 1
    fi
    
    echo ""
}

# 사전 확인
echo -e "${YELLOW}📋 배포 전 확인사항${NC}"
echo "1. AWS CLI가 설치되고 구성되어 있나요?"
echo "2. Docker가 설치되고 실행 중인가요?"
echo "3. momentir.com 도메인의 ACM 인증서가 준비되어 있나요?"
echo "4. .env 파일이 올바르게 설정되어 있나요?"
echo ""

read -p "모든 확인사항이 준비되었습니까? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⏸️  배포를 중단합니다${NC}"
    exit 0
fi

echo ""

# 1단계: ECR 리포지토리 생성
run_script "01-create-ecr-repository.sh" "ECR 리포지토리 생성"

# 2단계: Docker 이미지 빌드 및 푸시
run_script "02-build-and-push-image.sh" "Docker 이미지 빌드 및 푸시"

# 3단계: VPC 및 네트워킹 설정
run_script "03-create-vpc-and-networking.sh" "VPC 및 네트워킹 인프라 구성"

# 4단계: 보안 그룹 생성
run_script "04-create-security-groups.sh" "보안 그룹 생성"

# 5단계: ACM 인증서 확인
run_script "05-check-acm-certificate.sh" "ACM 인증서 확인"

# 6단계: ALB 생성
run_script "06-create-alb.sh" "Application Load Balancer 생성"

# 7단계: ECS 클러스터 생성
run_script "07-create-ecs-cluster.sh" "ECS 클러스터 생성"

# 8-1단계: SSM Parameter Store 설정
echo -e "${YELLOW}🔐 환경변수를 AWS Systems Manager Parameter Store에 설정합니다${NC}"
read -p "계속하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    run_script "08-1-setup-ssm-parameters.sh" "SSM Parameter Store 설정"
else
    echo -e "${YELLOW}⚠️  Parameter Store 설정을 건너뜁니다. 수동으로 설정해주세요.${NC}"
fi

# 8단계: ECS 태스크 정의 생성
run_script "08-create-ecs-task-definition.sh" "ECS 태스크 정의 생성"

# 9단계: ECS 서비스 생성
run_script "09-create-ecs-service.sh" "ECS 서비스 생성"

# 10단계: Route53 레코드 생성
echo -e "${YELLOW}🌐 Route53 DNS 레코드를 생성합니다${NC}"
read -p "계속하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    run_script "10-create-route53-records.sh" "Route53 레코드 생성"
else
    echo -e "${YELLOW}⚠️  Route53 설정을 건너뜁니다. 수동으로 설정해주세요.${NC}"
fi

# 배포 완료 정보 표시
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                      🎉 배포 완료!                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 환경변수 로드
source deployment/env.sh

echo -e "${GREEN}📍 배포된 리소스 정보:${NC}"
echo "• ECR Repository: $REPOSITORY_URI"
echo "• ECS Cluster: $CLUSTER_NAME"
echo "• ALB DNS: $ALB_DNS"
if [ ! -z "$API_SUBDOMAIN" ]; then
    echo "• API URL: https://$API_SUBDOMAIN"
    echo "• Swagger: https://$API_SUBDOMAIN/docs"
fi
echo ""

echo -e "${YELLOW}🔍 유용한 AWS CLI 명령어:${NC}"
echo "• 서비스 상태 확인:"
echo "  aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME"
echo ""
echo "• 서비스 로그 확인:"
echo "  aws logs tail /ecs/$FAMILY_NAME --follow"
echo ""
echo "• 서비스 재배포:"
echo "  aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --force-new-deployment"
echo ""

echo -e "${GREEN}✨ 배포가 성공적으로 완료되었습니다!${NC}"