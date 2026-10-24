package errors_test

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	apperrors "github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/platform/errors"
)

func TestValidationFmtSDD97(t *testing.T) {
	err := apperrors.Validation("Nomor WhatsApp tidak valid", map[string]any{"field": "wa_phone"})
	require.Equal(t, http.StatusBadRequest, err.Status)
	assert.Equal(t, apperrors.CodeValidationFailed, err.Detail.Code)
	assert.Equal(t, "Nomor WhatsApp tidak valid", err.Detail.Message)
	assert.Equal(t, "wa_phone", err.Detail.Details["field"])

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/test", nil)

	apperrors.Write(rec, req, err)
	assert.Equal(t, http.StatusBadRequest, rec.Code)
	assert.Equal(t, "application/json; charset=utf-8", rec.Header().Get("Content-Type"))

	var resp apperrors.ErrorResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))
	assert.Equal(t, "VALIDATION_FAILED", resp.Error.Code)
	assert.Equal(t, "Nomor WhatsApp tidak valid", resp.Error.Message)
	assert.Equal(t, "wa_phone", resp.Error.Details["field"])
}

func TestStandardErrorConstructors(t *testing.T) {
	tests := []struct {
		name       string
		err        *apperrors.AppError
		wantStatus int
		wantCode   string
	}{
		{"BadRequest", apperrors.BadRequest("bad"), http.StatusBadRequest, "BAD_REQUEST"},
		{"Unauthorized", apperrors.Unauthorized(""), http.StatusUnauthorized, "UNAUTHORIZED"},
		{"Forbidden", apperrors.Forbidden(""), http.StatusForbidden, "FORBIDDEN"},
		{"NotFound", apperrors.NotFound("Rumah"), http.StatusNotFound, "NOT_FOUND"},
		{"Conflict", apperrors.Conflict("conflict"), http.StatusConflict, "CONFLICT"},
		{"RateLimited", apperrors.RateLimited(60), http.StatusTooManyRequests, "RATE_LIMITED"},
		{"Internal", apperrors.Internal(errors.New("db error")), http.StatusInternalServerError, "INTERNAL_ERROR"},
		{"ServiceUnavailable", apperrors.ServiceUnavailable(""), http.StatusServiceUnavailable, "SERVICE_UNAVAILABLE"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.wantStatus, tt.err.Status)
			assert.Equal(t, tt.wantCode, tt.err.Detail.Code)
		})
	}
}

func TestWriteGenericError(t *testing.T) {
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/test", nil)

	apperrors.Write(rec, req, errors.New("unexpected crash"))
	assert.Equal(t, http.StatusInternalServerError, rec.Code)

	var resp apperrors.ErrorResponse
	require.NoError(t, json.Unmarshal(rec.Body.Bytes(), &resp))
	assert.Equal(t, apperrors.CodeInternalError, resp.Error.Code)
	assert.Equal(t, "Terjadi kesalahan pada sistem", resp.Error.Message)
}
