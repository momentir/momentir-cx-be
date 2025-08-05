package handlers

import (
	"auth-go-service/internal/models"
	"auth-go-service/internal/services"
	"github.com/gin-gonic/gin"
	"net/http"
)

type AuthHandler struct {
	authService *services.AuthService
}

func NewAuthHandler(authService *services.AuthService) *AuthHandler {
	return &AuthHandler{
		authService: authService,
	}
}

// Login godoc
// @Summary      사용자 로그인
// @Description  이메일과 비밀번호를 통해 사용자 로그인 처리
// @Tags         인증
// @Accept       json
// @Produce      json
// @Param        request body models.LoginRequest true "로그인 요청 정보"
// @Success      200 {object} models.LoginResponse "로그인 성공"
// @Failure      400 {object} models.ErrorResponse "잘못된 요청 또는 로그인 실패"
// @Router       /auth/login [post]
func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: "Invalid request format",
			Errors:  []string{err.Error()},
		})
		return
	}

	failureCount := h.authService.GetLoginFailureCount(req.Email)
	if failureCount >= 3 {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: "Too many login attempts. Please try again later.",
		})
		return
	}

	response, err := h.authService.Login(req.Email, req.Password)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// RequestEmailVerification godoc
// @Summary      이메일 인증 요청
// @Description  이메일 주소로 인증 코드 발송 요청
// @Tags         인증
// @Accept       json
// @Produce      json
// @Param        request body models.RequestEmailVerificationRequest true "이메일 인증 요청 정보"
// @Success      200 {object} models.RequestEmailVerificationResponse "인증 코드 발송 성공"
// @Failure      400 {object} models.ErrorResponse "잘못된 요청"
// @Router       /auth/request-email-verification [post]
func (h *AuthHandler) RequestEmailVerification(c *gin.Context) {
	var req models.RequestEmailVerificationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: "Invalid request format",
			Errors:  []string{err.Error()},
		})
		return
	}

	response, err := h.authService.RequestEmailVerification(req.Email)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// VerifyEmailAccount godoc
// @Summary      이메일 계정 인증
// @Description  발송된 인증 코드를 통해 이메일 계정 인증 처리
// @Tags         인증
// @Accept       json
// @Produce      json
// @Param        request body models.VerifyEmailRequest true "계정 인증 요청 정보"
// @Success      200 {object} object{message=string} "계정 인증 성공"
// @Failure      400 {object} models.ErrorResponse "잘못된 요청 또는 인증 실패"
// @Router       /auth/verify-email-account [post]
func (h *AuthHandler) VerifyEmailAccount(c *gin.Context) {
	var req models.VerifyEmailRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: "Invalid request format",
			Errors:  []string{err.Error()},
		})
		return
	}

	err := h.authService.VerifyEmailAccount(req.Email, req.VerificationCode, req.VerificationID)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Email account verified successfully.",
	})
}

// SignUp godoc
// @Summary      사용자 회원가입
// @Description  새로운 사용자 계정 생성
// @Tags         인증
// @Accept       json
// @Produce      json
// @Param        request body models.SignUpRequest true "회원가입 요청 정보"
// @Success      200 {object} object{message=string} "회원가입 성공"
// @Failure      400 {object} models.ErrorResponse "잘못된 요청 또는 회원가입 실패"
// @Router       /auth/sign-up [post]
func (h *AuthHandler) SignUp(c *gin.Context) {
	var req models.SignUpRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: "Invalid request format",
			Errors:  []string{err.Error()},
		})
		return
	}

	response, err := h.authService.SignUp(&req)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, response)
}

// FindMyEmail godoc
// @Summary      이메일 찾기
// @Description  이름과 전화번호를 통해 등록된 이메일 주소 찾기
// @Tags         인증
// @Accept       json
// @Produce      json
// @Param        name query string true "사용자 이름"
// @Param        phone query string true "전화번호"
// @Success      200 {object} models.FindMyEmailResponse "이메일 찾기 성공"
// @Failure      400 {object} models.ErrorResponse "필수 파라미터 누락"
// @Failure      404 {object} models.ErrorResponse "일치하는 계정 없음"
// @Router       /auth/find-my-email [get]
func (h *AuthHandler) FindMyEmail(c *gin.Context) {
	name := c.Query("name")
	phone := c.Query("phone")

	if name == "" || phone == "" {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: "Name and phone are required",
		})
		return
	}

	maskedEmail, err := h.authService.FindMyEmail(name, phone)
	if err != nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, models.FindMyEmailResponse{
		MaskedEmail: maskedEmail,
	})
}

// RequestPasswordReset godoc
// @Summary      비밀번호 재설정 요청
// @Description  이메일로 비밀번호 재설정 링크 발송
// @Tags         인증
// @Accept       json
// @Produce      json
// @Param        request body models.RequestPasswordResetRequest true "비밀번호 재설정 요청 정보"
// @Success      200 {object} object{message=string} "재설정 이메일 발송 성공"
// @Failure      400 {object} models.ErrorResponse "잘못된 요청"
// @Router       /auth/reset-password [post]
func (h *AuthHandler) RequestPasswordReset(c *gin.Context) {
	var req models.RequestPasswordResetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: "Invalid request format",
			Errors:  []string{err.Error()},
		})
		return
	}

	err := h.authService.RequestPasswordReset(req.Email)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Password reset email sent",
	})
}

// ResetPassword godoc
// @Summary      비밀번호 재설정
// @Description  재설정 토큰을 통해 새로운 비밀번호로 변경
// @Tags         인증
// @Accept       json
// @Produce      json
// @Param        request body models.ResetPasswordRequest true "비밀번호 재설정 정보"
// @Success      200 {object} object{message=string} "비밀번호 재설정 성공"
// @Failure      400 {object} models.ErrorResponse "잘못된 요청 또는 토큰 오류"
// @Router       /auth/reset-password/password [put]
func (h *AuthHandler) ResetPassword(c *gin.Context) {
	var req models.ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: "Invalid request format",
			Errors:  []string{err.Error()},
		})
		return
	}

	err := h.authService.ResetPassword(req.Token, req.NewPassword)
	if err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Message: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Password reset successful",
	})
}

// Logout godoc
// @Summary      사용자 로그아웃
// @Description  인증된 사용자 로그아웃 처리
// @Tags         인증
// @Accept       json
// @Produce      json
// @Security     ApiKeyAuth
// @Success      200 {object} object{message=string} "로그아웃 성공"
// @Router       /auth/logout [post]
func (h *AuthHandler) Logout(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"message": "Logged out successfully",
	})
}
