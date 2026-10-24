package region

import (
	"time"
)

type RegionType string

const (
	TypeKelurahan RegionType = "kelurahan"
	TypeRW        RegionType = "rw"
	TypeRT        RegionType = "rt"
)

type Role string

const (
	RoleOperator       Role = "operator"
	RoleAdminWilayah   Role = "admin_wilayah"
	RolePengurus       Role = "pengurus"
	RoleRelawan        Role = "relawan"
	RoleKepalaKeluarga Role = "kepala_keluarga"
)

type Region struct {
	ID          string     `json:"id"`
	Type        RegionType `json:"type"`
	ParentID    *string    `json:"parent_id,omitempty"`
	Name        string     `json:"name"`
	Code        string     `json:"code"`
	CentroidLat float64    `json:"centroid_lat"`
	CentroidLon float64    `json:"centroid_lon"`
	AIEnabled   bool       `json:"ai_enabled"`
	CreatedAt   time.Time  `json:"created_at"`
}

type RegionNode struct {
	Region
	Children []*RegionNode `json:"children,omitempty"`
}

type Membership struct {
	ID          string    `json:"id"`
	UserID      string    `json:"user_id"`
	RegionID    string    `json:"region_id"`
	Role        Role      `json:"role"`
	HouseholdID *string   `json:"household_id,omitempty"`
	UserName    string    `json:"user_name,omitempty"`
	UserPhone   string    `json:"user_phone,omitempty"`
	UserEmail   string    `json:"user_email,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

type AggregateMetrics struct {
	RegionID            string         `json:"region_id"`
	RegionName          string         `json:"region_name"`
	TotalRTs            int            `json:"total_rts"`
	ActiveIncidents     int            `json:"active_incidents"`
	HouseholdsByStatus  map[string]int `json:"households_by_status"`
	VulnerableUnreached int            `json:"vulnerable_unreached"`
}
