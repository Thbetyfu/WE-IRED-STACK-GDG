# Build stage
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Copy dependency definitions
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary with CGO disabled
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=1.0.0" \
    -o /app/bin/weired ./cmd/weired

# Final runtime stage
FROM alpine:3.20

WORKDIR /app

RUN apk add --no-cache ca-certificates tzdata curl postgresql-client

# Create non-root user
RUN addgroup -S weired && adduser -S weired -G weired

# Copy binary from builder
COPY --from=builder /app/bin/weired /usr/local/bin/weired

# Copy migrations for runtime auto-migration
COPY --from=builder /app/db /app/db

USER weired

EXPOSE 8080 8443

ENTRYPOINT ["/usr/local/bin/weired"]
CMD ["--mode=cloud", "--role=api"]
