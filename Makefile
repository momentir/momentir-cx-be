# Go parameters
GOCMD=go
GOBUILD=$(GOCMD) build
GOCLEAN=$(GOCMD) clean
GOTEST=$(GOCMD) test
GOGET=$(GOCMD) get
GOMOD=$(GOCMD) mod
BINARY_NAME=main
BINARY_UNIX=$(BINARY_NAME)_unix

# Build targets
all: test build

build:
	CGO_ENABLED=0 GOOS=linux GOARCH=amd64 $(GOBUILD) -a -installsuffix cgo -ldflags="-w -s" -o $(BINARY_NAME) ./cmd/main.go

build-local:
	$(GOBUILD) -o $(BINARY_NAME) ./cmd/main.go

test:
	$(GOTEST) -v -race -buildvcs=false -coverprofile=coverage.out ./...

test-coverage:
	$(GOTEST) -v -race -buildvcs=false -coverprofile=coverage.out ./...
	$(GOCMD) tool cover -html=coverage.out -o coverage.html

clean:
	$(GOCLEAN)
	rm -f $(BINARY_NAME)
	rm -f $(BINARY_UNIX)
	rm -f coverage.out coverage.html

deps:
	$(GOMOD) download
	$(GOMOD) verify

vet:
	$(GOCMD) vet ./...

lint:
	golangci-lint run

swagger:
	swag init -g cmd/main.go -o docs

run:
	$(GOCMD) run ./cmd/main.go

docker-build:
	docker build --platform linux/amd64 -t momentir-cx-be:latest .

docker-run:
	docker run -p 8081:8081 momentir-cx-be:latest

# Development helpers
dev-setup:
	$(GOGET) -u github.com/swaggo/swag/cmd/swag
	$(GOGET) -u github.com/golangci/golangci-lint/cmd/golangci-lint

.PHONY: all build build-local test test-coverage clean deps vet lint swagger run docker-build docker-run dev-setup