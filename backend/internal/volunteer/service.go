package volunteer

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

var (
	ErrInvalidBlockData       = errors.New("data blok tidak valid")
	ErrInvalidVolunteerData   = errors.New("data relawan tidak valid")
	ErrTaskBlockUnauthorized  = errors.New("relawan tidak dapat mengambil tugas dari blok yang di luar penugasannya")
)

type Service struct {
	store Store
}

func NewService(store Store) *Service {
	return &Service{store: store}
}

// CreateBlock creates a residential block within an RT (FR-VOL-01).
func (s *Service) CreateBlock(ctx context.Context, b *Block) (*Block, error) {
	b.Name = strings.TrimSpace(b.Name)
	if b.Name == "" {
		return nil, fmt.Errorf("%w: nama blok wajib diisi", ErrInvalidBlockData)
	}

	if b.ID == "" {
		b.ID = uuid.NewString()
	}
	b.CreatedAt = time.Now().UTC()

	if err := s.store.CreateBlock(ctx, b); err != nil {
		return nil, err
	}

	return b, nil
}

func (s *Service) GetBlock(ctx context.Context, id string) (*Block, error) {
	return s.store.GetBlock(ctx, id)
}

func (s *Service) ListBlocks(ctx context.Context, rtID string) ([]*Block, error) {
	return s.store.ListBlocksByRT(ctx, rtID)
}

func (s *Service) DeleteBlock(ctx context.Context, id string) error {
	return s.store.DeleteBlock(ctx, id)
}

// RegisterVolunteer registers a volunteer with skills (FR-VOL-02).
func (s *Service) RegisterVolunteer(ctx context.Context, v *Volunteer) (*Volunteer, error) {
	if v.UserID == "" || v.RTID == "" {
		return nil, fmt.Errorf("%w: user_id dan rt_id wajib diisi", ErrInvalidVolunteerData)
	}

	v.Available = true // default siap (FR-VOL-03)
	v.CreatedAt = time.Now().UTC()

	if err := s.store.CreateVolunteer(ctx, v); err != nil {
		return nil, err
	}

	if len(v.AssignedBlocks) > 0 {
		_ = s.store.AssignBlocksToVolunteer(ctx, v.UserID, v.AssignedBlocks)
	}

	return v, nil
}

// SetAvailability toggles volunteer availability status (siap / tidak tersedia per FR-VOL-03).
func (s *Service) SetAvailability(ctx context.Context, userID string, available bool) error {
	return s.store.SetVolunteerAvailability(ctx, userID, available)
}

// AssignBlocks assigns a volunteer to one or more blocks (FR-VOL-02).
func (s *Service) AssignBlocks(ctx context.Context, userID string, blockIDs []string) error {
	return s.store.AssignBlocksToVolunteer(ctx, userID, blockIDs)
}

func (s *Service) GetVolunteer(ctx context.Context, userID string) (*Volunteer, error) {
	return s.store.GetVolunteer(ctx, userID)
}

func (s *Service) ListVolunteers(ctx context.Context, rtID string) ([]*Volunteer, error) {
	return s.store.ListVolunteersByRT(ctx, rtID)
}

func (s *Service) GetVolunteerBlocks(ctx context.Context, userID string) ([]string, error) {
	return s.store.GetVolunteerBlocks(ctx, userID)
}

// CanVolunteerAccessBlock checks whether the volunteer has access to a block's household details (FR-VOL-04).
func (s *Service) CanVolunteerAccessBlock(ctx context.Context, userID, blockID string) (bool, error) {
	assignedBlocks, err := s.store.GetVolunteerBlocks(ctx, userID)
	if err != nil {
		return false, err
	}

	for _, b := range assignedBlocks {
		if b == blockID {
			return true, nil
		}
	}
	return false, nil
}

// CanVolunteerClaimTask ensures a volunteer cannot claim a task located in a block outside their jurisdiction.
func (s *Service) CanVolunteerClaimTask(ctx context.Context, userID, taskBlockID string) (bool, error) {
	canAccess, err := s.CanVolunteerAccessBlock(ctx, userID, taskBlockID)
	if err != nil {
		return false, err
	}
	if !canAccess {
		return false, ErrTaskBlockUnauthorized
	}
	return true, nil
}
