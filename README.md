# Auth Go Service

기존 NestJS 기반 momentir-be 프로젝트에서 인증 관련 기능만을 추출하여 Go로 포팅한 마이크로서비스입니다.

## 주요 기능

1. **이메일/비밀번호 로그인** - JWT 토큰 기반 인증
2. **이메일 인증을 통한 회원가입** - AWS SES를 통한 인증코드 발송
3. **비밀번호 찾기** - 이메일을 통한 비밀번호 재설정

## 기존 프로젝트와의 차이점

- **회사 정보 제거**: 기존의 사업자명, 사업자등록번호 등 회사 관련 정보를 모두 제거
- **전화번호만 입력**: 회원가입 시 이름, 이메일, 전화번호, 비밀번호만 입력받음
- **간소화된 스키마**: 사용자 테이블만 유지하고 회사 관련 테이블은 제거

## 프로젝트 구조

```
auth-go-service/
├── cmd/
│   └── main.go                 # 애플리케이션 엔트리포인트
├── internal/
│   ├── config/
│   │   └── config.go          # 환경설정 관리
│   ├── database/
│   │   └── database.go        # 데이터베이스 연결 및 마이그레이션
│   ├── handlers/
│   │   └── auth_handler.go    # HTTP 핸들러
│   ├── middleware/
│   │   └── auth_middleware.go # 인증 미들웨어
│   ├── models/
│   │   ├── user.go           # 데이터베이스 모델
│   │   └── dto.go            # 요청/응답 DTO
│   └── services/
│       ├── auth_service.go   # 인증 비즈니스 로직
│       └── email_service.go  # 이메일 발송 서비스
├── pkg/
│   └── utils/
│       └── hash.go           # 유틸리티 함수
├── go.mod
├── .env.example
└── README.md
```

## 설치 및 실행

### 1. 의존성 설치

```bash
go mod tidy
```

### 2. 환경 변수 설정

`.env.example`을 참고하여 `.env` 파일을 생성하고 필요한 값들을 설정합니다.

```bash
cp .env.example .env
```

### 3. 데이터베이스 준비

MySQL 데이터베이스를 생성하고 설정 파일에 연결 정보를 입력합니다.

### 4. 애플리케이션 실행

```bash
go run cmd/main.go
```

## API 엔드포인트

### 인증

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/v1/auth/login` | 로그인 |
| POST | `/v1/auth/logout` | 로그아웃 |
| GET | `/v1/auth/find-my-email` | 이메일 찾기 |
| POST | `/v1/auth/reset-password` | 비밀번호 재설정 요청 |
| PUT | `/v1/auth/reset-password/password` | 비밀번호 재설정 |
| POST | `/v1/auth/request-email-verification` | 이메일 인증 요청 |
| POST | `/v1/auth/verify-email-account` | 이메일 인증 확인 |
| POST | `/v1/auth/sign-up` | 회원가입 |

### API 사용 예시

#### 1. 이메일 인증 요청
```bash
curl -X POST http://localhost:8081/v1/auth/request-email-verification \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'
```

#### 2. 이메일 인증 확인
```bash
curl -X POST http://localhost:8081/v1/auth/verify-email-account \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "verificationCode": "123456",
    "verificationId": 1
  }'
```

#### 3. 회원가입
```bash
curl -X POST http://localhost:8081/v1/auth/sign-up \
  -H "Content-Type: application/json" \
  -d '{
    "name": "홍길동",
    "email": "user@example.com",
    "phone": "010-1234-5678",
    "password": "password123",
    "agreedMarketingOptIn": false
  }'
```

#### 4. 로그인
```bash
curl -X POST http://localhost:8081/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

## 데이터베이스 스키마

### users 테이블
- `id`: 사용자 ID (Primary Key)
- `name`: 사용자 이름
- `email`: 이메일 주소 (Unique)
- `encrypted_password`: 암호화된 비밀번호
- `phone`: 전화번호
- `sign_up_token`: 회원가입 토큰
- `reset_password_token`: 비밀번호 재설정 토큰
- `agreed_marketing_opt_in`: 마케팅 수신 동의
- `sign_up_status`: 가입 상태 (IN_PROGRESS, COMPLETED)

### email_verifications 테이블
- `id`: 인증 ID (Primary Key)
- `email`: 이메일 주소
- `verification_code`: 인증 코드
- `expires_at`: 만료 시간
- `verified_at`: 인증 완료 시간

### login_failures 테이블
- `id`: 실패 ID (Primary Key)  
- `email`: 이메일 주소
- `failure_reason`: 실패 이유

### password_reset_tokens 테이블
- `id`: 토큰 ID (Primary Key)
- `user_id`: 사용자 ID (Foreign Key)
- `token`: 재설정 토큰
- `expires_at`: 만료 시간

## AWS SES 설정

이메일 발송을 위해 AWS SES를 사용합니다. 다음 설정이 필요합니다:

1. AWS SES에서 발신자 이메일 주소 인증
2. IAM 사용자 생성 및 SES 권한 부여
3. 환경변수에 AWS 키 설정

## 보안 고려사항

- 로그인 실패 3회 이상 시 추가 보안 조치 필요 (현재는 제한만 적용)
- JWT 토큰 만료 시간: 24시간
- 이메일 인증 코드 만료 시간: 10분
- 비밀번호 재설정 토큰 만료 시간: 1시간
- bcrypt를 사용한 비밀번호 해싱

## 라이센스

이 프로젝트는 원본 momentir-be 프로젝트에서 추출되었습니다.