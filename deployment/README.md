# 🚀 MOMENTIR-CX-BE AWS ECS 배포 가이드

이 가이드는 Go 기반 인증 서비스를 AWS ECS Fargate에 배포하는 방법을 설명합니다.

## 📋 배포 아키텍처

```
Internet → Route53 → ALB (HTTPS) → ECS Fargate → RDS PostgreSQL
                 ↓                      ↓
             ACM Certificate      Default VPC
```

### 주요 구성 요소
- **ECS Fargate**: 컨테이너 실행 환경
- **Application Load Balancer**: HTTPS 트래픽 처리
- **Route53**: DNS 관리 (`api.momentir.com`)
- **ACM**: SSL/TLS 인증서
- **Default VPC**: AWS 기본 네트워크 환경 (별도 생성 불필요)
- **ECR**: Docker 이미지 저장소
- **Systems Manager Parameter Store**: 환경변수 보안 저장

## 🛠️ 사전 준비사항

### 1. 필수 도구 설치
```bash
# AWS CLI v2
aws --version

# Docker
docker --version

# jq (JSON 처리용, 선택사항)
jq --version
```

### 2. AWS 자격 증명 설정
```bash
aws configure
# 또는
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
export AWS_DEFAULT_REGION=ap-northeast-2
```

### 3. momentir.com 도메인 준비
- **ACM 인증서**: `momentir.com`과 `*.momentir.com`에 대한 인증서 필요
- **Route53 Hosted Zone**: `momentir.com` 도메인의 Hosted Zone 필요

### 4. 환경변수 설정
`.env` 파일이 올바르게 설정되어 있는지 확인:
```env
JWT_SECRET_KEY=your-jwt-secret
DATABASE_HOST=your-db-host
DATABASE_PORT=5432
DATABASE_USERNAME=your-db-user
DATABASE_PASSWORD=your-db-password
DATABASE_DEFAULT_SCHEMA=your-db-name
AWS_SES_ACCESS_KEY=your-ses-key
AWS_SES_SECRET_ACCESS_KEY=your-ses-secret
AWS_SES_FROM_EMAIL=your-verified-email@domain.com
```

## 🚀 배포 실행

### 전체 배포 (처음 배포시)
```bash
# 실행 권한 부여
chmod +x deployment/deploy.sh

# 전체 배포 실행
bash deployment/deploy.sh
```

배포 프로세스:
1. ✅ ECR 리포지토리 생성
2. 🔨 Docker 이미지 빌드 및 푸시
3. 🌐 Default VPC 및 서브넷 확인
4. 🔐 보안 그룹 생성
5. 🔒 ACM 인증서 확인
6. ⚖️ Application Load Balancer 생성
7. 🚀 ECS 클러스터 생성
8. 🔐 환경변수를 Parameter Store에 저장
9. 📋 ECS 태스크 정의 생성
10. 🎯 ECS 서비스 생성
11. 🌍 Route53 DNS 레코드 생성

### 코드 변경 후 재배포
```bash
# 코드 변경 후 빠른 재배포
bash deployment/redeploy.sh
```

재배포 프로세스:
1. 🔨 새 Docker 이미지 빌드 및 푸시
2. 📋 ECS 태스크 정의 업데이트
3. 🔄 ECS 서비스 무중단 재배포

## 🔍 배포 확인

### 서비스 상태 확인
```bash
# ECS 서비스 상태
aws ecs describe-services --cluster momentir-cx-be --services momentir-cx-be

# ALB 상태
aws elbv2 describe-load-balancers --names momentir-cx-be-alb

# 태스크 로그 확인
aws logs tail /ecs/momentir-cx-be --follow
```

### 엔드포인트 테스트
```bash
# Health Check
curl https://api.momentir.com/health

# Swagger UI
open https://api.momentir.com/docs
```

## 📊 모니터링

### CloudWatch 로그
```bash
# 실시간 로그 확인
aws logs tail /ecs/momentir-cx-be --follow

# 특정 시간대 로그
aws logs filter-log-events \
  --log-group-name /ecs/momentir-cx-be \
  --start-time $(date -d '1 hour ago' +%s)000
```

### 서비스 메트릭
- CloudWatch에서 ECS 서비스 메트릭 확인
- ALB 타겟 그룹 상태 모니터링
- 애플리케이션 응답 시간 및 에러율 추적

