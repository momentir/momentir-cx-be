package models

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email" example:"user@example.com"` // 사용자 이메일 주소
	Password string `json:"password" binding:"required" example:"password123"`         // 사용자 비밀번호
}

type LoginResponse struct {
	Token     string `json:"token" example:"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."`  // JWT 인증 토큰
	ExpiresIn int    `json:"expiresIn" example:"3600"`                              // 토큰 만료 시간(초)
}

type SignUpRequest struct {
	Name     string `json:"name" binding:"required" example:"홍길동"`                           // 사용자 이름
	Email    string `json:"email" binding:"required,email" example:"user@example.com"`      // 이메일 주소
	Phone    string `json:"phone" binding:"required" example:"010-1234-5678"`              // 전화번호
	Password string `json:"password" binding:"required,min=8" example:"password123"`       // 비밀번호 (8자 이상)
	AgreedMarketingOptIn bool `json:"agreedMarketingOptIn" example:"true"`               // 마케팅 수신 동의
}

type RequestEmailVerificationRequest struct {
	Email string `json:"email" binding:"required,email" example:"user@example.com"` // 인증받을 이메일 주소
}

type RequestEmailVerificationResponse struct {
	Message        string `json:"message" example:"인증 코드가 이메일로 발송되었습니다."`      // 응답 메시지
	VerificationID uint   `json:"verificationId" example:"12345"`                  // 인증 ID
}

type VerifyEmailRequest struct {
	Email            string `json:"email" binding:"required,email" example:"user@example.com"`  // 인증할 이메일 주소
	VerificationCode string `json:"verificationCode" binding:"required" example:"123456"`        // 이메일로 받은 인증 코드
	VerificationID   uint   `json:"verificationId" binding:"required" example:"12345"`          // 인증 요청 ID
}

type RequestPasswordResetRequest struct {
	Email string `json:"email" binding:"required,email" example:"user@example.com"` // 비밀번호를 재설정할 이메일 주소
}

type ResetPasswordRequest struct {
	Token       string `json:"token" binding:"required" example:"reset_token_abc123"`     // 이메일로 받은 재설정 토큰
	NewPassword string `json:"newPassword" binding:"required,min=8" example:"newpass123"` // 새로운 비밀번호 (8자 이상)
}

type FindMyEmailRequest struct {
	Name  string `json:"name" binding:"required" example:"홍길동"`          // 사용자 이름
	Phone string `json:"phone" binding:"required" example:"010-1234-5678"` // 전화번호
}

type FindMyEmailResponse struct {
	MaskedEmail string `json:"maskedEmail" example:"us***@example.com"` // 마스킹된 이메일 주소
}

type ErrorResponse struct {
	Message string   `json:"message" example:"요청 처리 중 오류가 발생했습니다."`     // 오류 메시지
	Errors  []string `json:"errors,omitempty" example:"[\"필드 검증 실패\"]"`   // 상세 오류 목록
}