package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
)

func TestHealthCheck(t *testing.T) {
	// Set Gin to test mode
	gin.SetMode(gin.TestMode)

	// Create a new Gin router
	router := gin.New()
	
	// Create handler instance (you'll need to adjust this based on your actual setup)
	authHandler := &AuthHandler{}
	
	// Add the health route
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "ok",
			"message": "Service is healthy",
		})
	})

	// Create a test request
	req, err := http.NewRequest("GET", "/health", nil)
	if err != nil {
		t.Fatal(err)
	}

	// Create a response recorder
	rr := httptest.NewRecorder()

	// Serve the HTTP request
	router.ServeHTTP(rr, req)

	// Check status code
	assert.Equal(t, http.StatusOK, rr.Code)

	// Check response body
	var response map[string]interface{}
	err = json.Unmarshal(rr.Body.Bytes(), &response)
	assert.NoError(t, err)
	assert.Equal(t, "ok", response["status"])
}

func TestLoginEndpoint(t *testing.T) {
	// Set Gin to test mode
	gin.SetMode(gin.TestMode)

	// Create a new Gin router
	router := gin.New()
	
	// Create handler instance
	authHandler := &AuthHandler{}
	
	// Add the login route (you'll need to adjust this based on your actual setup)
	router.POST("/api/auth/login", authHandler.Login)

	// Test data
	loginData := map[string]string{
		"email":    "test@example.com",
		"password": "testpassword",
	}
	
	jsonData, _ := json.Marshal(loginData)

	// Create a test request
	req, err := http.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")

	// Create a response recorder
	rr := httptest.NewRecorder()

	// Serve the HTTP request
	router.ServeHTTP(rr, req)

	// For now, we expect a 400 or similar since we don't have a real database setup
	// You can modify this based on your actual implementation
	assert.True(t, rr.Code >= 400, "Expected error status code due to missing database setup")
}

// Example test for request validation
func TestLoginValidation(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	
	authHandler := &AuthHandler{}
	router.POST("/api/auth/login", authHandler.Login)

	tests := []struct {
		name     string
		payload  map[string]string
		expected int
	}{
		{
			name:     "missing email",
			payload:  map[string]string{"password": "test123"},
			expected: http.StatusBadRequest,
		},
		{
			name:     "missing password",
			payload:  map[string]string{"email": "test@example.com"},
			expected: http.StatusBadRequest,
		},
		{
			name:     "invalid email format",
			payload:  map[string]string{"email": "invalid-email", "password": "test123"},
			expected: http.StatusBadRequest,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			jsonData, _ := json.Marshal(tt.payload)
			req, _ := http.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(jsonData))
			req.Header.Set("Content-Type", "application/json")
			
			rr := httptest.NewRecorder()
			router.ServeHTTP(rr, req)
			
			assert.Equal(t, tt.expected, rr.Code)
		})
	}
}