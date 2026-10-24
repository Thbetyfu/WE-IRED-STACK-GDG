# WE-IRED Running The Project Guide

Panduan langkah-demi-langkah untuk menjalankan backend Go, basis data PostgreSQL, migrasi skema, Web Dashboard Flutter, orkestrasi Docker Compose Cloud & Posko Lokal, pengujian sistem, dan prosedur pemulihan bencana.

---

## 1. PRASYARAT SISTEM

Sebelum memulai, pastikan perangkat Anda telah terpasang perangkat lunak berikut:

| Alat / SDK | Versi Minimum | Kebutuhan Lingkungan | Status Ketersediaan di Host |
| :--- | :---: | :--- | :---: |
| **Go** | 1.22+ (Disarankan 1.23) | Backend API & Worker | **Tersedia** (`go.exe`) |
| **Git** | 2.40+ | Kontrol versi & hook Gitleaks | **Tersedia** (`git.exe`) |
| **Docker & Docker Compose** | v24+ & Compose v2+ | Kontainer Cloud & Posko Lokal | *Tergantung Host / BLOCKED di Windows lokal* |
| **Flutter SDK** | 3.22+ (stable) | Web Dashboard & Aplikasi Mobile | *Tergantung Host / BLOCKED di Windows lokal* |
| **Melos** | 6.0+ | Monorepo package management | *Diperlukan untuk Flutter* |
| **PlatformIO Core / IDE** | 6.1+ | Kompilasi Firmware ESP32-S3 | *Tergantung Host Joshua* |

---

## 2. MENJALANKAN BACKEND GO (LOKAL & STANDALONE)

Backend WE-IRED dirancang cerdas: dapat berjalan dengan PostgreSQL riil maupun beralih otomatis ke *in-memory degraded state* jika database belum menyala (sangat berguna untuk pengujian cepat).

### A. Persiapan Berkas Konfigurasi
Masuk ke direktori backend dan salin template konfigurasi:
```bash
cd backend
cp .env.example .env
```
*(Di Windows PowerShell: `Copy-Item .env.example .env`)*

### B. Menjalankan Server Utama
Jalankan server dengan mode Cloud dan seluruh peran subsistem aktif:
```bash
go run ./cmd/weired --mode=cloud --role=all
```
**Opsi CLI Flags yang Didukung:**
- `--config <path>`: Menentukan lokasi berkas `.env` kustom (default: `.env`).
- `--mode <cloud|posko>`: Mengesampingkan mode operasi.
- `--role <api|worker|all>`: Mengesampingkan peran subsistem.
- `--migrate=true`: Menjalankan migrasi basis data secara otomatis saat startup.

### C. Menjalankan dalam Mode Posko Lokal (Offline Standalone)
```bash
go run ./cmd/weired --mode=posko --role=all
```
*Saat dijalankan dalam mode posko, sistem otomatis membangkitkan sertifikat TLS self-signed internal dan mencetak sidik jari SHA-256 pada log terminal.*

### D. Verifikasi Keberhasilan Startup
Buka terminal baru atau browser dan jalankan pemeriksaan kesehatan (*health check*):
```bash
curl http://localhost:8080/healthz
```
*Respons Sukses:*
```json
{
  "status": "healthy",
  "mode": "cloud",
  "role": "all",
  "database": "connected",
  "uptime": "12.4s",
  "timestamp": "2026-10-24T13:30:00Z"
}
```
*(Catatan: Jika database belum aktif, field `"database"` akan bernilai `"disconnected"`, namun server tetap melayani request menggunakan memori internal).*

Untuk menghentikan server, tekan `Ctrl + C` (server akan melakukan *graceful shutdown* dalam 10 detik).

---

## 3. BASIS DATA & MIGRASI POSTGRESQL

### A. Menjalankan PostgreSQL Lokal via Docker
Jika Docker tersedia di perangkat Anda:
```bash
docker run --name weired-postgres -e POSTGRES_USER=weired -e POSTGRES_PASSWORD=weired -e POSTGRES_DB=weired -p 5432:5432 -d postgres:16-alpine
```

### B. Eksekusi Migrasi Skema (000001–000009)
Ada dua metode untuk menjalankan migrasi:

**Metode 1: Otomatis via Backend**
```bash
cd backend
go run ./cmd/weired --migrate=true
```

**Metode 2: Menggunakan CLI `golang-migrate`**
```bash
# Pastikan golang-migrate terpasang di sistem
migrate -path db/migrations -database "postgres://weired:weired@localhost:5432/weired?sslmode=disable" up
```

### C. Menghasilkan Data Sintetis Pengujian
Untuk menghasilkan data simulasi RT, 100 rumah tangga, warga rentan, dan relawan (FR-RCP & SDD 10.5):
```bash
# Lakukan POST ke endpoint generator sintetis (membutuhkan autentikasi Pengurus)
curl -X POST http://localhost:8080/api/v1/synthetic/generate \
  -H "Authorization: Bearer <TOKEN_PENGURUS>" \
  -H "Content-Type: application/json" \
  -d '{"rt_id": "rt-01", "households_count": 100}'
```

---

## 4. MENJALANKAN DASHBOARD OPERASIONAL (FLUTTER WEB)

Web Dashboard digunakan oleh Pengurus RT dan Admin Wilayah untuk memantau insiden, triase, rekapitulasi, dan sinkronisasi Posko.