## 🔧 유지보수

### 환경변수 업데이트
```bash
# Parameter Store에서 직접 수정
aws ssm put-parameter \
  --name "/momentir-cx-be/JWT_SECRET_KEY" \
  --value "new-secret-key" \
  --type SecureString \
  --overwrite

# 서비스 재시작 (새 환경변수 적용)
aws ecs update-service \
  --cluster momentir-cx-be \
  --service momentir-cx-be \
  --force-new-deployment
```

### 스케일링
```bash
# 수동 스케일링
aws ecs update-service \
  --cluster momentir-cx-be \
  --service momentir-cx-be \
  --desired-count 2
```

### 데이터베이스 마이그레이션
```bash
# 마이그레이션이 필요한 경우
# 1. SKIP_MIGRATION=false로 설정
# 2. 일시적으로 태스크 정의 업데이트
# 3. 마이그레이션 완료 후 다시 SKIP_MIGRATION=true로 설정
```

## 🗑️ 리소스 정리

### 전체 리소스 삭제
```bash
# 모든 AWS 리소스 삭제
bash deployment/cleanup.sh
```

⚠️ **주의**: 이 명령은 모든 관련 AWS 리소스를 삭제합니다.

### 개별 리소스 정리
```bash
# ECS 서비스만 중단
aws ecs update-service --cluster momentir-cx-be --service momentir-cx-be --desired-count 0
aws ecs delete-service --cluster momentir-cx-be --service momentir-cx-be --force

# ECR 이미지만 정리
aws ecr list-images --repository-name momentir-cx-be
aws ecr batch-delete-image --repository-name momentir-cx-be --image-ids imageTag=latest
```

## 🚨 트러블슈팅

### 일반적인 문제들

#### 1. ECS 태스크가 시작되지 않음
```bash
# 태스크 이벤트 확인
aws ecs describe-services --cluster momentir-cx-be --services momentir-cx-be \
  --query 'services[0].events[:5]'

# 태스크 로그 확인
aws logs filter-log-events --log-group-name /ecs/momentir-cx-be --limit 50
```

**일반적인 원인:**
- Parameter Store 권한 부족
- 컨테이너 이미지 문제
- 리소스 부족 (CPU/메모리)

#### 2. ALB Health Check 실패
```bash
# 타겟 그룹 Health 상태 확인
aws elbv2 describe-target-health --target-group-arn $TG_ARN
```

**해결 방법:**
- `/health` 엔드포인트 응답 확인
- 보안 그룹 규칙 확인
- 컨테이너 포트 설정 확인

#### 3. DNS 해상도 문제
```bash
# Route53 레코드 확인
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID \
  --query "ResourceRecordSets[?Name=='api.momentir.com.']"

# DNS 전파 확인
dig api.momentir.com
nslookup api.momentir.com
```

#### 4. SSL 인증서 문제
```bash
# ACM 인증서 상태 확인
aws acm describe-certificate --certificate-arn $CERT_ARN \
  --query 'Certificate.{Status:Status,DomainName:DomainName,ValidationRecords:DomainValidationOptions}'
```

### 로그 디버깅
```bash
# 애플리케이션 시작 로그
aws logs filter-log-events \
  --log-group-name /ecs/momentir-cx-be \
  --filter-pattern "ERROR"

# 특정 시간대 에러 로그
aws logs filter-log-events \
  --log-group-name /ecs/momentir-cx-be \
  --start-time $(date -d '1 hour ago' +%s)000 \
  --filter-pattern "level=error"
```

## 📞 지원

문제가 발생하면 다음 정보와 함께 문의하세요:
- 에러 메시지 및 로그
- 배포 단계 (어느 스크립트에서 실패했는지)
- AWS 리전 및 계정 정보
- 환경변수 설정 (민감한 정보 제외)

## 📚 추가 리소스

- [AWS ECS 문서](https://docs.aws.amazon.com/ecs/)
- [AWS ALB 문서](https://docs.aws.amazon.com/elasticloadbalancing/)
- [AWS Route53 문서](https://docs.aws.amazon.com/route53/)
- [AWS ACM 문서](https://docs.aws.amazon.com/acm/)