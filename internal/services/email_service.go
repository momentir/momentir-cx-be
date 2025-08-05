package services

import (
	"fmt"
	"log"
	"auth-go-service/internal/config"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/credentials"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ses"
)

type EmailService struct {
	sesClient *ses.SES
	fromEmail string
}

func NewEmailService(cfg *config.Config) *EmailService {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(cfg.AWSRegion),
		Credentials: credentials.NewStaticCredentials(
			cfg.AWSSESAccessKey,
			cfg.AWSSESSecretAccessKey,
			"",
		),
	})
	if err != nil {
		log.Fatal("Failed to create AWS session:", err)
	}

	return &EmailService{
		sesClient: ses.New(sess),
		fromEmail: cfg.AWSSESFromEmail,
	}
}

func (e *EmailService) SendVerificationCodeEmail(email, code string) error {
	log.Printf("Sending verification code email to %s", email)
	log.Printf("Verification code: %s", code)

	htmlBody := fmt.Sprintf(`
		<p>Your verification code is: <strong>%s</strong></p>
		<p>This code will expire in 10 minutes.</p>
		<p>If you did not request this, please ignore this email.</p>
	`, code)

	input := &ses.SendEmailInput{
		Source: aws.String(e.fromEmail),
		Destination: &ses.Destination{
			ToAddresses: []*string{aws.String(email)},
		},
		Message: &ses.Message{
			Subject: &ses.Content{
				Data: aws.String("Your Email Verification Code"),
			},
			Body: &ses.Body{
				Html: &ses.Content{
					Data: aws.String(htmlBody),
				},
			},
		},
	}

	_, err := e.sesClient.SendEmail(input)
	if err != nil {
		log.Printf("Failed to send verification email: %v", err)
		return err
	}

	log.Printf("Verification email sent successfully to %s", email)
	return nil
}

func (e *EmailService) SendPasswordResetEmail(email, token string) error {
	log.Printf("Sending password reset email to %s", email)
	log.Printf("Reset token: %s", token)

	resetLink := fmt.Sprintf("https://yourdomain.com/auth/reset-password?email=%s&token=%s", email, token)

	htmlBody := fmt.Sprintf(`
		<p>Click the link below to reset your password:</p>
		<a href="%s">%s</a>
		<p>If you didn't request a password reset, please ignore this email.</p>
	`, resetLink, resetLink)

	input := &ses.SendEmailInput{
		Source: aws.String(e.fromEmail),
		Destination: &ses.Destination{
			ToAddresses: []*string{aws.String(email)},
		},
		Message: &ses.Message{
			Subject: &ses.Content{
				Data: aws.String("Password Reset Request"),
			},
			Body: &ses.Body{
				Html: &ses.Content{
					Data: aws.String(htmlBody),
				},
			},
		},
	}

	_, err := e.sesClient.SendEmail(input)
	if err != nil {
		log.Printf("Failed to send password reset email: %v", err)
		return err
	}

	log.Printf("Password reset email sent successfully to %s", email)
	return nil
}