package models

import (
	"time"
	"gorm.io/gorm"
)

type User struct {
	ID                     uint      `json:"id" gorm:"primaryKey"`
	Name                   string    `json:"name" gorm:"size:30;not null"`
	Email                  string    `json:"email" gorm:"size:60;not null;uniqueIndex"`
	EncryptedPassword      string    `json:"-" gorm:"size:256;not null"`
	Phone                  string    `json:"phone" gorm:"size:30;not null"`
	SignUpToken            string    `json:"-" gorm:"size:50"`
	ResetPasswordToken     string    `json:"-" gorm:"size:256"`
	AgreedMarketingOptIn   bool      `json:"agreedMarketingOptIn" gorm:"default:false"`
	SignUpStatus           string    `json:"signUpStatus" gorm:"size:20;default:IN_PROGRESS"`
	CreatedAt              time.Time `json:"createdAt"`
	UpdatedAt              time.Time `json:"updatedAt"`
	DeletedAt              gorm.DeletedAt `json:"-" gorm:"index"`
}

type EmailVerification struct {
	ID               uint      `json:"id" gorm:"primaryKey"`
	Email            string    `json:"email" gorm:"size:60;not null;index"`
	VerificationCode string    `json:"verificationCode" gorm:"size:10;not null"`
	ExpiresAt        time.Time `json:"expiresAt" gorm:"not null"`
	VerifiedAt       *time.Time `json:"verifiedAt"`
	CreatedAt        time.Time `json:"createdAt"`
	UpdatedAt        time.Time `json:"updatedAt"`
}

type LoginFailure struct {
	ID            uint      `json:"id" gorm:"primaryKey"`
	Email         string    `json:"email" gorm:"size:60;not null;index"`
	FailureReason string    `json:"failureReason" gorm:"size:50;not null"`
	CreatedAt     time.Time `json:"createdAt"`
}

type PasswordResetToken struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	UserID    uint      `json:"userId" gorm:"not null"`
	User      User      `json:"user" gorm:"foreignKey:UserID"`
	Token     string    `json:"token" gorm:"size:256;not null"`
	ExpiresAt time.Time `json:"expiresAt" gorm:"not null"`
	CreatedAt time.Time `json:"createdAt"`
}