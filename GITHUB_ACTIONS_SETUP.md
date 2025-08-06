# GitHub Actions 설정 가이드

이 문서는 GitHub Actions를 통한 자동 배포를 설정하는 방법을 설명합니다.

## 필요한 GitHub Secrets 설정

GitHub 리포지토리 설정에서 다음 secrets을 추가해야 합니다:

### AWS 인증 정보
```
AWS_ACCESS_KEY_ID=your_aws_access_key_id
AWS_SECRET_ACCESS_KEY=your_aws_secret_access_key
```

### AWS 인증 정보 생성 방법

1. **IAM 사용자 생성**
   ```bash
   # AWS CLI를 통해 배포용 IAM 사용자 생성
   aws iam create-user --user-name github-actions-deployer
   ```

2. **필요한 정책 연결**
   ```bash
   # ECR 권한
   aws iam attach-user-policy --user-name github-actions-deployer \
     --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
   
   # ECS 권한
   aws iam attach-user-policy --user-name github-actions-deployer \
     --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
   
   # SSM 파라미터 접근 권한 (선택사항)
   aws iam attach-user-policy --user-name github-actions-deployer \
     --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess
   ```

3. **액세스 키 생성**
   ```bash
   aws iam create-access-key --user-name github-actions-deployer
   ```

## 현재 프로젝트 설정 정보

### 배포 환경 변수
- **AWS Region**: `ap-northeast-2`
- **ECR Repository**: `momentir-cx-be`
- **ECS Cluster**: `momentir-cx-be`
- **ECS Service**: `momentir-cx-be`
- **Container Name**: `momentir-cx-be`

### 배포된 엔드포인트
- **API Base URL**: https://api.momentir.com
- **Health Check**: https://api.momentir.com/health
- **Swagger Documentation**: https://api.momentir.com/docs

## 워크플로우 동작 방식

### 1. 테스트 단계 (모든 브랜치)
- Go 모듈 다운로드 및 캐싱
- 코드 빌드
- 단위 테스트 실행 (활성화 시)
- `go vet` 정적 분석

### 2. 배포 단계 (main 브랜치만)
- AWS 인증
- ECR 로그인
- Docker 이미지 빌드 (linux/amd64)
- ECR에 이미지 푸시
- ECS 태스크 정의 업데이트
- ECS 서비스 배포
- 배포 확인

## 테스트 설정

### 테스트 실행
```bash
# 로컬에서 테스트 실행
make test

# 커버리지 포함 테스트
make test-coverage
```

### 테스트 파일 추가
`internal/` 디렉토리의 각 패키지에 `*_test.go` 파일을 추가하여 테스트를 작성하세요.

예시: `internal/handlers/auth_handler_test.go`

## 로컬 개발

### 필요한 도구 설치
```bash
# 개발 도구 설치
make dev-setup

# 또는 수동으로:
go install github.com/swaggo/swag/cmd/swag@latest
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
```

### 로컬 빌드 및 실행
```bash
# 로컬 빌드
make build-local

# 로컬 실행
make run

# Docker 빌드 및 실행
make docker-build
make docker-run
```

### Swagger 문서 재생성
```bash
make swagger
```

## 트러블슈팅

### 1. ECR 권한 오류
- IAM 사용자에 ECR 권한이 있는지 확인
- ECR 리포지토리가 존재하는지 확인

### 2. ECS 배포 실패
- 태스크 정의의 IAM 역할이 올바른지 확인
- 보안 그룹 설정 확인
- CloudWatch 로그 확인

### 3. Docker 이미지 아키텍처 오류
- `--platform linux/amd64` 플래그가 설정되어 있는지 확인
- ECS Fargate는 AMD64 아키텍처만 지원

## 보안 고려사항

1. **최소 권한 원칙**: IAM 사용자에 필요한 최소한의 권한만 부여
2. **액세스 키 로테이션**: 정기적으로 액세스 키 교체
3. **환경 변수**: 민감한 정보는 모두 AWS SSM Parameter Store 사용
4. **VPC 보안**: 적절한 보안 그룹 및 네트워크 ACL 설정

## 모니터링

### CloudWatch 로그 확인
```bash
# ECS 태스크 로그 확인
aws logs describe-log-groups --log-group-name-prefix "/ecs/momentir-cx-be"

# 로그 스트림 확인
aws logs describe-log-streams --log-group-name "/ecs/momentir-cx-be"
```

### ECS 서비스 상태 확인
```bash
# 서비스 상태 확인
aws ecs describe-services --cluster momentir-cx-be --services momentir-cx-be

# 태스크 상태 확인
aws ecs list-tasks --cluster momentir-cx-be --service-name momentir-cx-be
```