package priority

import (
	"math"
	"sort"
)

type QueueItem struct {
	HouseholdID     string
	BlockID         string
	PriorityScore   float64
	VulnerableCount int
	WaitMinutes     float64
	DistanceMeters  float64
	Lat             *float64
	Lon             *float64
}

type VolunteerCandidate struct {
	UserID         string
	Name           string
	AssignedBlocks []string
	ActiveLoad     int      // tasks in ('ditugaskan', 'diterima', 'dalam_perjalanan')
	IsAvailable    bool     // status ketersediaan
	LastLat        *float64
	LastLon        *float64
}

type SuggestedAssignment struct {
	HouseholdID string  `json:"household_id"`
	VolunteerID string  `json:"volunteer_id"`
	Score       float64 `json:"priority_score"`
	DistanceM   float64 `json:"distance_meters"`
	SameBlock   bool    `json:"same_block"`
}

// GenerateAssignmentPlan implements the greedy assignment algorithm from SDD 6.3:
//
// antrean = rumah dalam insiden, skor > 0, tanpa tugas aktif, urut skor menurun
// relawan = relawan tersedia, beban aktif < 2 tugas
// untuk setiap rumah di antrean:
//
//	kandidat = relawan dengan blok = blok rumah
//	jika kosong -> kandidat = semua relawan tersedia
//	pilih kandidat dengan (beban terkecil, jarak terdekat)
//	buat tugas berstatus "disarankan"
func GenerateAssignmentPlan(queue []*QueueItem, volunteers []*VolunteerCandidate) []*SuggestedAssignment {
	// 1. Filter and sort queue: score > 0, sorted descending
	// Tie-breaking rule per SDD 6.1:
	// "Urutan jika skor sama: V lebih tinggi -> menunggu lebih lama -> jarak lebih jauh."
	sort.Slice(queue, func(i, j int) bool {
		if queue[i].PriorityScore != queue[j].PriorityScore {
			return queue[i].PriorityScore > queue[j].PriorityScore
		}
		if queue[i].VulnerableCount != queue[j].VulnerableCount {
			return queue[i].VulnerableCount > queue[j].VulnerableCount
		}
		if queue[i].WaitMinutes != queue[j].WaitMinutes {
			return queue[i].WaitMinutes > queue[j].WaitMinutes
		}
		return queue[i].DistanceMeters > queue[j].DistanceMeters
	})

	// 2. Filter available volunteers with active load < 2
	volMap := make(map[string]*VolunteerCandidate)
	for _, v := range volunteers {
		if v.IsAvailable && v.ActiveLoad < 2 {
			copyV := *v
			volMap[v.UserID] = &copyV
		}
	}

	var suggestions []*SuggestedAssignment

	for _, hh := range queue {
		if hh.PriorityScore <= 0 {
			continue
		}

		// Find candidates in same block first
		var blockCandidates []*VolunteerCandidate
		for _, v := range volMap {
			if v.ActiveLoad >= 2 {
				continue
			}
			for _, b := range v.AssignedBlocks {
				if b == hh.BlockID {
					blockCandidates = append(blockCandidates, v)
					break
				}
			}
		}

		sameBlock := true
		candidates := blockCandidates
		if len(candidates) == 0 {
			sameBlock = false
			// Fallback: all available volunteers with active load < 2
			for _, v := range volMap {
				if v.ActiveLoad < 2 {
					candidates = append(candidates, v)
				}
			}
		}

		if len(candidates) == 0 {
			// No volunteer available right now for this household
			continue
		}

		// Pick candidate with (beban terkecil, jarak terdekat)
		var bestVol *VolunteerCandidate
		var bestDist float64 = math.MaxFloat64

		for _, v := range candidates {
			dist := 0.0
			if hh.Lat != nil && hh.Lon != nil && v.LastLat != nil && v.LastLon != nil {
				dist = HaversineDistance(*hh.Lat, *hh.Lon, *v.LastLat, *v.LastLon)
			}

			if bestVol == nil {
				bestVol = v
				bestDist = dist
			} else if v.ActiveLoad < bestVol.ActiveLoad {
				bestVol = v
				bestDist = dist
			} else if v.ActiveLoad == bestVol.ActiveLoad && dist < bestDist {
				bestVol = v
				bestDist = dist
			}
		}

		if bestVol != nil {
			suggestions = append(suggestions, &SuggestedAssignment{
				HouseholdID: hh.HouseholdID,
				VolunteerID: bestVol.UserID,
				Score:       hh.PriorityScore,
				DistanceM:   bestDist,
				SameBlock:   sameBlock,
			})

			// Increment load of the assigned volunteer for subsequent houses
			bestVol.ActiveLoad++
		}
	}

	return suggestions
}

// HaversineDistance computes the great circle distance in meters between two lat/lon pairs.
func HaversineDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusMeters = 6371000.0

	dLat := (lat2 - lat1) * (math.Pi / 180.0)
	dLon := (lon2 - lon1) * (math.Pi / 180.0)

	rLat1 := lat1 * (math.Pi / 180.0)
	rLat2 := lat2 * (math.Pi / 180.0)

	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(rLat1)*math.Cos(rLat2)*math.Sin(dLon/2)*math.Sin(dLon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadiusMeters * c
}
