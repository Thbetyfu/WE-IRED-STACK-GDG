package whatsapp

import (
	"fmt"
)

// BuildOTPLoginPayload creates payload for 'otp_login' template (Authentication).
func BuildOTPLoginPayload(phone string, code string) SendTemplateRequest {
	var req SendTemplateRequest
	req.To = phone
	req.Template.Name = TemplateOTPLogin
	req.Template.Language.Code = "id"
	req.Template.Components = []TemplateComponent{
		{
			Type: "body",
			Parameters: []TemplateParameter{
				{Type: "text", Text: code},
			},
		},
		{
			Type:    "button",
			SubType: "url",
			Index:   "0",
			Parameters: []TemplateParameter{
				{Type: "text", Text: code},
			},
		},
	}
	return req
}

// BuildSiagaAktivasiPayload creates payload for 'siaga_aktivasi' template (Utility).
func BuildSiagaAktivasiPayload(phone, mode, hazard, rtName, incidentShortID string) SendTemplateRequest {
	var req SendTemplateRequest
	req.To = phone
	req.Template.Name = TemplateSiagaAktivasi
	req.Template.Language.Code = "id"

	modeUpper := "SIAGA"
	if mode == "latihan" {
		modeUpper = "LATIHAN"
	}

	req.Template.Components = []TemplateComponent{
		{
			Type: "body",
			Parameters: []TemplateParameter{
				{Type: "text", Text: modeUpper},
				{Type: "text", Text: hazard},
				{Type: "text", Text: rtName},
			},
		},
		{
			Type:    "button",
			SubType: "quick_reply",
			Index:   "0",
			Parameters: []TemplateParameter{
				{Type: "text", Text: fmt.Sprintf("RPT|%s|1", incidentShortID)},
			},
		},
		{
			Type:    "button",
			SubType: "quick_reply",
			Index:   "1",
			Parameters: []TemplateParameter{
				{Type: "text", Text: fmt.Sprintf("RPT|%s|2", incidentShortID)},
			},
		},
		{
			Type:    "button",
			SubType: "quick_reply",
			Index:   "2",
			Parameters: []TemplateParameter{
				{Type: "text", Text: fmt.Sprintf("RPT|%s|3", incidentShortID)},
			},
		},
	}
	return req
}

// BuildSiagaPengingatPayload creates payload for 'siaga_pengingat' template (Utility).
func BuildSiagaPengingatPayload(phone, rtName string, minutesElapsed int, incidentShortID string) SendTemplateRequest {
	var req SendTemplateRequest
	req.To = phone
	req.Template.Name = TemplateSiagaPengingat
	req.Template.Language.Code = "id"

	req.Template.Components = []TemplateComponent{
		{
			Type: "body",
			Parameters: []TemplateParameter{
				{Type: "text", Text: rtName},
				{Type: "text", Text: fmt.Sprintf("%d", minutesElapsed)},
			},
		},
		{
			Type:    "button",
			SubType: "quick_reply",
			Index:   "0",
			Parameters: []TemplateParameter{
				{Type: "text", Text: fmt.Sprintf("RPT|%s|1", incidentShortID)},
			},
		},
		{
			Type:    "button",
			SubType: "quick_reply",
			Index:   "1",
			Parameters: []TemplateParameter{
				{Type: "text", Text: fmt.Sprintf("RPT|%s|2", incidentShortID)},
			},
		},
		{
			Type:    "button",
			SubType: "quick_reply",
			Index:   "2",
			Parameters: []TemplateParameter{
				{Type: "text", Text: fmt.Sprintf("RPT|%s|3", incidentShortID)},
			},
		},
	}
	return req
}

// BuildPengumumanRTPayload creates payload for 'pengumuman_rt' template (Utility).
func BuildPengumumanRTPayload(phone, level, text string) SendTemplateRequest {
	var req SendTemplateRequest
	req.To = phone
	req.Template.Name = TemplatePengumumanRT
	req.Template.Language.Code = "id"

	req.Template.Components = []TemplateComponent{
		{
			Type: "body",
			Parameters: []TemplateParameter{
				{Type: "text", Text: level},
				{Type: "text", Text: text},
			},
		},
	}
	return req
}

// BuildRekapInsidenPayload creates payload for 'rekap_insiden' template (Utility).
func BuildRekapInsidenPayload(phone, rtName, formattedDate, pdfURL string) SendTemplateRequest {
	var req SendTemplateRequest
	req.To = phone
	req.Template.Name = TemplateRekapInsiden
	req.Template.Language.Code = "id"

	req.Template.Components = []TemplateComponent{
		{
			Type: "header",
			Parameters: []TemplateParameter{
				{
					Type: "document",
					Document: &DocumentResource{
						Link:     pdfURL,
						Filename: fmt.Sprintf("Rekap_Insiden_%s.pdf", rtName),
						Caption:  fmt.Sprintf("Dokumen Rekap Resmi Tanggap Bencana %s", rtName),
					},
				},
			},
		},
		{
			Type: "body",
			Parameters: []TemplateParameter{
				{Type: "text", Text: rtName},
				{Type: "text", Text: formattedDate},
			},
		},
	}
	return req
}
