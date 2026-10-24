package region

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/go-chi/chi/v5"

	"github.com/Thbetyfu/WE-IRED-STACK-GDG/backend/internal/auth"
)

func TestRegionHierarchyEnforcement(t *testing.T) {
	store := NewMemoryStore()
	svc := NewService(store)
	ctx := context.Background()

	// 1. Non-operator cannot create regions
	_, err := svc.CreateRegion(ctx, &Region{
		Type: TypeKelurahan,
		Name: "Kelurahan Merdeka",
		Code: "KEL-MRD",
	}, RolePengurus)
	if err != ErrUnauthorizedAction {
		t.Fatalf("expected ErrUnauthorizedAction, got %v", err)
	}

	// 2. Kelurahan cannot have a parent
	parentID := "fake-parent-id"
	_, err = svc.CreateRegion(ctx, &Region{
		Type:     TypeKelurahan,
		ParentID: &parentID,
		Name:     "Kelurahan Merdeka",
		Code:     "KEL-MRD",
	}, RoleOperator)
	if err != ErrKelurahanParentSet {
		t.Fatalf("expected ErrKelurahanParentSet, got %v", err)
	}

	// 3. Create valid Kelurahan
	kel, err := svc.CreateRegion(ctx, &Region{
		Type: TypeKelurahan,
		Name: "Kelurahan Merdeka",
		Code: "KEL-MRD",
	}, RoleOperator)
	if err != nil {
		t.Fatalf("failed to create kelurahan: %v", err)
	}

	// 4. RW requires parent
	_, err = svc.CreateRegion(ctx, &Region{
		Type: TypeRW,
		Name: "RW 05",
		Code: "RW-05",
	}, RoleOperator)
	if err != ErrParentRequired {
		t.Fatalf("expected ErrParentRequired, got %v", err)
	}

	// 5. RW parent must be Kelurahan
	rwFakeParent := "fake-rw-parent"
	_, err = svc.CreateRegion(ctx, &Region{
		Type:     TypeRW,
		ParentID: &rwFakeParent,
		Name:     "RW 05",
		Code:     "RW-05",
	}, RoleOperator)
	if err == nil {
		t.Fatal("expected error for non-existent parent")
	}

	// 6. Create valid RW
	rw, err := svc.CreateRegion(ctx, &Region{
		Type:     TypeRW,
		ParentID: &kel.ID,
		Name:     "RW 05",
		Code:     "RW-05",
	}, RoleOperator)
	if err != nil {
		t.Fatalf("failed to create RW: %v", err)
	}

	// 7. RT parent cannot be Kelurahan (must be RW)
	_, err = svc.CreateRegion(ctx, &Region{
		Type:     TypeRT,
		ParentID: &kel.ID,
		Name:     "RT 01",
		Code:     "RT-01",
	}, RoleOperator)
	if err != ErrRTParentMustBeRW {
		t.Fatalf("expected ErrRTParentMustBeRW when parent is Kelurahan, got %v", err)
	}

	// 8. Create valid RT
	rt, err := svc.CreateRegion(ctx, &Region{
		Type:     TypeRT,
		ParentID: &rw.ID,
		Name:     "RT 01",
		Code:     "RT-01",
	}, RoleOperator)
	if err != nil {
		t.Fatalf("failed to create RT: %v", err)
	}

	if rt.ID == "" || rt.ParentID == nil || *rt.ParentID != rw.ID {
		t.Fatalf("invalid RT structure: %+v", rt)
	}
}

