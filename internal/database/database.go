package database

import (
	"fmt"
	"log"

	"auth-go-service/internal/config"
	"auth-go-service/internal/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func InitDatabase(cfg *config.Config) {
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName)

	var err error
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger:                 logger.Default.LogMode(logger.Silent), // 로그 레벨을 Silent로 변경
		SkipDefaultTransaction: true,                                   // 기본 트랜잭션 비활성화로 성능 향상
		PrepareStmt:            true,                                   // Prepared Statement 사용
	})
	if err != nil {
		log.Fatal("Failed to connect to database:", err)
	}

	log.Println("Connected to database successfully")

	// SKIP_MIGRATION=true 환경변수로 마이그레이션 스킵 가능
	if !cfg.SkipMigration {
		err = DB.AutoMigrate(
			&models.User{},
			&models.EmailVerification{},
			&models.LoginFailure{},
			&models.PasswordResetToken{},
		)
		if err != nil {
			log.Fatal("Failed to migrate database:", err)
		}
		log.Println("Database migration completed")
	} else {
		log.Println("Skipping database migration (SKIP_MIGRATION=true)")
	}
}