### A. Bootstrap Dependensi Monorepo
Dari akar direktori repositori:
```bash
# Mengaktifkan Melos jika belum aktif
dart pub global activate melos

# Melakukan linking paket lokal (packages/core, packages/ui)
melos bootstrap
```

### B. Menjalankan Dashboard di Browser Chrome (Development)
```bash
cd apps/dashboard
flutter run -d chrome --web-port=8000
```
Akses aplikasi melalui browser: `http://localhost:8000`.

### C. Build Produksi Flutter Web
Untuk mengompilasi bundel statis web yang siap disajikan oleh Caddy:
```bash
cd apps/dashboard
flutter build web --release
```
Hasil kompilasi akan tersimpan di direktori `apps/dashboard/build/web`.

---

## 5. STATUS APLIKASI MOBILE & FIRMWARE

### A. Aplikasi Warga & Relawan (`apps/warga` & `apps/relawan`)
- **Status Saat Ini:** **Skeleton / In Progress (Tanggung jawab Thoriq)**.
- Struktur folder dan dependensi model telah diselaraskan melalui `packages/core`.
- Perintah eksekusi saat pengembangan mobile selesai:
  ```bash
  # Menjalankan aplikasi Warga di emulator/HP Android
  cd apps/warga && flutter run -d android

  # Menjalankan aplikasi Relawan di emulator/HP Android
  cd apps/relawan && flutter run -d android
  ```

### B. Firmware WE-IRED Beacon (`firmware/beacon`)
- **Status Saat Ini:** **Skeleton / In Progress (Tanggung jawab Joshua)**.
- Perintah kompilasi dan upload firmware ke board ESP32-S3 via PlatformIO:
  ```bash
  cd firmware/beacon
  pio run -t upload
  ```

---

## 6. ORKESTRASI DOCKER COMPOSE

### A. Cloud Stack Produksi (`deploy/docker-compose.cloud.yml`)
Menjalankan Caddy Auto-HTTPS, Backend API, Asynchronous Job Worker, dan PostgreSQL 16:
```bash
cd deploy
docker compose -f docker-compose.cloud.yml up -d
```
**Pemeriksaan Status Kontainer:**
```bash
docker compose -f docker-compose.cloud.yml ps
```
**Melihat Log Layanan:**
```bash
docker compose -f docker-compose.cloud.yml logs -f api
```
**Menghentikan Layanan:**
```bash
docker compose -f docker-compose.cloud.yml down
```

### B. Posko Lokal Offline Stack (`deploy/docker-compose.posko.yml`)
Menjalankan stack mandiri untuk posko di lapangan tanpa internet:
```bash
cd deploy
docker compose -f docker-compose.posko.yml up -d
```
**Menjalankan dengan Profil AI Lokal (Ollama LLM):**
```bash
docker compose -f docker-compose.posko.yml --profile ai up -d
```

---

## 7. EKSEKUSI PENGUJIAN SISTEM LENGKAP

### A. Unit & Integration Test Backend dengan Race Detector
```powershell
cd backend
go test -race -count=1 ./...
```
*Indikator Sukses:* Seluruh 29 package backend berstatus `ok` tanpa laporan *DATA RACE*.

### B. Uji Skenario Penerimaan Sistem (AC-01 s/d AC-11)
```powershell
cd backend
go test -v -count=1 ./internal/integration
```
*Indikator Sukses:* Seluruh `TestAC01` hingga `TestAC11` berstatus `PASS`.

### C. Pengujian Beban Laporan Darurat (NFR-PERF-01)
Target spesifikasi: **300 laporan/menit per RT pada 50 RT** (setara 250 req/sec sustained, latensi $p95 \le 500\text{ ms}$).

```powershell
cd backend

# 1. Uji Beban Berkelanjutan HTTP Loopback (250 RPS stabil)
go run ./cmd/loadtest -target=http -mode=sustained -rps=250 -duration=5

# 2. Uji Beban Lonjakan Serentak HTTP Loopback (15.000 request paralel)
go run ./cmd/loadtest -target=http -mode=burst -rts=50 -reports=300

# 3. Uji Beban Skrip k6 (memerlukan k6 CLI)
k6 run ../deploy/k6/load_test_reports.js
```

---

## 8. PROSEDUR BACKUP DAN RESTORE DATABASE

Tersedia skrip pemulihan bencana otomatis di folder `deploy/scripts/`:

### A. Backup Basis Data
**Di Windows (PowerShell):**
```powershell
.\deploy\scripts\backup.ps1 -DbHost localhost -DbPort 5432 -DbUser weired_user -DbName weired_db
```
**Di Linux / macOS (Bash):**
```bash
./deploy/scripts/backup.sh
```
*Skrip akan menghasilkan berkas `.sql` terkompresi beserta berkas sidik jari SHA-256 (`.sha256`).*

### B. Restore Basis Data
**Di Windows (PowerShell):**
```powershell
.\deploy\scripts\restore.ps1 -BackupFile ./backups/weired_backup_YYYYMMDD_HHMMSS.sql
```
**Di Linux / macOS (Bash):**
```bash
./deploy/scripts/restore.sh /backups/weired_backup_YYYYMMDD_HHMMSS.sql.gz
```
*Skrip otomatis memverifikasi kecocokan SHA-256 sebelum melakukan impor tabel.*
