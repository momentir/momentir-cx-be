# 🚀 MOMENTIR-CX-BE AWS 배포 빠른 시작 가이드

## 📋 배포 요약

이 프로젝트는 **AWS ECS Fargate**에 배포되며, 다음과 같은 구조로 구성됩니다:

```
Internet → Route53(api.momentir.com) → ALB(HTTPS) → ECS Fargate → PostgreSQL RDS
                                              ↓
                                        Default VPC
```

**주요 특징:**
- **Default VPC 사용**: 별도 VPC 생성 없이 기존 Default VPC 활용
- **비용 최적화**: 네트워크 리소스 생성 비용 절약  
- **간편한 설정**: 복잡한 네트워킹 설정 불필요

## ⚡ 빠른 배포 (3단계)

### 1단계: 사전 준비 확인
```bash
# AWS CLI 설치 및 구성 확인
aws sts get-caller-identity

# Docker 실행 확인
docker version

# 환경변수 파일 확인
cat .env
```

### 2단계: 전체 배포 실행
```bash
# 배포 스크립트 실행
bash deployment/deploy.sh
```

### 3단계: 배포 확인
```bash
# API 상태 확인
curl https://api.momentir.com/health

# Swagger 문서 확인
open https://api.momentir.com/docs
```

## 🔧 코드 변경 후 재배포

```bash
# 빠른 재배포 (코드 변경 후)
bash deployment/redeploy.sh
```

## 📊 주요 엔드포인트

배포 완료 후 다음 URL들을 사용할 수 있습니다:

- **API Base URL**: `https://api.momentir.com`
- **Health Check**: `https://api.momentir.com/health`
- **Swagger UI**: `https://api.momentir.com/docs`

### API 엔드포인트 목록
- `POST /v1/auth/login` - 사용자 로그인
- `POST /v1/auth/sign-up` - 사용자 회원가입
- `POST /v1/auth/request-email-verification` - 이메일 인증 요청
- `POST /v1/auth/verify-email-account` - 이메일 계정 인증
- `GET /v1/auth/find-my-email` - 이메일 찾기
- `POST /v1/auth/reset-password` - 비밀번호 재설정 요청
- `PUT /v1/auth/reset-password/password` - 비밀번호 재설정
- `POST /v1/auth/logout` - 로그아웃 (인증 필요)

## 🛠️ 필수 사전 준비사항

### AWS 설정
1. **AWS CLI** 설치 및 구성
2. **momentir.com ACM 인증서** 준비 (ap-northeast-2 리전)
3. **momentir.com Route53 Hosted Zone** 준비

### 환경변수 설정 (.env)
```env
JWT_SECRET_KEY=your-strong-jwt-secret
DATABASE_HOST=your-rds-endpoint
DATABASE_PORT=5432
DATABASE_USERNAME=your-db-user
DATABASE_PASSWORD=your-db-password
DATABASE_DEFAULT_SCHEMA=your-db-name
AWS_SES_ACCESS_KEY=your-ses-access-key
AWS_SES_SECRET_ACCESS_KEY=your-ses-secret-key
AWS_SES_FROM_EMAIL=verified-email@yourdomain.com
```

## 🗑️ 리소스 정리

모든 AWS 리소스를 삭제하려면:
```bash
bash deployment/cleanup.sh
```

## 📚 자세한 가이드

더 자세한 설정과 트러블슈팅은 `deployment/README.md`를 참조하세요.

## 🚨 주의사항

- **AWS 비용**: 프리티어 범위 내에서 구성되지만 사용량에 따라 요금이 발생할 수 있습니다
- **도메인 설정**: momentir.com 도메인과 ACM 인증서가 사전에 준비되어야 합니다
- **데이터베이스**: 기존 RDS PostgreSQL 인스턴스를 사용합니다
- **보안**: 환경변수는 AWS Systems Manager Parameter Store에 암호화되어 저장됩니다

## ✅ 배포 성공 체크리스트

- [ ] ECS 서비스가 `RUNNING` 상태
- [ ] ALB Health Check가 `healthy` 상태  
- [ ] `https://api.momentir.com/health` 응답 확인
- [ ] Swagger UI 접근 가능
- [ ] 로그인/회원가입 API 테스트 완료

---

🎉 **배포 완료!** 이제 `https://api.momentir.com`에서 인증 서비스를 사용할 수 있습니다.