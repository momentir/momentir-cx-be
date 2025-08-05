package services

import (
	"auth-go-service/internal/database"
	"auth-go-service/internal/models"
	"errors"
	"fmt"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"golang.org/x/crypto/bcrypt"
	"math/rand"
	"strings"
	"time"
)

type AuthService struct {
	emailService *EmailService
	jwtSecret    string
	jwtExpiresIn int
}

type JWTClaims struct {
	UserID uint   `json:"userId"`
	Email  string `json:"email"`
	Name   string `json:"name"`
	jwt.RegisteredClaims
}

func NewAuthService(emailService *EmailService, jwtSecret string) *AuthService {
	return &AuthService{
		emailService: emailService,
		jwtSecret:    jwtSecret,
		jwtExpiresIn: 60 * 60 * 24, // 24 hours
	}
}

func (s *AuthService) Login(email, password string) (*models.LoginResponse, error) {
	var user models.User
	if err := database.DB.Where("email = ? AND sign_up_status = ?", email, "COMPLETED").First(&user).Error; err != nil {
		s.recordLoginFailure(email, "INVALID_EMAIL")
		failureCount := s.getLoginFailureCount(email)
		return nil, fmt.Errorf("계정 또는 비밀번호에 오류가 있습니다. (실패횟수: %d)", failureCount)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.EncryptedPassword), []byte(password)); err != nil {
		s.recordLoginFailure(email, "INVALID_PASSWORD")
		failureCount := s.getLoginFailureCount(email)
		return nil, fmt.Errorf("계정 또는 비밀번호에 오류가 있습니다. (실패횟수: %d)", failureCount)
	}

	token, err := s.generateJWTToken(user)
	if err != nil {
		return nil, err
	}

	return &models.LoginResponse{
		Token:     token,
		ExpiresIn: s.jwtExpiresIn,
	}, nil
}

func (s *AuthService) GetLoginFailureCount(email string) int {
	return s.getLoginFailureCount(email)
}

func (s *AuthService) getLoginFailureCount(email string) int {
	var count int64
	oneHourAgo := time.Now().Add(-time.Hour)

	database.DB.Model(&models.LoginFailure{}).
		Where("email = ? AND created_at > ?", email, oneHourAgo).
		Count(&count)

	return int(count)
}

func (s *AuthService) recordLoginFailure(email, reason string) {
	failure := models.LoginFailure{
		Email:         email,
		FailureReason: reason,
	}
	database.DB.Create(&failure)
}

func (s *AuthService) RequestEmailVerification(email string) (*models.RequestEmailVerificationResponse, error) {
	code := s.generateVerificationCode()
	expiresAt := time.Now().Add(10 * time.Minute)

	verification := models.EmailVerification{
		Email:            email,
		VerificationCode: code,
		ExpiresAt:        expiresAt,
	}

	if err := database.DB.Create(&verification).Error; err != nil {
		return nil, err
	}

	if err := s.emailService.SendVerificationCodeEmail(email, code); err != nil {
		return nil, errors.New("Failed to send verification email. Please try again.")
	}

	return &models.RequestEmailVerificationResponse{
		Message:        "Verification email sent. Please check your inbox.",
		VerificationID: verification.ID,
	}, nil
}

func (s *AuthService) VerifyEmailAccount(email, code string, verificationID uint) error {
	var verification models.EmailVerification
	if err := database.DB.Where("id = ? AND email = ?", verificationID, email).First(&verification).Error; err != nil {
		return errors.New("Verification request not found or email does not match.")
	}

	if verification.VerifiedAt != nil {
		return errors.New("This email verification request has already been completed.")
	}

	if time.Now().After(verification.ExpiresAt) {
		return errors.New("Verification code has expired. Please request a new one.")
	}

	if verification.VerificationCode != code {
		return errors.New("Invalid verification code.")
	}

	now := time.Now()
	verification.VerifiedAt = &now
	return database.DB.Save(&verification).Error
}

