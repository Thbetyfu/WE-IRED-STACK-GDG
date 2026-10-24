# WE-IRED Developer Guide

Panduan teknis dan arsitektural untuk pengembang yang bekerja pada repositori **WE-IRED-STACK-GDG**. Dokumen ini menjelaskan struktur monorepo, pola arsitektur, interaksi antarmodul, standar kode, dan prosedur aman untuk menambah atau memodifikasi fitur tanpa merusak kontrak integrasi antartim.

---

## 1. STRUKTUR MONOREPO

Repositori ini dikelola sebagai monorepo multi-teknologi (Go backend + Dart/Flutter workspace + C++ PlatformIO firmware):

```text
WE-IRED-STACK-GDG/
├── .github/
│   └── workflows/              # Otomatisasi CI/CD (Gitleaks, Go test -race, Flutter analyze/test, build APK)
├── apps/
│   ├── dashboard/              # Web Dashboard Pengurus RT & Admin Wilayah (Flutter Web)
│   ├── relawan/                # Aplikasi Mobile Relawan Lapangan (Flutter Android/iOS) - Skeleton
│   └── warga/                  # Aplikasi Mobile Warga (Flutter Android/iOS) - Skeleton
├── backend/
│   ├── cmd/
│   │   ├── weired/             # Entry point server utama (--mode=cloud|posko, --role=api|worker|all)
│   │   └── loadtest/           # CLI runner uji beban HTTP berkelanjutan (sustained) & serentak (burst)
│   ├── db/
│   │   ├── migrations/         # Skrip migrasi PostgreSQL berversi (000001–000009 up/down)
│   │   └── queries/            # Template kueri sqlc (jika digunakan)
│   ├── internal/               # Domain modules & platform (Clean Architecture)
│   │   ├── ai/                 # Adapter LLM (Gemini/Ollama) & sanitasi PII
│   │   ├── announcement/       # Siaran pengumuman darurat & penandatanganan Ed25519
│   │   ├── assembly/           # Manajemen titik kumpul evakuasi
│   │   ├── audit/              # Pencatatan jejak audit aktivitas sensitif
│   │   ├── auth/               # Autentikasi JWT, session, & middleware otorisasi (RBAC, RTScope)
│   │   ├── household/          # Data master rumah tangga, anggota keluarga, consent, enkripsi medis
│   │   ├── incident/           # Lifecycle insiden darurat, aktivasi siaga 2-langkah, mode latihan
│   │   ├── notify/             # Notifikasi eksternal (fcm, whatsapp)
│   │   ├── platform/           # Infrastruktur bersama (config, database, logger, server, metrics, jobs, ratelimit)
│   │   ├── posko/              # Posko Lokal offline, snapshot AES-256-GCM, push/pull kursor, self-signed TLS
│   │   ├── priority/           # Algoritma skoring prioritas U+V+W+N+D & rekalkulator berkala
│   │   ├── realtime/           # WebSocket event hub & bus pub-sub per insiden
│   │   ├── recap/              # Agregasi pasca-insiden, generator PDF (Maroto), CSV, FR-RCP-05
│   │   ├── region/             # Struktur wilayah administratif (RW, RT)
│   │   ├── relay/              # Codec paket biner BLE 46-byte & verifikasi HMAC-SHA256
│   │   ├── report/             # Ingest laporan status warga, deduplikasi, idempotensi
│   │   ├── sync/               # Sinkronisasi batch laporan relawan offline & rekonsiliasi
│   │   ├── synthetic/          # Generator data sintetis pengujian (penanda is_synthetic)
│   │   ├── task/               # State machine penugasan relawan evakuasi
│   │   └── volunteer/          # Data master relawan & asosiasi blok wilayah
│   ├── Dockerfile              # Multi-stage build container Go minimalis (Alpine)
│   ├── go.mod / go.sum         # Dependensi modul Go
│   └── .env.example            # Template variabel lingkungan
├── deploy/
│   ├── Caddyfile               # Konfigurasi reverse proxy Caddy (auto-HTTPS, WebSocket proxy, SPA fallback)
│   ├── docker-compose.cloud.yml# Stack produksi Cloud (Caddy + API + Worker + PostgreSQL 16)
│   ├── docker-compose.posko.yml# Stack offline Posko Lokal (API posko + PostgreSQL 16 + Ollama AI)
│   ├── k6/                     # Skrip pengujian beban k6 (300 laporan/menit/RT)
│   └── scripts/                # Prosedur backup & restore database (PowerShell & Bash)
├── docs/                       # Spesifikasi sistem (PRD, SRS, SDD, HRD, Developer Docs)
│   └── test-vectors/           # Vektor uji biner resmi (relay_packet.json, announcement.json)
├── firmware/
│   └── beacon/                 # Proyek PlatformIO C++ untuk firmware WE-IRED Beacon ESP32-S3 (Skeleton)
├── hardware/                   # Wiring, enclosure 3D print, BOM hardware (Dokumentasi)
├── packages/
│   ├── ble_relay/              # Paket Dart untuk protokol komunikasi BLE (Skeleton)
│   ├── content/                # Konten panduan P3K & edukasi luring berbasis JSON (Skeleton)
│   ├── core/                   # Shared Dart core: HTTP client, Drift SQLite DB, Outbox worker, Models
│   └── ui/                     # Design system, tema aksesibel, dan SharedLocationPickerMap (T-03)
├── melos.yaml                  # Konfigurasi workspace monorepo Dart/Flutter
└── pubspec.yaml                # Root pubspec untuk melos
```

