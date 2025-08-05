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

echo -e "${YELLOW}🔒 ACM 인증서 확인 시작${NC}"

DOMAIN_NAME="momentir.com"
WILDCARD_DOMAIN="*.momentir.com"

# 기존 인증서 찾기
echo "momentir.com 도메인 인증서 검색 중..."

# momentir.com 인증서 찾기
CERT_ARN=$(aws acm list-certificates \
    --region $REGION \
    --query "CertificateSummaryList[?DomainName=='$DOMAIN_NAME' || DomainName=='$WILDCARD_DOMAIN'].CertificateArn" \
    --output text --no-cli-pager | head -1)

if [ "$CERT_ARN" != "" ] && [ "$CERT_ARN" != "None" ]; then
    echo -e "${GREEN}✅ 기존 ACM 인증서 발견: $CERT_ARN${NC}"
    
    # 인증서 상태 확인
    CERT_STATUS=$(aws acm describe-certificate \
        --certificate-arn $CERT_ARN \
        --region $REGION \
        --query 'Certificate.Status' \
        --output text --no-cli-pager)
    
    echo "인증서 상태: $CERT_STATUS"
    
    if [ "$CERT_STATUS" = "ISSUED" ]; then
        echo -e "${GREEN}✅ 인증서가 발급되어 사용 가능합니다${NC}"
        
        # 인증서 도메인 정보 표시
        echo "인증서 도메인 정보:"
        aws acm describe-certificate \
            --certificate-arn $CERT_ARN \
            --region $REGION \
            --query 'Certificate.{DomainName:DomainName,SubjectAlternativeNames:SubjectAlternativeNames}' \
            --output table --no-cli-pager
    else
        echo -e "${RED}⚠️  인증서 상태가 ISSUED가 아닙니다: $CERT_STATUS${NC}"
        echo "인증서가 검증 대기 중이거나 문제가 있을 수 있습니다."
    fi
else
    echo -e "${RED}❌ momentir.com 도메인에 대한 ACM 인증서를 찾을 수 없습니다${NC}"
    echo "다음 중 하나를 수행해야 합니다:"
    echo "1. AWS Console에서 momentir.com 도메인에 대한 ACM 인증서를 수동으로 요청"
    echo "2. 또는 아래 명령어로 인증서 요청 (DNS 검증 필요):"
    echo ""
    echo "aws acm request-certificate \\"
    echo "    --domain-name momentir.com \\"
    echo "    --subject-alternative-names *.momentir.com \\"
    echo "    --validation-method DNS \\"
    echo "    --region $REGION"
    exit 1
fi

# 환경변수 파일에 인증서 ARN 추가
echo "CERT_ARN=$CERT_ARN" >> deployment/env.sh

echo -e "${GREEN}🎉 ACM 인증서 확인 완료!${NC}"