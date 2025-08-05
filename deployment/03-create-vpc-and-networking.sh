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

echo -e "${YELLOW}🌐 Default VPC 및 서브넷 확인 시작${NC}"

# Default VPC 가져오기
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query 'Vpcs[0].VpcId' --output text --no-cli-pager 2>/dev/null)

if [ "$VPC_ID" = "None" ] || [ "$VPC_ID" = "" ]; then
    echo -e "${RED}❌ Default VPC를 찾을 수 없습니다${NC}"
    echo "Default VPC를 생성하거나 기존 VPC를 사용하도록 스크립트를 수정해주세요."
    exit 1
fi

echo -e "${GREEN}✅ Default VPC 발견: $VPC_ID${NC}"

# Default VPC의 서브넷들 가져오기 (최소 2개 가용영역 필요)
SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" \
    --query 'Subnets[*].{SubnetId:SubnetId,AvailabilityZone:AvailabilityZone}' \
    --output text --no-cli-pager)

if [ -z "$SUBNETS" ]; then
    echo -e "${RED}❌ Default VPC에서 서브넷을 찾을 수 없습니다${NC}"
    exit 1
fi

# 서브넷 ID들을 배열로 변환
SUBNET_IDS=($(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=default-for-az,Values=true" \
    --query 'Subnets[*].SubnetId' \
    --output text --no-cli-pager))

if [ ${#SUBNET_IDS[@]} -lt 2 ]; then
    echo -e "${RED}❌ ALB를 위해서는 최소 2개의 가용영역이 필요합니다${NC}"
    echo "현재 발견된 서브넷 수: ${#SUBNET_IDS[@]}"
    exit 1
fi

SUBNET_PUBLIC_A_ID=${SUBNET_IDS[0]}
SUBNET_PUBLIC_B_ID=${SUBNET_IDS[1]}

echo -e "${GREEN}✅ 사용할 서브넷들:${NC}"
echo "  - Subnet A: $SUBNET_PUBLIC_A_ID"
echo "  - Subnet B: $SUBNET_PUBLIC_B_ID"

# 가용영역 정보 표시
echo "서브넷 정보:"
aws ec2 describe-subnets \
    --subnet-ids $SUBNET_PUBLIC_A_ID $SUBNET_PUBLIC_B_ID \
    --query 'Subnets[*].{SubnetId:SubnetId,AvailabilityZone:AvailabilityZone,CidrBlock:CidrBlock}' \
    --output table --no-cli-pager

# Internet Gateway 확인 (Default VPC는 이미 IGW가 연결되어 있음)
IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text --no-cli-pager)

if [ "$IGW_ID" = "None" ] || [ "$IGW_ID" = "" ]; then
    echo -e "${RED}❌ Default VPC에 Internet Gateway가 연결되어 있지 않습니다${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Internet Gateway 확인: $IGW_ID${NC}"

# 환경변수 파일에 네트워킹 정보 추가
echo "VPC_ID=$VPC_ID" >> deployment/env.sh
echo "SUBNET_PUBLIC_A_ID=$SUBNET_PUBLIC_A_ID" >> deployment/env.sh
echo "SUBNET_PUBLIC_B_ID=$SUBNET_PUBLIC_B_ID" >> deployment/env.sh
echo "IGW_ID=$IGW_ID" >> deployment/env.sh

echo -e "${GREEN}🎉 Default VPC 네트워킹 설정 완료!${NC}"
echo -e "${YELLOW}📝 참고: Default VPC를 사용하므로 별도의 네트워크 리소스 생성이 불필요합니다${NC}"