---

## 2. ARSITEKTUR SISTEM

Sistem WE-IRED dirancang dengan prinsip **ketersediaan tinggi (high availability)**, **tahan gangguan jaringan (offline resilience)**, dan **privasi data ketat (privacy-first)**:

```
                          ┌─────────────────────────────┐
                          │   Cloud Server (VPS Publik) │
                          │   • API (Go)                │
                          │   • PostgreSQL 16           │
                          │   • Background Worker       │
                          │   • Caddy Auto-HTTPS        │
                          └──────────────┬──────────────┘
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 │ Sinkronisasi 2-Arah (Cursor Pull/Push)        │
                 │ Snapshot AES-256-GCM (Argon2id KDF)          │
                 ▼                                               ▼
┌─────────────────────────────┐                 ┌─────────────────────────────┐
│  Posko Lokal (Laptop/MiniPC)│                 │   Aplikasi Relawan & Warga  │
│  • Go Backend (--mode=posko)│                 │   • Drift Outbox SQLite     │
│  • PostgreSQL Lokal (5433)  │                 │   • BLE Relay 46-byte Mesh  │
│  • Self-Signed TLS (:8443)  │                 │   • Beacon Check-in (21-byte)│
│  • Ollama AI Lokal (:11434) │                 └─────────────────────────────┘
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│ WE-IRED Beacon (ESP32-S3)   │
│ • Titik Kumpul Evakuasi     │
│ • Iklan BLE & Buffer Laporan│
└─────────────────────────────┘
```

### A. Pola Arsitektur Backend (Go)
Backend mengadopsi varian **Domain-Driven Design (DDD) / Hexagonal Architecture**:
1. **Domain Models (`model.go`):** Struktur data inti, konstanta, dan enum domain murni tanpa dependensi I/O.
2. **Ports / Interfaces (`store.go`):** Kontrak abstraksi penyimpanan data (`Store`) dan ketergantungan antardomain.
3. **Business Logic (`service.go`):** Implementasi aturan bisnis, kalkulasi prioritas, validasi izin, dan orkestrasi peristiwa.
4. **Adapters / Handlers (`handler.go`):** Mengikat rute HTTP (Chi), mem-parsing request JSON, memvalidasi klaim autentikasi, dan memformat respons.
5. **Storage Adapters (`store_postgres.go` & `store_memory.go`):** Implementasi store untuk database PostgreSQL sesungguhnya (via `pgxpool`) serta fallback in-memory untuk pengujian cepat.

### B. Pola Arsitektur Frontend (Flutter Dashboard)
Dashboard pengurus dibangun dengan arsitektur **Feature-First**:
- Setiap modul berada di `apps/dashboard/lib/features/<nama_fitur>/` yang berisi:
  - `<fitur>_model.dart`: DTO dan representasi data lokal yang cocok 1:1 dengan payload backend.
  - `<fitur>_provider.dart`: State management berbasis `ChangeNotifier` yang memanggil `ApiClient` dari `package:core`.
  - `<fitur>_page.dart`: Antarmuka visual responsif menggunakan widget bersama dari `package:ui`.