func (s *AuthService) SignUp(req *models.SignUpRequest) (*models.LoginResponse, error) {
	var emailVerification models.EmailVerification
	if err := database.DB.Where("email = ?", req.Email).
		Order("created_at DESC").
		First(&emailVerification).Error; err != nil {
		return nil, errors.New("이메일 주소가 인증되지 않았습니다. 이메일 인증 후 다시 시도해주세요.")
	}

	if emailVerification.VerifiedAt == nil {
		return nil, errors.New("이메일 주소가 인증되지 않았습니다. 이메일 인증 후 다시 시도해주세요.")
	}

	var existingUser models.User
	if err := database.DB.Where("email = ?", req.Email).First(&existingUser).Error; err == nil {
		if existingUser.SignUpStatus == "COMPLETED" {
			return nil, errors.New("이미 가입한 이메일 주소입니다.")
		}
		database.DB.Delete(&existingUser)
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	user := models.User{
		Name:                 req.Name,
		Email:                req.Email,
		Phone:                req.Phone,
		EncryptedPassword:    string(hashedPassword),
		SignUpToken:          uuid.New().String(),
		AgreedMarketingOptIn: req.AgreedMarketingOptIn,
		SignUpStatus:         "COMPLETED",
	}

	if err := database.DB.Create(&user).Error; err != nil {
		return nil, err
	}

	token, err := s.generateJWTToken(user)
	if err != nil {
		return nil, err
	}

	return &models.LoginResponse{
		Token:     token,
		ExpiresIn: s.jwtExpiresIn,
	}, nil
}

func (s *AuthService) FindMyEmail(name, phone string) (string, error) {
	var user models.User
	if err := database.DB.Where("name = ? AND phone = ? AND sign_up_status = ?", name, phone, "COMPLETED").
		First(&user).Error; err != nil {
		return "", errors.New("가입한 이메일이 존재하지 않습니다.")
	}

	return s.maskEmail(user.Email), nil
}

func (s *AuthService) RequestPasswordReset(email string) error {
	var user models.User
	if err := database.DB.Where("email = ?", email).First(&user).Error; err != nil {
		return errors.New("User not found")
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"sub":   user.ID,
		"email": user.Email,
		"type":  "password_reset",
		"exp":   time.Now().Add(time.Hour).Unix(),
	})

	tokenString, err := token.SignedString([]byte(s.jwtSecret))
	if err != nil {
		return err
	}

	resetToken := models.PasswordResetToken{
		UserID:    user.ID,
		Token:     tokenString,
		ExpiresAt: time.Now().Add(time.Hour),
	}

	if err := database.DB.Create(&resetToken).Error; err != nil {
		return err
	}

	return s.emailService.SendPasswordResetEmail(email, tokenString)
}

func (s *AuthService) ResetPassword(tokenString, newPassword string) error {
	token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(s.jwtSecret), nil
	})

	if err != nil || !token.Valid {
		return errors.New("Invalid token")
	}

	claims, ok := token.Claims.(jwt.MapClaims)
	if !ok {
		return errors.New("Invalid token claims")
	}

	userID := uint(claims["sub"].(float64))
	email := claims["email"].(string)
	tokenType := claims["type"].(string)

	if tokenType != "password_reset" {
		return errors.New("Invalid token type for password reset")
	}

	var user models.User
	if err := database.DB.Where("id = ? AND email = ?", userID, email).First(&user).Error; err != nil {
		return errors.New("User not found")
	}

	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(newPassword), bcrypt.DefaultCost)
	if err != nil {
		return err
	}

	user.EncryptedPassword = string(hashedPassword)
	if err := database.DB.Save(&user).Error; err != nil {
		return err
	}

	database.DB.Where("user_id = ?", userID).Delete(&models.PasswordResetToken{})

	return nil
}

func (s *AuthService) VerifyToken(tokenString string) (*JWTClaims, error) {
	token, err := jwt.ParseWithClaims(tokenString, &JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
		}
		return []byte(s.jwtSecret), nil
	})

	if err != nil || !token.Valid {
		return nil, errors.New("Invalid token")
	}

	claims, ok := token.Claims.(*JWTClaims)
	if !ok {
		return nil, errors.New("Invalid token claims")
	}

	return claims, nil
}

func (s *AuthService) generateJWTToken(user models.User) (string, error) {
	claims := &JWTClaims{
		UserID: user.ID,
		Email:  user.Email,
		Name:   user.Name,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Duration(s.jwtExpiresIn) * time.Second)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(s.jwtSecret))
}

func (s *AuthService) generateVerificationCode() string {
	rand.Seed(time.Now().UnixNano())
	return fmt.Sprintf("%06d", rand.Intn(1000000))
}

func (s *AuthService) maskEmail(email string) string {
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return email
	}

	name := parts[0]
	domain := parts[1]
	nameLen := len(name)
	maskLen := nameLen / 2

	if maskLen == 0 {
		maskLen = 1
	}

	masked := name[:nameLen-maskLen] + strings.Repeat("*", maskLen)
	return masked + "@" + domain
}
