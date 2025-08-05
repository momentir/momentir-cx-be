package config

import (
	"github.com/joho/godotenv"
	"log"
	"os"
)

type Config struct {
	DBHost                string
	DBPort                string
	DBUser                string
	DBPassword            string
	DBName                string
	JWTSecretKey          string
	AWSRegion             string
	AWSSESAccessKey       string
	AWSSESSecretAccessKey string
	AWSSESFromEmail       string
	ServerPort            string
	SkipMigration         bool
}

func LoadConfig() *Config {
	err := godotenv.Load()
	if err != nil {
		log.Println("Warning: .env file not found, using environment variables")
	}

	return &Config{
		DBHost:                getEnv("DATABASE_HOST", "localhost"),
		DBPort:                getEnv("DATABASE_PORT", "3306"),
		DBUser:                getEnv("DATABASE_USERNAME", "root"),
		DBPassword:            getEnv("DATABASE_PASSWORD", "password"),
		DBName:                getEnv("DATABASE_DEFAULT_SCHEMA", "auth_service"),
		JWTSecretKey:          getEnv("JWT_SECRET_KEY", "your-secret-key-here"),
		AWSRegion:             getEnv("AWS_REGION", "ap-northeast-2"),
		AWSSESAccessKey:       getEnv("AWS_SES_ACCESS_KEY", ""),
		AWSSESSecretAccessKey: getEnv("AWS_SES_SECRET_ACCESS_KEY", ""),
		AWSSESFromEmail:       getEnv("AWS_SES_FROM_EMAIL", "noreply@yourdomain.com"),
		ServerPort:            getEnv("SERVER_PORT", "8081"),
		SkipMigration:         getEnv("SKIP_MIGRATION", "false") == "true",
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
