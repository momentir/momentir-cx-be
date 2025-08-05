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

# REGION 변수가 설정되지 않았으면 기본값 설정
if [ -z "$REGION" ]; then
    REGION="ap-northeast-2"
    echo "REGION=$REGION" >> deployment/env.sh
fi

echo -e "${YELLOW}🔐 AWS Systems Manager Parameter Store 설정 시작${NC}"

# .env 파일에서 환경변수 읽기
if [ ! -f ".env" ]; then
    echo -e "${RED}❌ .env 파일을 찾을 수 없습니다${NC}"
    exit 1
fi

# Parameter Store에 값 설정하는 함수
set_parameter() {
    local param_name=$1
    local param_value=$2
    local param_type=${3:-"SecureString"}
    
    if [ -z "$param_value" ]; then
        echo -e "${YELLOW}⚠️  $param_name 값이 비어있습니다. 건너뜀${NC}"
        return
    fi
    
    # 기존 파라미터 확인
    if aws ssm get-parameter --name "/momentir-cx-be/$param_name" --region $REGION --no-cli-pager > /dev/null 2>&1; then
        echo "파라미터 업데이트: $param_name"
        aws ssm put-parameter \
            --name "/momentir-cx-be/$param_name" \
            --value "$param_value" \
            --type "$param_type" \
            --overwrite \
            --region $REGION \
            --no-cli-pager > /dev/null
    else
        echo "파라미터 생성: $param_name"
        aws ssm put-parameter \
            --name "/momentir-cx-be/$param_name" \
            --value "$param_value" \
            --type "$param_type" \
            --region $REGION \
            --no-cli-pager > /dev/null
    fi
    
    echo -e "${GREEN}✅ $param_name 설정 완료${NC}"
}

# .env 파일에서 환경변수 로드 및 Parameter Store에 설정
echo "환경변수를 Parameter Store에 설정 중..."

# .env 파일 파싱
while IFS= read -r line || [[ -n "$line" ]]; do
    # 주석이나 빈 줄 건너뛰기
    [[ $line =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue
    
    # KEY=VALUE 형태 파싱
    if [[ $line == *"="* ]]; then
        key="${line%%=*}"
        value="${line#*=}"
        
        # 공백 제거
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        case $key in
            JWT_SECRET_KEY|DATABASE_PASSWORD|AWS_SES_SECRET_ACCESS_KEY)
                set_parameter "$key" "$value" "SecureString"
                ;;
            DATABASE_HOST|DATABASE_PORT|DATABASE_USERNAME|DATABASE_DEFAULT_SCHEMA|AWS_SES_ACCESS_KEY|AWS_SES_FROM_EMAIL)
                set_parameter "$key" "$value" "String"
                ;;
            *)
                echo -e "${YELLOW}⚠️  알 수 없는 환경변수: $key (건너뜀)${NC}"
                ;;
        esac
    fi
done < .env

# AWS_REGION도 추가
set_parameter "AWS_REGION" "$REGION" "String"

echo -e "${GREEN}🎉 AWS Systems Manager Parameter Store 설정 완료!${NC}"

# 설정된 파라미터 목록 표시
echo -e "${YELLOW}📋 설정된 파라미터 목록:${NC}"
aws ssm get-parameters-by-path \
    --path "/momentir-cx-be" \
    --region $REGION \
    --query 'Parameters[].Name' \
    --output table --no-cli-pager