- **Tidak ada duplikasi komponen peta:** Halaman Triase dan Data RT wajib mengimpor `SharedLocationPickerMap` dari `package:ui/ui.dart` (kontrak bersama T-03).

---

## 3. HUBUNGAN ANTARMODUL & ALUR DATA UTAMA

### A. Alur Laporan Masuk & Kalkulasi Prioritas
1. Laporan warga dikirimkan melalui aplikasi (HTTP), WhatsApp webhook, relawan (outbox sync), atau paket relay BLE (Joshua codec).
2. `report.Service` memvalidasi sequence number, channel pelaporan, dan idempotensi (menolak mutasi duplikat tanpa error).
3. Status rumah tangga diperbarui pada insiden aktif.
4. `priority.Recalculator` menghitung skor prioritas $P = U + V + W + N + D$:
   - $U$ (Urgensi medis/evakuasi): $0$ s/d $40$
   - $V$ (Bobot warga rentan lansia/disabilitas/balita): $0$ s/d $30$
   - $W$ (Waktu sejak pelaporan / keterlambatan): $0$ s/d $15$
   - $N$ (Kebutuhan logistik spesifik): $0$ s/d $10$
   - $D$ (Faktor bahaya zona/blok): $0$ s/d $5$
5. `realtime.Hub` menyiarkan event WebSocket `report_created` atau `status_updated` ke seluruh pengurus yang terhubung pada `/ws/{incident_id}`.

### B. Alur Perlindungan Privasi & Agregasi Regional (FR-RCP-05)
1. Seluruh data kesehatan warga disimpan terenkripsi di kolom `members.health_notes_enc` (AES-256-GCM).
2. Endpoint operasional RT (`/api/v1/rts/{rt}/*`) memvalidasi klaim JWT pengurus RT via middleware `auth.RequireRTScope()`. Pengurus RT 01 ditolak mengakses data RT 02.
3. Saat Admin Wilayah (RW/Kelurahan) memanggil endpoint agregat `/api/v1/regions/{id}/aggregate`:
   - Sistem melakukan rekapitulasi numerik murni (jumlah KK aman, butuh bantuan, jumlah lansia total, rumah belum terjangkau).
   - **Nama warga, nomor rumah, nomor telepon, dan catatan medis dibersihkan 100% dari respons JSON.**

### C. Alur Sinkronisasi Posko Lokal & Cloud (FR-PSK)
1. **Kondisi Terkoneksi (Online):**
   - Pengurus mengekspor snapshot master RT di Cloud via `POST /api/v1/posko/snapshot/export` dengan kata sandi pengurus.
   - Posko Lokal mengimpor snapshot via `POST /api/v1/posko/snapshot/import` menggunakan kata sandi yang sama.
2. **Kondisi Terputus (Offline Bencana):**
   - Posko Lokal berjalan mandiri dengan flag `--mode=posko`.
   - Laporan relawan, check-in beacon, dan triase lokal dicatat pada database lokal Posko.
   - Pekerjaan eksternal (pengiriman WhatsApp / FCM) diantrikan di tabel `jobs` lokal.
3. **Kondisi Rekoneksi (Online Kembali):**
   - Posko mengeksekusi `POST /api/v1/posko/push` mengirimkan event mutasi yang terjadi selama offline.
   - Cloud menerapkan mutasi secara idempoten. Jika terjadi deviasi status, sistem mencatat konflik pada tabel `sync_conflicts`.
   - Posko memanggil `GET /api/v1/posko/pull?cursor={last_id}` untuk menarik pembaruan dari Cloud.

---

## 4. STANDAR KODE & KONVENSI PENGEMBANGAN

### A. Standar Kode Go (Backend)
- **Format & Linting:** Kode harus lolos `golangci-lint` tanpa peringatan.
- **Error Handling:** Jangan mengembalikan error mentah ke klien HTTP. Gunakan builder standar dari `backend/internal/platform/errors`:
  ```go
  // Contoh penanganan error yang benar
  if err != nil {
      platformErrors.WriteJSON(w, http.StatusNotFound, "HOUSEHOLD_NOT_FOUND", "Data rumah tangga tidak ditemukan", nil)
      return
  }
  ```
