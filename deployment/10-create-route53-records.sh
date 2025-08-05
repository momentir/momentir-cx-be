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

echo -e "${YELLOW}🌐 Route53 레코드 생성 시작${NC}"

DOMAIN_NAME="momentir.com"
API_SUBDOMAIN="api.momentir.com"

# Route53 Hosted Zone 찾기
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones \
    --query "HostedZones[?Name=='${DOMAIN_NAME}.'].Id" \
    --output text --no-cli-pager | cut -d'/' -f3)

if [ "$HOSTED_ZONE_ID" = "" ] || [ "$HOSTED_ZONE_ID" = "None" ]; then
    echo -e "${RED}❌ ${DOMAIN_NAME}의 Route53 Hosted Zone을 찾을 수 없습니다${NC}"
    echo "다음 중 하나를 수행해야 합니다:"
    echo "1. AWS Console에서 ${DOMAIN_NAME} 도메인의 Hosted Zone을 생성"
    echo "2. 도메인 등록업체에서 네임서버를 AWS Route53으로 변경"
    exit 1
fi

echo -e "${GREEN}✅ Hosted Zone 발견: $HOSTED_ZONE_ID${NC}"

# ALB 정보 가져오기
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns $ALB_ARN \
    --query 'LoadBalancers[0].CanonicalHostedZoneId' \
    --output text --no-cli-pager)

echo "ALB Zone ID: $ALB_ZONE_ID"
echo "ALB DNS: $ALB_DNS"

# Change Batch JSON 생성
cat > /tmp/route53-changeset.json << EOF
{
  "Comment": "Create A record for $API_SUBDOMAIN pointing to ALB",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$API_SUBDOMAIN",
        "Type": "A",
        "AliasTarget": {
          "DNSName": "$ALB_DNS",
          "EvaluateTargetHealth": true,
          "HostedZoneId": "$ALB_ZONE_ID"
        }
      }
    }
  ]
}
EOF

# Route53 레코드 생성/업데이트
echo "Route53 A 레코드 생성/업데이트 중: $API_SUBDOMAIN -> $ALB_DNS"
CHANGE_ID=$(aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch file:///tmp/route53-changeset.json \
    --query 'ChangeInfo.Id' \
    --output text --no-cli-pager)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Route53 레코드 생성/업데이트 요청 완료${NC}"
    echo "Change ID: $CHANGE_ID"
    
    # 변경 사항 전파 대기
    echo "DNS 전파 대기 중... (최대 5분)"
    aws route53 wait resource-record-sets-changed --id $CHANGE_ID
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ DNS 전파 완료${NC}"
    else
        echo -e "${YELLOW}⚠️  DNS 전파 대기 시간이 초과되었습니다. 수동으로 확인해주세요.${NC}"
    fi
else
    echo -e "${RED}❌ Route53 레코드 생성/업데이트 실패${NC}"
    exit 1
fi

# 정리
rm -f /tmp/route53-changeset.json

# DNS 레코드 확인
echo "생성된 DNS 레코드 확인:"
aws route53 list-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --query "ResourceRecordSets[?Name=='${API_SUBDOMAIN}.']" \
    --output table --no-cli-pager

# 환경변수 파일에 DNS 정보 추가
echo "HOSTED_ZONE_ID=$HOSTED_ZONE_ID" >> deployment/env.sh
echo "API_SUBDOMAIN=$API_SUBDOMAIN" >> deployment/env.sh

echo -e "${GREEN}🎉 Route53 레코드 설정 완료!${NC}"
echo -e "${GREEN}🌍 API 엔드포인트: https://$API_SUBDOMAIN${NC}"
echo -e "${GREEN}📖 Swagger 문서: https://$API_SUBDOMAIN/docs${NC}"
echo -e "${YELLOW}⏰ DNS 전파까지 최대 몇 분이 소요될 수 있습니다${NC}"