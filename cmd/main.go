package main

import (
	_ "auth-go-service/docs"
	"auth-go-service/internal/config"
	"auth-go-service/internal/database"
	"auth-go-service/internal/handlers"
	"auth-go-service/internal/middleware"
	"auth-go-service/internal/services"
	"github.com/gin-gonic/gin"
	swaggerFiles "github.com/swaggo/files"
	ginSwagger "github.com/swaggo/gin-swagger"
	"log"
)

// @title           인증 서비스 API
// @version         1.0
// @description     사용자 인증, 회원가입, 이메일 인증, 비밀번호 재설정 기능을 제공하는 API 서비스
// @termsOfService  http://swagger.io/terms/

// @contact.name   API 지원팀
// @contact.url    http://www.swagger.io/support
// @contact.email  support@swagger.io

// @license.name  Apache 2.0
// @license.url   http://www.apache.org/licenses/LICENSE-2.0.html

// @host      localhost:8081
// @BasePath  /v1

// @securityDefinitions.apikey ApiKeyAuth
// @in header
// @name Authorization

func main() {
	cfg := config.LoadConfig()

	database.InitDatabase(cfg)

	emailService := services.NewEmailService(cfg)
	authService := services.NewAuthService(emailService, cfg.JWTSecretKey)

	authHandler := handlers.NewAuthHandler(authService)

	router := gin.Default()

	router.Use(middleware.CORS())

	v1 := router.Group("/v1")
	{
		auth := v1.Group("/auth")
		{
			auth.POST("/login", authHandler.Login)
			auth.POST("/logout", middleware.AuthRequired(authService), authHandler.Logout)
			auth.GET("/find-my-email", authHandler.FindMyEmail)
			auth.POST("/reset-password", authHandler.RequestPasswordReset)
			auth.PUT("/reset-password/password", authHandler.ResetPassword)
			auth.POST("/request-email-verification", authHandler.RequestEmailVerification)
			auth.POST("/verify-email-account", authHandler.VerifyEmailAccount)
			auth.POST("/sign-up", authHandler.SignUp)
		}
	}

	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy"})
	})

	// Swagger UI 엔드포인트
	router.GET("/docs/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
	// /docs로 바로 접근할 수 있도록 리다이렉트
	router.GET("/docs", func(c *gin.Context) {
		c.Redirect(302, "/docs/index.html")
	})

	log.Printf("Server starting on port %s", cfg.ServerPort)
	if err := router.Run(":" + cfg.ServerPort); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
