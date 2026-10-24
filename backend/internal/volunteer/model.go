package volunteer

import (
	"time"
)

type Block struct {
	ID        string                 `json:"id"`
	RTID      string                 `json:"rt_id"`
	Name      string                 `json:"name"`
	Polygon   map[string]interface{} `json:"polygon,omitempty"`
	CreatedAt time.Time              `json:"created_at"`
}

type Volunteer struct {
	UserID         string     `json:"user_id"`
	RTID           string     `json:"rt_id"`
	Name           string     `json:"name,omitempty"`
	Phone          string     `json:"phone,omitempty"`
	Skills         []string   `json:"skills"` // P3K, evakuasi, logistik (FR-VOL-02)
	Available      bool       `json:"available"` // siap / tidak tersedia (FR-VOL-03)
	LastLat        *float64   `json:"last_lat,omitempty"`
	LastLon        *float64   `json:"last_lon,omitempty"`
	LastLocAt      *time.Time `json:"last_loc_at,omitempty"`
	AssignedBlocks []string   `json:"assigned_blocks,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
}
