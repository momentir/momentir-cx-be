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

echo -e "${YELLOW}📋 ECS 태스크 정의 생성 시작${NC}"

FAMILY_NAME="momentir-cx-be"

# IAM 실행 역할 생성 (ECS 태스크용)
EXECUTION_ROLE_NAME="ecsTaskExecutionRole-momentir-cx-be"
EXECUTION_ROLE_ARN=""

# IAM 태스크 역할 생성 (애플리케이션용)
TASK_ROLE_NAME="ecsTaskRole-momentir-cx-be"
TASK_ROLE_ARN=""

# 기존 역할 확인
echo "ECS 실행 역할 확인 중: $EXECUTION_ROLE_NAME"
EXISTING_ROLE=$(aws iam get-role --role-name $EXECUTION_ROLE_NAME --query 'Role.Arn' --output text --no-cli-pager 2>/dev/null || echo "NOT_FOUND")

if [ "$EXISTING_ROLE" != "" ] && [ "$EXISTING_ROLE" != "None" ] && [ "$EXISTING_ROLE" != "NOT_FOUND" ]; then
    echo -e "${GREEN}✅ ECS 실행 역할이 이미 존재합니다: $EXISTING_ROLE${NC}"
    EXECUTION_ROLE_ARN=$EXISTING_ROLE
else
    echo "ECS 실행 역할 생성 중..."
    
    # Trust Policy 생성
    cat > /tmp/ecs-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # 역할 생성
    EXECUTION_ROLE_ARN=$(aws iam create-role \
        --role-name $EXECUTION_ROLE_NAME \
        --assume-role-policy-document file:///tmp/ecs-trust-policy.json \
        --query 'Role.Arn' \
        --output text --no-cli-pager)
    
    # 관리형 정책 연결
    aws iam attach-role-policy \
        --role-name $EXECUTION_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy \
        --no-cli-pager
    
    echo -e "${GREEN}✅ ECS 실행 역할 생성 완료: $EXECUTION_ROLE_ARN${NC}"
    
    # 정리
    rm -f /tmp/ecs-trust-policy.json
fi

# 기존 태스크 역할 확인
echo "ECS 태스크 역할 확인 중: $TASK_ROLE_NAME"
EXISTING_TASK_ROLE=$(aws iam get-role --role-name $TASK_ROLE_NAME --query 'Role.Arn' --output text --no-cli-pager 2>/dev/null || echo "NOT_FOUND")

if [ "$EXISTING_TASK_ROLE" != "" ] && [ "$EXISTING_TASK_ROLE" != "None" ] && [ "$EXISTING_TASK_ROLE" != "NOT_FOUND" ]; then
    echo -e "${GREEN}✅ ECS 태스크 역할이 이미 존재합니다: $EXISTING_TASK_ROLE${NC}"
    TASK_ROLE_ARN=$EXISTING_TASK_ROLE
else
    echo "ECS 태스크 역할 생성 중..."
    
    # Trust Policy 생성 (동일한 파일 재사용)
    cat > /tmp/ecs-trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    # 태스크 역할 생성
    TASK_ROLE_ARN=$(aws iam create-role \
        --role-name $TASK_ROLE_NAME \
        --assume-role-policy-document file:///tmp/ecs-trust-policy.json \
        --query 'Role.Arn' \
        --output text --no-cli-pager)
    
    # SSM 파라미터 접근을 위한 정책 연결
    aws iam attach-role-policy \
        --role-name $TASK_ROLE_NAME \
        --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess \
        --no-cli-pager
    
    echo -e "${GREEN}✅ ECS 태스크 역할 생성 완료: $TASK_ROLE_ARN${NC}"
    
    # 정리
    rm -f /tmp/ecs-trust-policy.json
fi

