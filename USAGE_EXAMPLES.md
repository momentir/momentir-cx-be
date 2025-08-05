# 사용법 예시

## 회원가입 프로세스

### 1단계: 이메일 인증 요청

```bash
curl -X POST http://localhost:8081/v1/auth/request-email-verification \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com"
  }'
```

**응답:**
```json
{
  "message": "Verification email sent. Please check your inbox.",
  "verificationId": 1
}
```

### 2단계: 이메일 인증 확인

이메일로 받은 6자리 인증코드를 사용합니다.

```bash
curl -X POST http://localhost:8081/v1/auth/verify-email-account \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "verificationCode": "123456",
    "verificationId": 1
  }'
```

**응답:**
```json
{
  "message": "Email account verified successfully."
}
```

### 3단계: 회원가입

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

**응답:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 86400
}
```

## 로그인

```bash
curl -X POST http://localhost:8081/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

**응답:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 86400
}
```

## 이메일 찾기

이름과 전화번호로 가입한 이메일을 찾을 수 있습니다.

```bash
curl "http://localhost:8081/v1/auth/find-my-email?name=홍길동&phone=010-1234-5678"
```

**응답:**
```json
{
  "maskedEmail": "us***@example.com"
}
```

## 비밀번호 재설정

### 1단계: 비밀번호 재설정 요청

```bash
curl -X POST http://localhost:8081/v1/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com"
  }'
```

**응답:**
```json
{
  "message": "Password reset email sent"
}
```

### 2단계: 새 비밀번호 설정

이메일로 받은 토큰을 사용합니다.

```bash
curl -X PUT http://localhost:8081/v1/auth/reset-password/password \
  -H "Content-Type: application/json" \
  -d '{
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "newPassword": "newpassword123"
  }'
```

**응답:**
```json
{
  "message": "Password reset successful"
}
```

## 인증이 필요한 API 호출

로그인 후 받은 토큰을 Authorization 헤더에 포함합니다.

```bash
curl -X POST http://localhost:8081/v1/auth/logout \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**응답:**
```json
{
  "message": "Logged out successfully"
}
```

## 에러 응답 예시

### 유효성 검사 실패
```json
{
  "message": "Invalid request format",
  "errors": [
    "Key: 'LoginRequest.Email' Error:Field validation for 'Email' failed on the 'required' tag"
  ]
}
```

### 인증 실패
```json
{
  "message": "계정 또는 비밀번호에 오류가 있습니다. (실패횟수: 1)"
}
```

### 이미 가입된 이메일
```json
{
  "message": "이미 가입한 이메일 주소입니다."
}
```

### 인증되지 않은 이메일로 회원가입 시도
```json
{
  "message": "이메일 주소가 인증되지 않았습니다. 이메일 인증 후 다시 시도해주세요."
}
```

## 환경 설정 예시

`.env` 파일:
```env
# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=auth_user
DB_PASSWORD=auth_password
DB_NAME=auth_service

# JWT
JWT_SECRET_KEY=your-super-secret-jwt-key-change-this-in-production

# AWS SES
AWS_REGION=ap-northeast-2
AWS_SES_ACCESS_KEY=AKIAIOSFODNN7EXAMPLE
AWS_SES_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_SES_FROM_EMAIL=noreply@yourdomain.com

# Server
SERVER_PORT=8081
```

## Docker를 사용한 실행

```bash
# Docker Compose로 전체 스택 실행 (MySQL 포함)
docker-compose up -d

# 개별 실행
docker build -t auth-go-service .
docker run -p 8081:8081 --env-file .env auth-go-service
```