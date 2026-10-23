# Deployment

**PIC:** Nopal

| Berkas (akan dibuat) | Kegunaan |
|---|---|
| `docker-compose.cloud.yml` | Caddy (TLS) + api + worker + PostgreSQL di VPS |
| `docker-compose.posko.yml` | api (mode posko) + PostgreSQL + Ollama (profil `ai`) di laptop posko |
| `Caddyfile` | Reverse proxy, TLS otomatis, penyajian Dashboard Web |

**Checklist Posko Lokal saat operasi:**
1. Impor snapshot RT dari cloud.
2. Nyalakan hotspot laptop/router portabel dengan SSID yang sama seperti konfigurasi beacon.
3. Jalankan `docker compose -f deploy/docker-compose.posko.yml up -d`.
4. Buka Dashboard Posko, lalu tampilkan QR konfigurasi untuk relawan.
5. Pastikan beacon muncul di halaman Beacon (sinkron < 1 menit).

Rincian: [SDD](../docs/SDD.md) Bagian 12.
