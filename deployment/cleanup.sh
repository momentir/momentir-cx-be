#!/bin/bash

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 환경변수 파일 확인
if [ ! -f "deployment/env.sh" ]; then
    echo -e "${RED}❌ deployment/env.sh 파일을 찾을 수 없습니다${NC}"
    echo "배포된 리소스가 없거나 이미 정리되었을 수 있습니다."
    exit 1
fi

# 환경변수 로드 (파일이 없으면 스킵)
if [ -f "deployment/env.sh" ]; then
    source deployment/env.sh
else
    echo -e "${RED}❌ deployment/env.sh 파일을 찾을 수 없습니다${NC}"
    echo "배포된 리소스가 없거나 이미 정리되었을 수 있습니다."
    exit 1
fi

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   🗑️  리소스 정리                            ║"
echo "║                (모든 AWS 리소스 삭제)                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${RED}⚠️  주의: 다음 리소스들이 삭제됩니다:${NC}"
echo "• ECS 서비스 및 태스크"
echo "• ECS 클러스터"
echo "• Application Load Balancer"
echo "• Target Group"
echo "• 보안 그룹"
echo "• VPC 및 서브넷"
echo "• ECR 리포지토리 (이미지 포함)"
echo "• Route53 레코드"
echo "• IAM 역할"
echo "• SSM Parameter Store 파라미터"
echo ""

read -p "정말로 모든 리소스를 삭제하시겠습니까? (yes/NO): " -r
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo -e "${YELLOW}⏸️  리소스 정리를 중단합니다${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}🗑️  리소스 정리를 시작합니다...${NC}"
echo ""

# 1. ECS 서비스 삭제
if [ ! -z "$SERVICE_NAME" ] && [ ! -z "$CLUSTER_NAME" ]; then
    echo "ECS 서비스 삭제 중: $SERVICE_NAME"
    
    # 서비스 스케일 다운
    aws ecs update-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --desired-count 0 \
        --no-cli-pager > /dev/null 2>&1 || true
    
    # 태스크 중지 대기
    sleep 30
    
    # 서비스 삭제
    aws ecs delete-service \
        --cluster $CLUSTER_NAME \
        --service $SERVICE_NAME \
        --force \
        --no-cli-pager > /dev/null 2>&1 || true
    
    echo -e "${GREEN}✅ ECS 서비스 삭제 완료${NC}"
fi

# 2. ECS 클러스터 삭제
if [ ! -z "$CLUSTER_NAME" ]; then
    echo "ECS 클러스터 삭제 중: $CLUSTER_NAME"
    aws ecs delete-cluster \
        --cluster $CLUSTER_NAME \
        --no-cli-pager > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ ECS 클러스터 삭제 완료${NC}"
fi

# 3. ALB 삭제
if [ ! -z "$ALB_ARN" ]; then
    echo "Application Load Balancer 삭제 중"
    aws elbv2 delete-load-balancer \
        --load-balancer-arn $ALB_ARN \
        --no-cli-pager > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ ALB 삭제 완료${NC}"
fi

# 4. Target Group 삭제
if [ ! -z "$TG_ARN" ]; then
    echo "Target Group 삭제 중"
    sleep 10  # ALB 삭제 후 잠시 대기
    aws elbv2 delete-target-group \
        --target-group-arn $TG_ARN \
        --no-cli-pager > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ Target Group 삭제 완료${NC}"
fi

# 5. Route53 레코드 삭제
if [ ! -z "$HOSTED_ZONE_ID" ] && [ ! -z "$API_SUBDOMAIN" ] && [ ! -z "$ALB_DNS" ]; then
    echo "Route53 레코드 삭제 중: $API_SUBDOMAIN"
    
    # ALB Zone ID 다시 가져오기 (ALB가 삭제되었을 수 있음)
    ALB_ZONE_ID_FOR_DELETE="Z3AADJGX6KTTL2"  # ap-northeast-2 ALB 기본 Zone ID
    
    cat > /tmp/route53-delete.json << EOF
{
  "Comment": "Delete A record for $API_SUBDOMAIN",
  "Changes": [
    {
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "$API_SUBDOMAIN",
        "Type": "A",
        "AliasTarget": {
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true,
          "HostedZoneId": "$ALB_ZONE_ID_FOR_DELETE"
        }
      }
    }
  ]
}
EOF
    
    aws route53 change-resource-record-sets \
        --hosted-zone-id $HOSTED_ZONE_ID \
        --change-batch file:///tmp/route53-delete.json \
        --no-cli-pager > /dev/null 2>&1 || true
    
    rm -f /tmp/route53-delete.json
    echo -e "${GREEN}✅ Route53 레코드 삭제 완료${NC}"
fi