func TestHierarchyTreeAndScopeIsolation(t *testing.T) {
	store := NewMemoryStore()
	svc := NewService(store)
	ctx := context.Background()

	// Setup hierarchy:
	// Kelurahan Merdeka (kel)
	//   -> RW 05 (rw5)
	//        -> RT 01 (rt1)
	//        -> RT 02 (rt2)
	//   -> RW 06 (rw6)
	//        -> RT 03 (rt3)
	kel, _ := svc.CreateRegion(ctx, &Region{Type: TypeKelurahan, Name: "Kelurahan Merdeka", Code: "KEL-01"}, RoleOperator)
	rw5, _ := svc.CreateRegion(ctx, &Region{Type: TypeRW, ParentID: &kel.ID, Name: "RW 05", Code: "RW-05"}, RoleOperator)
	rw6, _ := svc.CreateRegion(ctx, &Region{Type: TypeRW, ParentID: &kel.ID, Name: "RW 06", Code: "RW-06"}, RoleOperator)

	rt1, _ := svc.CreateRegion(ctx, &Region{Type: TypeRT, ParentID: &rw5.ID, Name: "RT 01", Code: "RT-01"}, RoleOperator)
	rt2, _ := svc.CreateRegion(ctx, &Region{Type: TypeRT, ParentID: &rw5.ID, Name: "RT 02", Code: "RT-02"}, RoleOperator)
	rt3, _ := svc.CreateRegion(ctx, &Region{Type: TypeRT, ParentID: &rw6.ID, Name: "RT 03", Code: "RT-03"}, RoleOperator)

	// 1. Verify Hierarchy Tree
	tree, err := svc.GetHierarchy(ctx, nil)
	if err != nil {
		t.Fatalf("failed to get hierarchy tree: %v", err)
	}
	if len(tree) != 1 {
		t.Fatalf("expected 1 root kelurahan, got %d", len(tree))
	}
	if len(tree[0].Children) != 2 {
		t.Fatalf("expected 2 RW children under kelurahan, got %d", len(tree[0].Children))
	}

	// 2. Scope Verification (IsRTInRegion)
	// rt1 in rw5 -> true
	inScope, err := svc.IsRTInRegion(ctx, rt1.ID, rw5.ID)
	if err != nil || !inScope {
		t.Fatalf("expected rt1 to be in rw5, got %v, err=%v", inScope, err)
	}

	// rt1 in kel -> true (ancestor)
	inScope, err = svc.IsRTInRegion(ctx, rt1.ID, kel.ID)
	if err != nil || !inScope {
		t.Fatalf("expected rt1 to be in kelurahan, got %v, err=%v", inScope, err)
	}

	// rt1 in rw6 -> false (isolated)
	inScope, err = svc.IsRTInRegion(ctx, rt1.ID, rw6.ID)
	if err != nil || inScope {
		t.Fatalf("expected rt1 NOT to be in rw6, got %v", inScope)
	}

	// 3. List Accessible RTs by Role
	// Operator sees all 3 RTs
	allRTs, err := svc.ListAccessibleRTs(ctx, RoleOperator, "")
	if err != nil || len(allRTs) != 3 {
		t.Fatalf("expected operator to see 3 RTs, got %d", len(allRTs))
	}

	// Admin Wilayah for RW 05 sees rt1 and rt2 (2 RTs)
	rw5RTs, err := svc.ListAccessibleRTs(ctx, RoleAdminWilayah, rw5.ID)
	if err != nil || len(rw5RTs) != 2 {
		t.Fatalf("expected admin_wilayah for rw5 to see 2 RTs, got %d", len(rw5RTs))
	}

	// Pengurus for RT 01 sees only rt1 (1 RT)
	pengurusRTs, err := svc.ListAccessibleRTs(ctx, RolePengurus, rt1.ID)
	if err != nil || len(pengurusRTs) != 1 || pengurusRTs[0].ID != rt1.ID {
		t.Fatalf("expected pengurus to see only rt1, got %+v", pengurusRTs)
	}

	_ = rt2
	_ = rt3
}

