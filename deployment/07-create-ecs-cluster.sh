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

echo -e "${YELLOW}🚀 ECS 클러스터 생성 시작${NC}"

CLUSTER_NAME="momentir-cx-be"

# ECS 클러스터 존재 확인
CLUSTER_ARN=$(aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].clusterArn' --output text --no-cli-pager 2>/dev/null)

if [ "$CLUSTER_ARN" != "None" ] && [ "$CLUSTER_ARN" != "" ]; then
    echo -e "${GREEN}✅ ECS 클러스터가 이미 존재합니다: $CLUSTER_ARN${NC}"
    
    # 클러스터 상태 확인
    CLUSTER_STATUS=$(aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].status' --output text --no-cli-pager)
    echo "클러스터 상태: $CLUSTER_STATUS"
else
    echo "ECS 클러스터 생성 중..."
    CLUSTER_ARN=$(aws ecs create-cluster \
        --cluster-name $CLUSTER_NAME \
        --capacity-providers FARGATE \
        --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1 \
        --tags key=Name,value=$CLUSTER_NAME \
        --query 'cluster.clusterArn' \
        --output text --no-cli-pager)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ ECS 클러스터 생성 완료: $CLUSTER_ARN${NC}"
    else
        echo -e "${RED}❌ ECS 클러스터 생성 실패${NC}"
        exit 1
    fi
fi

# 클러스터 정보 표시
echo "클러스터 정보:"
aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].{Name:clusterName,Status:status,RunningTasks:runningTasksCount,PendingTasks:pendingTasksCount,ActiveServices:activeServicesCount}' --output table --no-cli-pager

# 환경변수 파일에 클러스터 정보 추가
echo "CLUSTER_NAME=$CLUSTER_NAME" >> deployment/env.sh
echo "CLUSTER_ARN=$CLUSTER_ARN" >> deployment/env.sh

echo -e "${GREEN}🎉 ECS 클러스터 설정 완료!${NC}"