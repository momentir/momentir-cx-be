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

echo -e "${YELLOW}⚖️ Application Load Balancer 생성 시작${NC}"

ALB_NAME="momentir-cx-be-alb"
TG_NAME="momentir-cx-be-tg"

# ALB 존재 확인
echo "ALB 존재 여부 확인 중..."
if aws elbv2 describe-load-balancers --names $ALB_NAME --no-cli-pager >/dev/null 2>&1; then
    ALB_ARN=$(aws elbv2 describe-load-balancers --names $ALB_NAME --query 'LoadBalancers[0].LoadBalancerArn' --output text --no-cli-pager)
    echo -e "${GREEN}✅ ALB가 이미 존재합니다: $ALB_ARN${NC}"
else
    echo "Application Load Balancer 생성 중..."
    echo "  - 이름: $ALB_NAME"
    echo "  - 서브넷: $SUBNET_PUBLIC_A_ID, $SUBNET_PUBLIC_B_ID"
    echo "  - 보안그룹: $ALB_SG_ID"
    
    # 변수 확인
    if [ -z "$SUBNET_PUBLIC_A_ID" ] || [ -z "$SUBNET_PUBLIC_B_ID" ] || [ -z "$ALB_SG_ID" ]; then
        echo -e "${RED}❌ 필수 변수가 설정되지 않았습니다${NC}"
        echo "  - SUBNET_PUBLIC_A_ID: $SUBNET_PUBLIC_A_ID"
        echo "  - SUBNET_PUBLIC_B_ID: $SUBNET_PUBLIC_B_ID"  
        echo "  - ALB_SG_ID: $ALB_SG_ID"
        echo "이전 단계의 스크립트들이 올바르게 실행되었는지 확인해주세요."
        exit 1
    fi
    
    ALB_ARN=$(aws elbv2 create-load-balancer \
        --name $ALB_NAME \
        --subnets $SUBNET_PUBLIC_A_ID $SUBNET_PUBLIC_B_ID \
        --security-groups $ALB_SG_ID \
        --scheme internet-facing \
        --type application \
        --ip-address-type ipv4 \
        --query 'LoadBalancers[0].LoadBalancerArn' \
        --output text --no-cli-pager)
    
    if [ $? -eq 0 ] && [ "$ALB_ARN" != "None" ] && [ "$ALB_ARN" != "" ]; then
        echo -e "${GREEN}✅ ALB 생성 완료: $ALB_ARN${NC}"
    else
        echo -e "${RED}❌ ALB 생성 실패${NC}"
        echo "AWS CLI 명령어를 수동으로 실행해서 오류를 확인해보세요:"
        echo "aws elbv2 create-load-balancer --name $ALB_NAME --subnets $SUBNET_PUBLIC_A_ID $SUBNET_PUBLIC_B_ID --security-groups $ALB_SG_ID --scheme internet-facing --type application"
        exit 1
    fi
fi

# ALB DNS 이름 가져오기
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].DNSName' \
    --output text --no-cli-pager)

echo -e "${GREEN}📍 ALB DNS: $ALB_DNS${NC}"

# Target Group 존재 확인
echo "Target Group 확인 중..."
if aws elbv2 describe-target-groups --names $TG_NAME --no-cli-pager >/dev/null 2>&1; then
    TG_ARN=$(aws elbv2 describe-target-groups --names $TG_NAME --query 'TargetGroups[0].TargetGroupArn' --output text --no-cli-pager)
    echo -e "${GREEN}✅ Target Group이 이미 존재합니다: $TG_ARN${NC}"
else
    echo "Target Group 생성 중..."
    echo "  - 이름: $TG_NAME"
    echo "  - VPC: $VPC_ID"
    echo "  - 포트: 8081"
    echo "  - Health Check: /health"
    
    TG_ARN=$(aws elbv2 create-target-group \
        --name $TG_NAME \
        --protocol HTTP \
        --port 8081 \
        --vpc-id $VPC_ID \
        --target-type ip \
        --health-check-enabled \
        --health-check-path /health \
        --health-check-protocol HTTP \
        --health-check-port 8081 \
        --health-check-interval-seconds 30 \
        --health-check-timeout-seconds 5 \
        --healthy-threshold-count 2 \
        --unhealthy-threshold-count 3 \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text --no-cli-pager)
    
    if [ $? -eq 0 ] && [ "$TG_ARN" != "None" ] && [ "$TG_ARN" != "" ]; then
        echo -e "${GREEN}✅ Target Group 생성 완료: $TG_ARN${NC}"
    else
        echo -e "${RED}❌ Target Group 생성 실패${NC}"
        exit 1
    fi
fi

# HTTPS 리스너 존재 확인
HTTPS_LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn $ALB_ARN \
    --query 'Listeners[?Port==`443`].ListenerArn' \
    --output text --no-cli-pager 2>/dev/null)

if [ "$HTTPS_LISTENER_ARN" != "" ] && [ "$HTTPS_LISTENER_ARN" != "None" ]; then
    echo -e "${GREEN}✅ HTTPS 리스너가 이미 존재합니다: $HTTPS_LISTENER_ARN${NC}"
else
    echo "HTTPS 리스너 생성 중..."
    HTTPS_LISTENER_ARN=$(aws elbv2 create-listener \
        --load-balancer-arn $ALB_ARN \
        --protocol HTTPS \
        --port 443 \
        --certificates CertificateArn=$CERT_ARN \
        --default-actions Type=forward,TargetGroupArn=$TG_ARN \
        --query 'Listeners[0].ListenerArn' \
        --output text --no-cli-pager)
    echo -e "${GREEN}✅ HTTPS 리스너 생성 완료: $HTTPS_LISTENER_ARN${NC}"
fi

# HTTP 리스너 (HTTPS로 리다이렉트) 존재 확인
HTTP_LISTENER_ARN=$(aws elbv2 describe-listeners \
    --load-balancer-arn $ALB_ARN \
    --query 'Listeners[?Port==`80`].ListenerArn' \
    --output text --no-cli-pager 2>/dev/null)

if [ "$HTTP_LISTENER_ARN" != "" ] && [ "$HTTP_LISTENER_ARN" != "None" ]; then
    echo -e "${GREEN}✅ HTTP 리스너가 이미 존재합니다: $HTTP_LISTENER_ARN${NC}"
else
    echo "HTTP 리스너 생성 중 (HTTPS 리다이렉트)..."
    HTTP_LISTENER_ARN=$(aws elbv2 create-listener \
        --load-balancer-arn $ALB_ARN \
        --protocol HTTP \
        --port 80 \
        --default-actions Type=redirect,RedirectConfig='{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}' \
        --query 'Listeners[0].ListenerArn' \
        --output text --no-cli-pager)
    echo -e "${GREEN}✅ HTTP 리스너 생성 완료: $HTTP_LISTENER_ARN${NC}"
fi

# 환경변수 파일에 ALB 정보 추가
echo "ALB_ARN=$ALB_ARN" >> deployment/env.sh
echo "ALB_DNS=$ALB_DNS" >> deployment/env.sh
echo "TG_ARN=$TG_ARN" >> deployment/env.sh

echo -e "${GREEN}🎉 Application Load Balancer 설정 완료!${NC}"
echo -e "${YELLOW}📍 ALB DNS: https://$ALB_DNS${NC}"