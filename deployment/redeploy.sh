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

# 환경변수 파일 확인
if [ ! -f "deployment/env.sh" ]; then
    echo -e "${RED}❌ deployment/env.sh 파일을 찾을 수 없습니다${NC}"
    echo "먼저 전체 배포를 실행해주세요: bash deployment/deploy.sh"
    exit 1
fi

# 환경변수 로드 (파일이 없으면 스킵)
if [ -f "deployment/env.sh" ]; then
    source deployment/env.sh
else
    echo -e "${RED}❌ deployment/env.sh 파일을 찾을 수 없습니다${NC}"
    echo "먼저 전체 배포를 실행해주세요: bash deployment/deploy.sh"
    exit 1
fi

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    🔄 MOMENTIR-CX-BE 재배포                  ║"
echo "║                      (코드 변경사항 적용)                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}🔄 재배포 프로세스를 시작합니다...${NC}"
echo "• Docker 이미지 새로 빌드"
echo "• ECR에 새 이미지 푸시"
echo "• ECS 태스크 정의 업데이트"
echo "• ECS 서비스 재배포"
echo ""

read -p "계속하시겠습니까? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⏸️  재배포를 중단합니다${NC}"
    exit 0
fi

# 1. Docker 이미지 빌드 및 푸시
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}🔨 Docker 이미지 빌드 및 푸시${NC}"
echo -e "${BLUE}========================================${NC}"

chmod +x deployment/02-build-and-push-image.sh
bash deployment/02-build-and-push-image.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Docker 이미지 빌드/푸시 실패${NC}"
    exit 1
fi

# Image URI 업데이트 (env.sh 파일에서 다시 로드)
source deployment/env.sh

# 2. ECS 태스크 정의 업데이트
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}📋 ECS 태스크 정의 업데이트${NC}"
echo -e "${BLUE}========================================${NC}"

chmod +x deployment/08-create-ecs-task-definition.sh
bash deployment/08-create-ecs-task-definition.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ ECS 태스크 정의 업데이트 실패${NC}"
    exit 1
fi

# 3. ECS 서비스 재배포
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}🚀 ECS 서비스 재배포${NC}"
echo -e "${BLUE}========================================${NC}"

echo "ECS 서비스 강제 재배포 중..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --task-definition $FAMILY_NAME \
    --force-new-deployment \
    --no-cli-pager > /dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ECS 서비스 재배포 시작됨${NC}"
else
    echo -e "${RED}❌ ECS 서비스 재배포 실패${NC}"
    exit 1
fi

# 4. 배포 상태 모니터링
echo "배포 진행 상황 모니터링 중..."
echo -e "${YELLOW}⏰ 새로운 태스크가 시작되고 이전 태스크가 종료될 때까지 기다리는 중...${NC}"

# 배포 완료 대기 (최대 10분)
TIMEOUT=600
ELAPSED=0
INTERVAL=15

while [ $ELAPSED -lt $TIMEOUT ]; do
    # 서비스 상태 확인
    DEPLOYMENT_STATUS=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --query 'services[0].deployments[0].status' \
        --output text --no-cli-pager)
    
    RUNNING_COUNT=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --query 'services[0].runningCount' \
        --output text --no-cli-pager)
    
    DESIRED_COUNT=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --query 'services[0].desiredCount' \
        --output text --no-cli-pager)
    
    echo "상태: $DEPLOYMENT_STATUS | 실행 중: $RUNNING_COUNT/$DESIRED_COUNT | 경과: ${ELAPSED}s"
    
    if [ "$DEPLOYMENT_STATUS" = "PRIMARY" ] && [ "$RUNNING_COUNT" = "$DESIRED_COUNT" ]; then
        echo -e "${GREEN}✅ 배포 완료!${NC}"
        break
    fi
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo -e "${YELLOW}⚠️  배포 모니터링 시간이 초과되었습니다${NC}"
    echo "수동으로 확인해주세요: aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME"
fi

# 5. 최종 상태 확인
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}🔍 최종 상태 확인${NC}"
echo -e "${BLUE}========================================${NC}"

echo "서비스 상태:"
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --query 'services[0].{Name:serviceName,Status:status,RunningCount:runningCount,PendingCount:pendingCount,DesiredCount:desiredCount}' \
    --output table --no-cli-pager

echo ""
echo "실행 중인 태스크:"
TASK_ARNS=$(aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --service-name $SERVICE_NAME \
    --query 'taskArns' \
    --output text --no-cli-pager)

if [ "$TASK_ARNS" != "" ] && [ "$TASK_ARNS" != "None" ]; then
    aws ecs describe-tasks \
        --cluster $CLUSTER_NAME \
        --tasks $TASK_ARNS \
        --query 'tasks[0].{TaskArn:taskArn,LastStatus:lastStatus,HealthStatus:healthStatus,CreatedAt:createdAt}' \
        --output table --no-cli-pager
else
    echo -e "${YELLOW}⚠️  실행 중인 태스크가 없습니다${NC}"
fi

# 완료 메시지
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     🎉 재배포 완료!                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${GREEN}📍 업데이트된 서비스 정보:${NC}"
if [ ! -z "$API_SUBDOMAIN" ]; then
    echo "• API URL: https://$API_SUBDOMAIN"
    echo "• Swagger: https://$API_SUBDOMAIN/docs"
    echo "• Health Check: https://$API_SUBDOMAIN/health"
else
    echo "• ALB URL: https://$ALB_DNS"
    echo "• Swagger: https://$ALB_DNS/docs"
    echo "• Health Check: https://$ALB_DNS/health"
fi

echo ""
echo -e "${YELLOW}📋 로그 확인:${NC}"
echo "aws logs tail /ecs/$FAMILY_NAME --follow"

echo -e "${GREEN}✨ 재배포가 성공적으로 완료되었습니다!${NC}"