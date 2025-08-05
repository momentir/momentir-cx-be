#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔍 환경변수 디버깅${NC}"

# deployment/env.sh 파일 확인
if [ -f "deployment/env.sh" ]; then
    echo -e "${GREEN}✅ deployment/env.sh 파일 존재${NC}"
    echo ""
    echo "=== deployment/env.sh 내용 ==="
    cat deployment/env.sh
    echo "=========================="
    echo ""
    
    # 환경변수 로드 및 확인
    source deployment/env.sh
    
    echo "=== 로드된 환경변수 확인 ==="
    echo "REGION: $REGION"
    echo "REPOSITORY_NAME: $REPOSITORY_NAME"
    echo "REPOSITORY_URI: $REPOSITORY_URI"
    echo "IMAGE_URI: $IMAGE_URI"
    echo "VPC_ID: $VPC_ID"
    echo "SUBNET_PUBLIC_A_ID: $SUBNET_PUBLIC_A_ID"
    echo "SUBNET_PUBLIC_B_ID: $SUBNET_PUBLIC_B_ID"
    echo "IGW_ID: $IGW_ID"
    echo "ALB_SG_ID: $ALB_SG_ID"
    echo "ECS_SG_ID: $ECS_SG_ID"
    echo "CERT_ARN: $CERT_ARN"
    echo "=========================="
    
    # 누락된 변수 확인
    echo ""
    echo "=== 누락된 변수 확인 ==="
    MISSING_VARS=""
    
    [ -z "$REGION" ] && MISSING_VARS="$MISSING_VARS REGION"
    [ -z "$VPC_ID" ] && MISSING_VARS="$MISSING_VARS VPC_ID"
    [ -z "$SUBNET_PUBLIC_A_ID" ] && MISSING_VARS="$MISSING_VARS SUBNET_PUBLIC_A_ID"
    [ -z "$SUBNET_PUBLIC_B_ID" ] && MISSING_VARS="$MISSING_VARS SUBNET_PUBLIC_B_ID"
    [ -z "$ALB_SG_ID" ] && MISSING_VARS="$MISSING_VARS ALB_SG_ID"
    [ -z "$ECS_SG_ID" ] && MISSING_VARS="$MISSING_VARS ECS_SG_ID"
    
    if [ -z "$MISSING_VARS" ]; then
        echo -e "${GREEN}✅ 모든 필수 변수가 설정되었습니다${NC}"
    else
        echo -e "${RED}❌ 누락된 변수: $MISSING_VARS${NC}"
        echo "이전 단계의 스크립트들을 다시 실행해주세요."
    fi
    
else
    echo -e "${RED}❌ deployment/env.sh 파일이 존재하지 않습니다${NC}"
    echo "먼저 01-create-ecr-repository.sh부터 실행해주세요."
fi

echo ""
echo -e "${YELLOW}🔍 AWS 리소스 상태 확인${NC}"

# VPC 확인
if [ ! -z "$VPC_ID" ]; then
    echo "VPC 상태 확인..."
    aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].{VpcId:VpcId,State:State,IsDefault:IsDefault}' --output table --no-cli-pager 2>/dev/null || echo "VPC 확인 실패"
fi

# 서브넷 확인  
if [ ! -z "$SUBNET_PUBLIC_A_ID" ] && [ ! -z "$SUBNET_PUBLIC_B_ID" ]; then
    echo "서브넷 상태 확인..."
    aws ec2 describe-subnets --subnet-ids $SUBNET_PUBLIC_A_ID $SUBNET_PUBLIC_B_ID --query 'Subnets[*].{SubnetId:SubnetId,State:State,AvailabilityZone:AvailabilityZone}' --output table --no-cli-pager 2>/dev/null || echo "서브넷 확인 실패"
fi

# 보안그룹 확인
if [ ! -z "$ALB_SG_ID" ]; then
    echo "ALB 보안그룹 상태 확인..."
    aws ec2 describe-security-groups --group-ids $ALB_SG_ID --query 'SecurityGroups[0].{GroupId:GroupId,GroupName:GroupName,VpcId:VpcId}' --output table --no-cli-pager 2>/dev/null || echo "ALB 보안그룹 확인 실패"
fi

echo ""
echo -e "${GREEN}🎉 디버깅 완료!${NC}"