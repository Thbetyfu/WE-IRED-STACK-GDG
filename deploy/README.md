# WE-IRED Deployment Guide

**PIC:** Nopal  
**Referensi Teknis:** [SDD Bagian 12 & 13](../docs/SDD.md)

---

## 📦 Berkas Deployment

| Berkas | Deskripsi | Lingkungan |
|---|---|---|
| `docker-compose.cloud.yml` | Caddy (auto-HTTPS), backend API, asynchronous worker, PostgreSQL 16 | Cloud VPS / Server Publik |
| `docker-compose.posko.yml` | Backend API (mode posko, role all), PostgreSQL 16, Ollama AI (profil `ai`) | Laptop Posko / Mini PC Offline |
| `Caddyfile` | Reverse proxy, TLS otomatis, routing WebSocket `/ws/*`, SPA Web Dashboard | Cloud & Posko |
| `scripts/backup.sh` | Skrip backup harian `pg_dump` dengan kompresi gzip & SHA-256 | Cloud / Cron job |
| `scripts/restore.sh` | Skrip restore basis data dengan verifikasi checksum & validasi data | Disaster recovery |
| `k6/load_test_reports.js` | Skrip uji beban k6: 300 laporan/menit/RT pada 50 RT (15.000 laporan/menit) | Stress / Load test |

---

## 🚀 Panduan Eksekusi

### 1. Menjalankan Cloud Production / Staging
```bash
# Pastikan konfigurasi .env sesuai kebutuhan
cp ../backend/.env.example ../backend/.env

# Jalankan seluruh stack Cloud
docker compose -f docker-compose.cloud.yml up -d

# Periksa status kontainer
docker compose -f docker-compose.cloud.yml ps
```

### 2. Menjalankan Posko Lokal (Offline Standalone)
```bash
# Jalankan Posko Lokal tanpa internet
docker compose -f docker-compose.posko.yml up -d

# Jika ingin mengaktifkan modul AI lokal (Ollama):
docker compose -f docker-compose.posko.yml --profile ai up -d
```

### 3. Backup & Restore Database
```bash
# Backup
./scripts/backup.sh

# Restore
./scripts/restore.sh /backups/weired_backup_YYYYMMDD_HHMMSS.sql.gz
```

### 4. Menjalankan Pengujian Beban

WE-IRED membedakan 3 tingkatan pengujian performa (NFR-PERF-01: p95 ≤ 500 ms, target 300 laporan/menit/RT pada 50 RT = 250 RPS sustained):

1. **HTTP Loopback Benchmark (Client TCP, Router Chi, JWT Auth, JSON Ser/Deser):**
```bash
cd backend
# Mode sustained (250 RPS konstan = 15.000 laporan/menit)
go run ./cmd/loadtest -target=http -mode=sustained -rps=250 -duration=5

# Mode burst (15.000 laporan serentak melintasi 50 RT)
go run ./cmd/loadtest -target=http -mode=burst -rts=50 -reports=300
```
Hasil aktual:
- Sustained (250 RPS): p95 = 0.69 ms, error rate = 0.0% [TARGET ≤ 500 ms : PASS]
- Burst (15.000 concurrent): p95 = 6.15 ms, error rate = 0.0% [TARGET ≤ 500 ms : PASS]

2. **In-Memory Core Logic Benchmark (Kapasitas komputasi murni tanpa network I/O):**
```bash
cd backend && go run ./cmd/loadtest -target=internal -mode=burst -rts=50 -reports=300
```
Hasil: Throughput 128.800 req/sec, p95 = 1.57 ms.

3. **k6 Load Test terhadap Docker / Cloud Production:**
```bash
# Jalankan pada runner/lingkungan yang memiliki runtime k6 dan database PostgreSQL aktif
k6 run k6/load_test_reports.js
```
