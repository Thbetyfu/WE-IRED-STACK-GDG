package assembly

import (
	"time"
)

type Facilities struct {
	WheelchairAccessible bool `json:"wheelchair_accessible"`
	Toilet               bool `json:"toilet"`
	Electricity          bool `json:"electricity"`
	Water                bool `json:"water"`
}

type AssemblyPoint struct {
	ID         string     `json:"id"`
	RTID       string     `json:"rt_id"`
	Name       string     `json:"name"`
	Lat        float64    `json:"lat"`
	Lon        float64    `json:"lon"`
	Capacity   int        `json:"capacity"`
	Facilities Facilities `json:"facilities"`
	Contact    string     `json:"contact,omitempty"`
	IsActive   bool       `json:"is_active"`
	CreatedAt  time.Time  `json:"created_at"`
}

type BlockAssemblyPoint struct {
	BlockID         string `json:"block_id"`
	AssemblyPointID string `json:"assembly_point_id"`
	Rank            int    `json:"rank"` // 1: utama, 2: cadangan
	APName          string `json:"ap_name,omitempty"`
}

type BlockMapping struct {
	BlockID         string         `json:"block_id"`
	PrimaryAPID     string         `json:"primary_ap_id"`
	PrimaryAP       *AssemblyPoint `json:"primary_ap,omitempty"`
	SecondaryAPID   string         `json:"secondary_ap_id"`
	SecondaryAP     *AssemblyPoint `json:"secondary_ap,omitempty"`
}