# 태스크 정의 JSON 생성
cat > /tmp/task-definition.json << EOF
{
  "family": "$FAMILY_NAME",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "$EXECUTION_ROLE_ARN",
  "taskRoleArn": "$TASK_ROLE_ARN",
  "containerDefinitions": [
    {
      "name": "$FAMILY_NAME",
      "image": "$IMAGE_URI",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8081,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "GIN_MODE",
          "value": "release"
        },
        {
          "name": "SKIP_MIGRATION",
          "value": "true"
        },
        {
          "name": "SERVER_PORT",
          "value": "8081"
        }
      ],
      "secrets": [
        {
          "name": "JWT_SECRET_KEY",
          "valueFrom": "arn:aws:ssm:$REGION:$(aws sts get-caller-identity --query Account --output text):parameter/momentir-cx-be/JWT_SECRET_KEY"
        },
        {
          "name": "DATABASE_HOST",
          "valueFrom": "arn:aws:ssm:$REGION:$(aws sts get-caller-identity --query Account --output text):parameter/momentir-cx-be/DATABASE_HOST"
        },
        {
          "name": "DATABASE_PORT",
          "valueFrom": "arn:aws:ssm:$REGION:$(aws sts get-caller-identity --query Account --output text):parameter/momentir-cx-be/DATABASE_PORT"
        },
        {
          "name": "DATABASE_USERNAME",
          "valueFrom": "arn:aws:ssm:$REGION:$(aws sts get-caller-identity --query Account --output text):parameter/momentir-cx-be/DATABASE_USERNAME"
        },
        {
          "name": "DATABASE_PASSWORD",
          "valueFrom": "arn:aws:ssm:$REGION:$(aws sts get-caller-identity --query Account --output text):parameter/momentir-cx-be/DATABASE_PASSWORD"
        },
        {
          "name": "DATABASE_DEFAULT_SCHEMA",
          "valueFrom": "arn:aws:ssm:$REGION:$(aws sts get-caller-identity --query Account --output text):parameter/momentir-cx-be/DATABASE_DEFAULT_SCHEMA"
        },
        {
          "name": "AWS_SES_ACCESS_KEY",
          "valueFrom": "arn:aws:ssm:$REGION:$(aws sts get-caller-identity --query Account --output text):parameter/momentir-cx-be/AWS_SES_ACCESS_KEY"
        },
        {
          "name": "AWS_SES_SECRET_ACCESS_KEY",
          "valueFrom": "arn:aws:ssm:$REGION:$(aws sts get-caller-identity --query Account --output text):parameter/momentir-cx-be/AWS_SES_SECRET_ACCESS_KEY"
        },
        {
          "name": "AWS_SES_FROM_EMAIL",
          "valueFrom": "arn:aws:ssm:$REGION:$(aws sts get-caller-identity --query Account --output text):parameter/momentir-cx-be/AWS_SES_FROM_EMAIL"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/$FAMILY_NAME",
          "awslogs-region": "$REGION",
          "awslogs-stream-prefix": "ecs",
          "awslogs-create-group": "true"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:8081/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

# 태스크 정의 등록
echo "ECS 태스크 정의 등록 중..."
TASK_DEF_ARN=$(aws ecs register-task-definition \
    --cli-input-json file:///tmp/task-definition.json \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text --no-cli-pager)

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ ECS 태스크 정의 등록 완료: $TASK_DEF_ARN${NC}"
else
    echo -e "${RED}❌ ECS 태스크 정의 등록 실패${NC}"
    exit 1
fi

# 정리
rm -f /tmp/task-definition.json

# 환경변수 파일에 태스크 정의 정보 추가
echo "FAMILY_NAME=$FAMILY_NAME" >> deployment/env.sh
echo "TASK_DEF_ARN=$TASK_DEF_ARN" >> deployment/env.sh
echo "EXECUTION_ROLE_ARN=$EXECUTION_ROLE_ARN" >> deployment/env.sh
echo "TASK_ROLE_ARN=$TASK_ROLE_ARN" >> deployment/env.sh

echo -e "${GREEN}🎉 ECS 태스크 정의 생성 완료!${NC}"
echo -e "${YELLOW}⚠️  주의: AWS Systems Manager Parameter Store에 환경변수를 설정해야 합니다:${NC}"
echo "- /momentir-cx-be/JWT_SECRET_KEY"
echo "- /momentir-cx-be/DATABASE_HOST"
echo "- /momentir-cx-be/DATABASE_PORT"
echo "- /momentir-cx-be/DATABASE_USERNAME"
echo "- /momentir-cx-be/DATABASE_PASSWORD"
echo "- /momentir-cx-be/DATABASE_DEFAULT_SCHEMA"
echo "- /momentir-cx-be/AWS_SES_ACCESS_KEY"
echo "- /momentir-cx-be/AWS_SES_SECRET_ACCESS_KEY"
echo "- /momentir-cx-be/AWS_SES_FROM_EMAIL"