# 6. 보안 그룹 삭제
sleep 30  # 다른 리소스들이 삭제될 때까지 대기

if [ ! -z "$ECS_SG_ID" ]; then
    echo "ECS 보안 그룹 삭제 중"
    aws ec2 delete-security-group \
        --group-id $ECS_SG_ID \
        --no-cli-pager > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ ECS 보안 그룹 삭제 완료${NC}"
fi

if [ ! -z "$ALB_SG_ID" ]; then
    echo "ALB 보안 그룹 삭제 중"
    aws ec2 delete-security-group \
        --group-id $ALB_SG_ID \
        --no-cli-pager > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ ALB 보안 그룹 삭제 완료${NC}"
fi

# 7. 네트워크 리소스 확인 (Default VPC 사용으로 삭제 안함)
if [ ! -z "$VPC_ID" ]; then
    echo -e "${YELLOW}🌐 네트워크 리소스 확인${NC}"
    
    # Default VPC 확인
    IS_DEFAULT=$(aws ec2 describe-vpcs \
        --vpc-ids $VPC_ID \
        --query 'Vpcs[0].IsDefault' \
        --output text --no-cli-pager 2>/dev/null || echo "false")
    
    if [ "$IS_DEFAULT" = "true" ]; then
        echo -e "${YELLOW}📝 Default VPC를 사용하므로 VPC 관련 리소스는 삭제하지 않습니다${NC}"
        echo "  - VPC ID: $VPC_ID (Default VPC)"
        echo "  - Internet Gateway: $IGW_ID (유지)"
        echo "  - Subnets: $SUBNET_PUBLIC_A_ID, $SUBNET_PUBLIC_B_ID (유지)"
    else
        echo -e "${YELLOW}⚠️  사용자 정의 VPC가 감지되었습니다. 수동으로 확인 후 삭제해주세요${NC}"
        echo "  - VPC ID: $VPC_ID"
    fi
    
    echo -e "${GREEN}✅ 네트워크 리소스 확인 완료${NC}"
fi

# 8. ECR 리포지토리 삭제
if [ ! -z "$REPOSITORY_NAME" ]; then
    echo "ECR 리포지토리 삭제 중: $REPOSITORY_NAME"
    aws ecr delete-repository \
        --repository-name $REPOSITORY_NAME \
        --force \
        --region $REGION \
        --no-cli-pager > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ ECR 리포지토리 삭제 완료${NC}"
fi

# 9. IAM 역할 삭제
if [ ! -z "$EXECUTION_ROLE_ARN" ]; then
    ROLE_NAME=$(echo $EXECUTION_ROLE_ARN | cut -d'/' -f2)
    echo "IAM 역할 삭제 중: $ROLE_NAME"
    
    # 정책 분리
    aws iam detach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
        --no-cli-pager > /dev/null 2>&1 || true
    
    # 역할 삭제
    aws iam delete-role \
        --role-name $ROLE_NAME \
        --no-cli-pager > /dev/null 2>&1 || true
    
    echo -e "${GREEN}✅ IAM 역할 삭제 완료${NC}"
fi

# 10. SSM Parameter Store 파라미터 삭제
echo "SSM Parameter Store 파라미터 삭제 중"
PARAMETERS=$(aws ssm get-parameters-by-path \
    --path "/momentir-cx-be" \
    --region $REGION \
    --query 'Parameters[].Name' \
    --output text --no-cli-pager 2>/dev/null || true)

for PARAM in $PARAMETERS; do
    aws ssm delete-parameter \
        --name "$PARAM" \
        --region $REGION \
        --no-cli-pager > /dev/null 2>&1 || true
done

if [ ! -z "$PARAMETERS" ]; then
    echo -e "${GREEN}✅ SSM Parameter Store 파라미터 삭제 완료${NC}"
fi

# 11. CloudWatch Log Group 삭제
if [ ! -z "$FAMILY_NAME" ]; then
    echo "CloudWatch Log Group 삭제 중"
    aws logs delete-log-group \
        --log-group-name "/ecs/$FAMILY_NAME" \
        --region $REGION \
        --no-cli-pager > /dev/null 2>&1 || true
    echo -e "${GREEN}✅ CloudWatch Log Group 삭제 완료${NC}"
fi

# 12. 환경변수 파일 삭제
rm -f deployment/env.sh

echo ""
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                   🎉 정리 완료!                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${GREEN}✅ 모든 AWS 리소스가 성공적으로 삭제되었습니다${NC}"
echo -e "${YELLOW}📝 참고: ACM 인증서와 Route53 Hosted Zone은 수동으로 삭제하지 않았습니다${NC}"
echo -e "${YELLOW}   이 리소스들은 다른 서비스에서 사용될 수 있으므로 필요시 수동으로 삭제해주세요${NC}"