func TestMembershipAppointment(t *testing.T) {
	store := NewMemoryStore()
	svc := NewService(store)
	ctx := context.Background()

	kel, _ := svc.CreateRegion(ctx, &Region{Type: TypeKelurahan, Name: "Kelurahan Merdeka", Code: "KEL-01"}, RoleOperator)
	rw, _ := svc.CreateRegion(ctx, &Region{Type: TypeRW, ParentID: &kel.ID, Name: "RW 01", Code: "RW-01"}, RoleOperator)
	rt, _ := svc.CreateRegion(ctx, &Region{Type: TypeRT, ParentID: &rw.ID, Name: "RT 01", Code: "RT-01"}, RoleOperator)

	// 1. Operator appoints Admin Wilayah to RW
	err := svc.AssignMembership(ctx, &Membership{
		UserID:   "user-admin",
		RegionID: rw.ID,
		Role:     RoleAdminWilayah,
	}, RoleOperator, "")
	if err != nil {
		t.Fatalf("operator failed to assign admin_wilayah: %v", err)
	}

	// 2. Admin Wilayah appoints Pengurus to RT in their RW
	err = svc.AssignMembership(ctx, &Membership{
		UserID:   "user-pengurus",
		RegionID: rt.ID,
		Role:     RolePengurus,
	}, RoleAdminWilayah, rw.ID)
	if err != nil {
		t.Fatalf("admin_wilayah failed to assign pengurus: %v", err)
	}

	// 3. Pengurus appoints Relawan in their RT
	err = svc.AssignMembership(ctx, &Membership{
		UserID:   "user-relawan",
		RegionID: rt.ID,
		Role:     RoleRelawan,
	}, RolePengurus, rt.ID)
	if err != nil {
		t.Fatalf("pengurus failed to assign relawan: %v", err)
	}

	// 4. Pengurus cannot appoint Admin Wilayah
	err = svc.AssignMembership(ctx, &Membership{
		UserID:   "user-hacker",
		RegionID: rw.ID,
		Role:     RoleAdminWilayah,
	}, RolePengurus, rt.ID)
	if err != ErrUnauthorizedAction {
		t.Fatalf("expected ErrUnauthorizedAction, got %v", err)
	}

	// 5. Verify list memberships
	memberships, err := svc.ListMemberships(ctx, rt.ID)
	if err != nil || len(memberships) != 2 {
		t.Fatalf("expected 2 memberships in RT, got %d", len(memberships))
	}
}

func TestRegionHandlerHTTP(t *testing.T) {
	jwtSecret := []byte("very-secret-key-32-bytes-long!!!")
	store := NewMemoryStore()
	svc := NewService(store)
	handler := NewHandler(svc, jwtSecret)

	ctx := context.Background()
	kel, _ := svc.CreateRegion(ctx, &Region{Type: TypeKelurahan, Name: "Kelurahan Merdeka", Code: "KEL-01"}, RoleOperator)
	rw, _ := svc.CreateRegion(ctx, &Region{Type: TypeRW, ParentID: &kel.ID, Name: "RW 01", Code: "RW-01"}, RoleOperator)
	rt, _ := svc.CreateRegion(ctx, &Region{Type: TypeRT, ParentID: &rw.ID, Name: "RT 01", Code: "RT-01"}, RoleOperator)

	r := chi.NewRouter()
	handler.Routes(r)

	server := httptest.NewServer(r)
	defer server.Close()

	// Tokens
	opTok, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{UserID: "op-1", Role: "operator"})
	rtTok, _, _ := auth.GenerateAccessToken(jwtSecret, auth.Claims{UserID: "pengurus-1", Role: "pengurus", RegionID: rt.ID})

	// 1. Operator creates new RW via POST /regions
	newRWBody, _ := json.Marshal(map[string]interface{}{
		"type":      "rw",
		"parent_id": kel.ID,
		"name":      "RW 02",
		"code":      "RW-02",
	})
	req, _ := http.NewRequest(http.MethodPost, server.URL+"/regions", bytes.NewReader(newRWBody))
	req.Header.Set("Authorization", "Bearer "+opTok)
	resp, err := http.DefaultClient.Do(req)
	if err != nil || resp.StatusCode != http.StatusCreated {
		t.Fatalf("create region failed, status=%d", resp.StatusCode)
	}

	// 2. Non-operator cannot create region
	req2, _ := http.NewRequest(http.MethodPost, server.URL+"/regions", bytes.NewReader(newRWBody))
	req2.Header.Set("Authorization", "Bearer "+rtTok)
	resp2, _ := http.DefaultClient.Do(req2)
	if resp2.StatusCode != http.StatusForbidden {
		t.Fatalf("expected 403 Forbidden for non-operator, got %d", resp2.StatusCode)
	}

	// 3. GET /rts/{rt} with valid scope
	getRTReq, _ := http.NewRequest(http.MethodGet, server.URL+"/rts/"+rt.ID, nil)
	getRTReq.Header.Set("Authorization", "Bearer "+rtTok)
	getRTResp, err := http.DefaultClient.Do(getRTReq)
	if err != nil || getRTResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK on get RT, got %d", getRTResp.StatusCode)
	}

	// 4. GET /regions/hierarchy
	hierReq, _ := http.NewRequest(http.MethodGet, server.URL+"/regions/hierarchy", nil)
	hierReq.Header.Set("Authorization", "Bearer "+opTok)
	hierResp, err := http.DefaultClient.Do(hierReq)
	if err != nil || hierResp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK on hierarchy, got %d", hierResp.StatusCode)
	}
}
