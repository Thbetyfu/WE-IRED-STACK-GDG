package errors

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
)

// Standard Error Codes according to SDD 9.7 and API design.
const (
	CodeValidationFailed   = "VALIDATION_FAILED"
	CodeBadRequest         = "BAD_REQUEST"
	CodeUnauthorized       = "UNAUTHORIZED"
	CodeForbidden          = "FORBIDDEN"
	CodeNotFound           = "NOT_FOUND"
	CodeConflict           = "CONFLICT"
	CodeRateLimited        = "RATE_LIMITED"
	CodeInternalError      = "INTERNAL_ERROR"
	CodeServiceUnavailable = "SERVICE_UNAVAILABLE"
)

// ErrorDetail represents the inner error body per SDD 9.7.
type ErrorDetail struct {
	Code    string         `json:"code"`
	Message string         `json:"message"`
	Details map[string]any `json:"details,omitempty"`
}

// ErrorResponse represents the outer error payload envelope: {"error": {...}}.
type ErrorResponse struct {
	Error ErrorDetail `json:"error"`
}

// AppError represents an application error containing an HTTP status code,
// SDD 9.7 formatted error detail, and optional underlying error.
type AppError struct {
	Status int
	Detail ErrorDetail
	Err    error
}

func (e *AppError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("[%s] %s: %v", e.Detail.Code, e.Detail.Message, e.Err)
	}
	return fmt.Sprintf("[%s] %s", e.Detail.Code, e.Detail.Message)
}

func (e *AppError) Unwrap() error {
	return e.Err
}

// New creates a new AppError with the specified HTTP status code.
func New(status int, code, message string, details map[string]any) *AppError {
	return &AppError{
		Status: status,
		Detail: ErrorDetail{
			Code:    code,
			Message: message,
			Details: details,
		},
	}
}

// Validation returns a 400 Bad Request error for input validation failures.
func Validation(message string, details map[string]any) *AppError {
	return New(http.StatusBadRequest, CodeValidationFailed, message, details)
}

// BadRequest returns a generic 400 Bad Request error.
func BadRequest(message string) *AppError {
	return New(http.StatusBadRequest, CodeBadRequest, message, nil)
}

// Unauthorized returns a 401 Unauthorized error.
func Unauthorized(message string) *AppError {
	if message == "" {
		message = "Autentikasi diperlukan"
	}
	return New(http.StatusUnauthorized, CodeUnauthorized, message, nil)
}

// Forbidden returns a 403 Forbidden error.
func Forbidden(message string) *AppError {
	if message == "" {
		message = "Akses ditolak"
	}
	return New(http.StatusForbidden, CodeForbidden, message, nil)
}

// NotFound returns a 404 Not Found error.
func NotFound(resource string) *AppError {
	msg := "Data tidak ditemukan"
	if resource != "" {
		msg = fmt.Sprintf("%s tidak ditemukan", resource)
	}
	return New(http.StatusNotFound, CodeNotFound, msg, nil)
}

// Conflict returns a 409 Conflict error.
func Conflict(message string) *AppError {
	return New(http.StatusConflict, CodeConflict, message, nil)
}

// RateLimited returns a 429 Too Many Requests error.
func RateLimited(retryAfterSeconds int) *AppError {
	var details map[string]any
	if retryAfterSeconds > 0 {
		details = map[string]any{"retry_after_seconds": retryAfterSeconds}
	}
	return New(http.StatusTooManyRequests, CodeRateLimited, "Terlalu banyak permintaan. Silakan coba beberapa saat lagi.", details)
}

// Internal wraps an unexpected server error into a 500 AppError.
func Internal(err error) *AppError {
	return &AppError{
		Status: http.StatusInternalServerError,
		Detail: ErrorDetail{
			Code:    CodeInternalError,
			Message: "Terjadi kesalahan pada sistem",
		},
		Err: err,
	}
}

// ServiceUnavailable returns a 503 Service Unavailable error.
func ServiceUnavailable(message string) *AppError {
	if message == "" {
		message = "Layanan sedang tidak tersedia"
	}
	return New(http.StatusServiceUnavailable, CodeServiceUnavailable, message, nil)
}

// WriteJSON writes a structured JSON error response directly with status, code, and message.
func WriteJSON(w http.ResponseWriter, status int, code, message string, details map[string]any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(ErrorResponse{
		Error: ErrorDetail{
			Code:    code,
			Message: message,
			Details: details,
		},
	})
}

// Write writes the standard JSON error response to w.
func Write(w http.ResponseWriter, r *http.Request, err error) {
	var appErr *AppError
	switch e := err.(type) {
	case *AppError:
		appErr = e
	default:
		appErr = Internal(err)
	}

	if appErr.Status >= 500 {
		slog.ErrorContext(r.Context(), "server error",
			"status", appErr.Status,
			"code", appErr.Detail.Code,
			"message", appErr.Detail.Message,
			"error", appErr.Err,
		)
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(appErr.Status)
	_ = json.NewEncoder(w).Encode(ErrorResponse{Error: appErr.Detail})
}