- **Concurrency & Concurrency Safety:**
  - Struktur data in-memory yang diakses konkuren wajib dilindungi `sync.RWMutex` atau tipe atomik (`sync/atomic`).
  - Seluruh pengujian unit dan integrasi wajib dijalankan dengan race detector: `go test -race ./...`.
- **Format JSON Response:**
  - Sukses: `{"status": "success", "data": { ... }}`
  - Error: `{"status": "error", "error": {"code": "KODE_ERROR", "message": "Pesan deskriptif", "details": ...}}`

### B. Standar Kode Dart/Flutter (Frontend & Shared Packages)
- **Null-Safety & Immutability:** Gunakan tipe data eksplisit, hindari operator `!` tanpa pengecekan null sebelumnya.
- **Model Seragam:** Setiap model di `packages/core` wajib memiliki method `Map<String, dynamic> toJson()` dan factory constructor `fromJson(Map<String, dynamic> json)`.
- **Komponen UI Bersama:**
  - Status darurat menggunakan widget `StatusBadge` dari `package:ui/ui.dart`.
  - Pemilihan atau penandaan koordinat geografis menggunakan widget `SharedLocationPickerMap` dari `package:ui/ui.dart`. Jangan mengimpor `flutter_map` langsung di level fitur jika fungsionalitasnya sudah diakomodasi oleh shared widget.

---

## 5. PANDUAN MENAMBAH ATAU MENGUBAH FITUR

### A. Prosedur Menambah Endpoint Baru di Backend
1. **Tentukan Modul Domain:** Buka folder `backend/internal/<nama_modul>/`.
2. **Perbarui Interface Store (`store.go`):** Tambahkan method kueri yang diperlukan.
3. **Implementasikan di Postgres Store (`store_postgres.go`):** Tulis query SQL parameterized menggunakan pgxpool.
4. **Implementasikan di Memory Store (`store.go` atau file mock terkait):** Sediakan implementasi in-memory untuk pengujian otomatis.
5. **Tambahkan Logika Bisnis di Service (`service.go`):** Validasi masukan dan terapkan aturan bisnis.
6. **Ekspos Route di Handler (`handler.go`):**
   - Bind route pada method `Routes(r chi.Router)`.
   - Tambahkan middleware autentikasi `auth.Authenticate(h.jwtSecret)` atau otorisasi `auth.RequireRTScope()` jika endpoint terkait wilayah RT.
7. **Buat Unit/Integration Test:** Tulis pengujian di file `<nama_modul>_test.go`.

### B. Prosedur Mengubah Skema Basis Data (Database Migration)
> [!CAUTION]
> **JANGAN PERNAH MENGUBAH FILE MIGRASI YANG SUDAH DITERAPKAN DI REPOSITORI!**  
> Perubahan skema selalu dilakukan dengan menambahkan nomor urut migrasi baru.

1. Periksa nomor urut migrasi terakhir di `backend/db/migrations/` (saat ini `000009`).
2. Buat sepasang file migrasi baru:
   - `000010_<nama_perubahan>.up.sql`
   - `000010_<nama_perubahan>.down.sql`
3. Tulis DDL SQL yang kompatibel dengan PostgreSQL 16. Pastikan menyediakan skrip rollback (`down.sql`) yang menghapus tabel, kolom, atau indeks yang dibuat di `up.sql`.
4. Jalankan pengujian integritas migrasi:
   ```powershell
   cd backend
   go test -v ./internal/platform/database -run TestMigrationsIntegrity
   ```

### C. Prosedur Menambah Layar / Fitur di Dashboard Flutter
1. Buat folder baru di `apps/dashboard/lib/features/<nama_fitur>/`.
2. Buat DTO model, ChangeNotifier provider, dan StatelessWidget / StatefulWidget page.
3. Daftarkan provider di `apps/dashboard/lib/app/dashboard_shell.dart` atau `main.dart`.
4. Tambahkan rute navigasi pada `apps/dashboard/lib/app/routes.dart`.
5. Pastikan komponen lolos linting monorepo:
   ```bash
   melos run analyze
   ```
