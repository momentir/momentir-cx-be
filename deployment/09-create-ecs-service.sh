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

echo -e "${YELLOW}🚀 ECS 서비스 생성 시작${NC}"

SERVICE_NAME="momentir-cx-be"

# ECS 서비스 존재 확인
SERVICE_ARN=$(aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --query 'services[0].serviceArn' \
    --output text --no-cli-pager 2>/dev/null)

if [ "$SERVICE_ARN" != "None" ] && [ "$SERVICE_ARN" != "" ]; then
    echo -e "${GREEN}✅ ECS 서비스가 이미 존재합니다: $SERVICE_ARN${NC}"
    
    # 서비스 업데이트 (새로운 태스크 정의 적용)
    echo "서비스 업데이트 중..."
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --task-definition $FAMILY_NAME \
        --desired-count 1 \
        --no-cli-pager > /dev/null
    
    echo -e "${GREEN}✅ ECS 서비스 업데이트 완료${NC}"
else
    echo "ECS 서비스 생성 중..."
    
    # 서비스 생성
    SERVICE_ARN=$(aws ecs create-service \
        --cluster $CLUSTER_NAME \
        --service-name $SERVICE_NAME \
        --task-definition $FAMILY_NAME \
        --desired-count 1 \
        --launch-type FARGATE \
        --platform-version LATEST \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_PUBLIC_A_ID,$SUBNET_PUBLIC_B_ID],securityGroups=[$ECS_SG_ID],assignPublicIp=ENABLED}" \
        --load-balancers "targetGroupArn=$TG_ARN,containerName=$FAMILY_NAME,containerPort=8081" \
        --health-check-grace-period-seconds 120 \
        --enable-execute-command \
        --query 'service.serviceArn' \
        --output text --no-cli-pager)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ ECS 서비스 생성 완료: $SERVICE_ARN${NC}"
    else
        echo -e "${RED}❌ ECS 서비스 생성 실패${NC}"
        exit 1
    fi
fi

# 서비스 안정화 대기
echo "서비스 안정화 대기 중... (최대 10분)"
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $REGION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ 서비스가 안정 상태입니다${NC}"
else
    echo -e "${YELLOW}⚠️  서비스 안정화 대기 시간이 초과되었습니다. 수동으로 확인해주세요.${NC}"
fi

# 서비스 상태 확인
echo "서비스 상태 확인 중..."
aws ecs describe-services \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --query 'services[0].{Name:serviceName,Status:status,RunningCount:runningCount,PendingCount:pendingCount,DesiredCount:desiredCount}' \
    --output table --no-cli-pager

# 태스크 상태 확인
echo "실행 중인 태스크 확인..."
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

# 환경변수 파일에 서비스 정보 추가
echo "SERVICE_NAME=$SERVICE_NAME" >> deployment/env.sh
echo "SERVICE_ARN=$SERVICE_ARN" >> deployment/env.sh

echo -e "${GREEN}🎉 ECS 서비스 설정 완료!${NC}"
echo -e "${YELLOW}📍 서비스 상태를 계속 모니터링하세요:${NC}"
echo "aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME"