# WE-IRED Configuration Reference

Katalog lengkap variabel konfigurasi, berkas setelan, port jaringan, dependensi sistem, endpoint API, dan tata kelola secret untuk repositori **WE-IRED-STACK-GDG**.

---

## 1. KATALOG VARIABEL ENVIRONMENT

Konfigurasi backend dibaca melalui berkas `backend/.env` atau variabel lingkungan proses (`os.Getenv`), diinisialisasi melalui struct `Config` di [`backend/internal/platform/config/config.go`](file:///c:/Users/gresn/Documents/Lomba/Hackathon%20GDG%20ITB/Project_Hackathon/WE-IRED-STACK-GDG/backend/internal/platform/config/config.go).

### A. Konfigurasi Inti Platform

| Variabel | Wajib/Opsional | Nilai Default | Format / Contoh | Keterangan & Dampak Perubahan |
| :--- | :---: | :---: | :--- | :--- |
| `MODE` | **Wajib** | `cloud` | `cloud` \| `posko` | Menentukan lingkungan operasi sistem. Mode `posko` mengaktifkan pembangkitan sertifikat TLS self-signed, kursor sinkronisasi offline, dan penundaan pengiriman WA/FCM ke antrean lokal. |
| `ROLE` | **Wajib** | `all` | `api` \| `worker` \| `all` | Menentukan subsistem yang berjalan dalam proses. `api` hanya melayani HTTP/WebSocket. `worker` hanya menjalankan background processor (job queue, rekalkulasi prioritas). `all` menjalankan keduanya (standar development). |
| `HTTP_ADDR` | **Wajib** | `:8080` | `:8080` atau `0.0.0.0:8080` | Port listen server HTTP/WebSocket. Jika diubah, pemetaan port Docker Compose dan konfigurasi reverse proxy Caddy harus disesuaikan. |
| `PUBLIC_BASE_URL` | Opsional | *(kosong)* | `https://api.we-ired.id` | URL publik server backend. Digunakan untuk menyusun webhook WhatsApp dan tautan unduhan dokumen laporan PDF eksternal. |
| `LOG_LEVEL` | Opsional | `info` | `debug` \| `info` \| `warn` \| `error` | Tingkat keparahan logging terstruktur JSON. Nilai `debug` mencetak detail payload HTTP dan kueri database (tanpa secret). |
| `DATABASE_URL` | **Wajib (Prod)** | `postgres://weired:weired@localhost:5432/weired?sslmode=disable` | PostgreSQL DSN | String koneksi basis data. Jika koneksi gagal saat startup, backend secara otomatis beralih ke *degraded state* menggunakan in-memory store untuk kebutuhan pengujian lokal. |

---

### B. Kriptografi & Tata Kelola Secret

> [!CAUTION]
> **JANGAN PERNAH MENG-COMMIT SECRET NYATA KE DALAM GIT!**  
> Gunakan nilai acak kriptografis yang dihasilkan secara aman pada setiap mesin produksi.

| Variabel | Wajib/Opsional | Format | Contoh Aman | Dampak Perubahan / Fungsi |
| :--- | :---: | :--- | :--- | :--- |
| `JWT_SECRET` | **Wajib (Prod)** | String acak ($\ge 32$ karakter) | `rahasia-jwt-weired-min-32-karakter-acak!` | Kunci penandatanganan token JWT (HS256) untuk sesi Pengurus RT, Relawan, dan Admin Wilayah. Jika diubah, seluruh token aktif menjadi tidak valid (*logged out*). |
| `DATA_KEY` | **Wajib (Prod)** | 32-byte Base64 atau string | `MDEyMzQ1Njc4OTAxMjM0NTY3ODkwMTIzNDU2Nzg5MDE=` | Kunci simetris AES-256-GCM untuk mengenkripsi data sensitif: catatan medis warga (`health_notes_enc`), kunci rumah (`key_enc`), dan secret beacon (`secret_enc`). **JIKA HILANG ATAU DIUBAH, DATA TERENKRIPSI DI DATABASE TIDAK DAPAT DIDEKRIPSI KEMBALI.** |
| `ANNOUNCE_SIGNING_KEY` | Opsional (Cloud) | Base64 Ed25519 Private Key (64 byte) | `KunciPrivatEd25519Base64...` | Kunci privat untuk menandatangani siaran pengumuman darurat (FR-ANN). HP warga dan beacon memverifikasi tanda tangan ini menggunakan kunci publik sebelum menampilkan pengumuman. |

---

### C. WhatsApp Cloud API (Meta Graph API v21.0)

| Variabel | Wajib/Opsional | Nilai Default | Format / Contoh | Keterangan & Dampak Perubahan |
| :--- | :---: | :---: | :--- | :--- |
| `WA_PHONE_NUMBER_ID` | Opsional | *(kosong)* | `109283746592831` | ID nomor telepon resmi dari Meta Business Manager untuk pengiriman notifikasi warga. |
| `WA_ACCESS_TOKEN` | Opsional | *(kosong)* | `EAAx...` (System User Token) | Token akses Meta Graph API dengan izin `whatsapp_business_messaging`. Jika kosong, sistem otomatis beralih ke *Simulated WhatsApp Client*. |
| `WA_APP_SECRET` | Opsional | *(kosong)* | `3a9b1c7d...` | Kunci rahasia aplikasi Meta untuk memvalidasi header tanda tangan webhook `X-Hub-Signature-256` (HMAC-SHA256). |
| `WA_VERIFY_TOKEN` | Opsional | *(kosong)* | `weired-wa-verify-token-2026` | Token verifikasi saat mendaftarkan webhook URL di dashboard Meta for Developers. |
| `WA_REMINDER_MINUTES` | Opsional | `10,25` | Angka dipisah koma | Menit keterlambatan pengingat T+10 dan T+25 untuk rumah tangga yang belum melapor sejak siaga diaktifkan (FR-WA-06). |

---

### D. Notifikasi Push (Firebase Cloud Messaging - FCM)

| Variabel | Wajib/Opsional | Format | Contoh | Keterangan & Dampak Perubahan |
| :--- | :---: | :--- | :--- | :--- |
| `FCM_CREDENTIALS_FILE` | Opsional | Path absolut/relatif file JSON | `/etc/weired/fcm-service-account.json` | Berkas service account Google Firebase untuk mengirim push notification siaga ke HP Android warga. Jika tidak diset, notifikasi push dialihkan ke log simulator. |

---

### E. Kecerdasan Buatan (AI Assistant & LLM)

| Variabel | Wajib/Opsional | Nilai Default | Format / Contoh | Keterangan & Dampak Perubahan |
| :--- | :---: | :---: | :--- | :--- |
| `AI_ENABLED` | Opsional | `false` | `true` \| `false` | Saklar global fitur ringkasan laporan dan draf rekap AI. Tetap tunduk pada saklar per-RT (`rts.ai_consent`). |
| `OLLAMA_URL` | Opsional | `http://localhost:11434` | URL HTTP | Alamat server Ollama lokal untuk inferensi model luring (standar Posko Lokal tanpa internet). |
| `OLLAMA_MODEL` | Opsional | `llama3.2:3b` | Nama model Ollama | Model LLM lokal yang digunakan. |
| `GEMINI_API_KEY` | Opsional | *(kosong)* | `AIzaSy...` | Kunci API Google Gemini untuk inferensi AI di Cloud server. |
| `GEMINI_MODEL` | Opsional | `gemini-1.5-flash` | Model identifier | Model Gemini yang digunakan (default: `gemini-1.5-flash`). |

---

### F. Integrasi Peringatan Dini (BMKG) & Operasi Posko

| Variabel | Wajib/Opsional | Nilai Default | Format / Contoh | Keterangan & Dampak Perubahan |
| :--- | :---: | :---: | :--- | :--- |
| `BMKG_POLL_INTERVAL` | Opsional | `5m` | String durasi Go (`1m`, `5m`) | Interval polling feed peringatan dini gempa dan tsunami BMKG. |
| `POSKO_ID` | Wajib jika `MODE=posko` | *(kosong)* | `posko-rw05-01` | Identitas unik instans Posko Lokal untuk pencatatan jejak audit dan rekonsiliasi kursor sinkronisasi. |
| `CLOUD_SYNC_URL` | Opsional (Posko) | *(kosong)* | `https://api.we-ired.id` | Alamat endpoint Cloud server tujuan saat melakukan push/pull event sinkronisasi ketika internet tersedia. |

---

## 2. DAFTAR BERKAS KONFIGURASI PROYEK

| Lokasi Berkas | Tujuan Konfigurasi | Lingkungan |
| :--- | :--- | :--- |
| [`backend/.env.example`](file:///c:/Users/gresn/Documents/Lomba/Hackathon%20GDG%20ITB/Project_Hackathon/WE-IRED-STACK-GDG/backend/.env.example) | Template berkas environment lengkap tanpa data rahasia | Panduan Developer |
| `backend/.env` | Konfigurasi aktif proses backend (tidak di-commit) | Lokal / Dev |
| [`deploy/docker-compose.cloud.yml`](file:///c:/Users/gresn/Documents/Lomba/Hackathon%20GDG%20ITB/Project_Hackathon/WE-IRED-STACK-GDG/deploy/docker-compose.cloud.yml) | Orkestrasi container Cloud (Caddy, API, Worker, PostgreSQL 16) | Cloud Staging / Prod |
| [`deploy/docker-compose.posko.yml`](file:///c:/Users/gresn/Documents/Lomba/Hackathon%20GDG%20ITB/Project_Hackathon/WE-IRED-STACK-GDG/deploy/docker-compose.posko.yml) | Orkestrasi container Posko Lokal mandiri (API posko, PostgreSQL lokal, Ollama) | Posko Offline |
| [`deploy/Caddyfile`](file:///c:/Users/gresn/Documents/Lomba/Hackathon%20GDG%20ITB/Project_Hackathon/WE-IRED-STACK-GDG/deploy/Caddyfile) | Reverse proxy, terminasi TLS otomatis, routing WebSocket `/ws/*`, SPA Web Dashboard | Cloud & Posko |
| [`melos.yaml`](file:///c:/Users/gresn/Documents/Lomba/Hackathon%20GDG%20ITB/Project_Hackathon/WE-IRED-STACK-GDG/melos.yaml) | Konfigurasi monorepo Flutter & skrip multi-paket (`analyze`, `test`) | Workspace Flutter |

---

## 3. KATALOG PORT JARINGAN

| Port | Layanan | Protokol | Lingkungan | Keterangan |
| :---: | :--- | :---: | :---: | :--- |
| **8080** | Backend API & WebSocket | HTTP/WS | Cloud / Posko | Port aplikasi utama backend Go. |
| **8443** | Posko Self-Signed HTTPS | HTTPS/WSS | Posko Lokal | Port aman lokal dengan sertifikat TLS internal dan sidik jari SHA-256 (FR-PSK-04). |
| **5432** | PostgreSQL Database | TCP | Cloud / Host Dev | Port basis data PostgreSQL Cloud standar. |
| **5433** | PostgreSQL Posko | TCP | Posko Lokal | Port basis data lokal pada Posko (agar tidak bentrok dengan PostgreSQL lokal host). |
| **11434**| Ollama Local LLM | HTTP | Posko Lokal / Dev | Endpoint REST server AI lokal. |
| **80**   | Caddy HTTP | HTTP | Cloud / Prod | Dialihkan otomatis ke HTTPS oleh Caddy. |
| **443**  | Caddy HTTPS | HTTPS | Cloud / Prod | Titik masuk lalu lintas publik terenkripsi otomatis (Let's Encrypt / ZeroSSL). |

---

## 4. KATALOG ENDPOINT API RESMI (`/api/v1`)

Seluruh endpoint domain dipasang dengan prefiks `/api/v1` (kecuali endpoint observabilitas root):

### Observabilitas & Webhook Root
- `GET /healthz` — Status kesehatan server, konektivitas database, uptime, dan mode.
- `GET /metrics` — Metrik standar Prometheus (durasi request, total laporan, counter).
- `GET /webhook/whatsapp` — Verifikasi tantangan (*challenge verification*) webhook Meta.
- `POST /webhook/whatsapp` — Penerimaan pesan inbound WhatsApp (Status 'Aman', tombol 'Butuh Bantuan').

### Autentikasi (`/api/v1/auth`)
- `POST /api/v1/auth/request-otp` — Permintaan kode OTP login via SMS/WhatsApp.
- `POST /api/v1/auth/verify-otp` — Verifikasi OTP dan penerbitan JWT access token.
- `POST /api/v1/auth/refresh` — Pembaruan access token menggunakan refresh token.

### Wilayah, Warga & Titik Kumpul (`/api/v1/rts/{rt}/*`)
- `GET /api/v1/rts/{rt}/households` — Daftar rumah tangga dan status verifikasi NIK.
- `POST /api/v1/rts/{rt}/households` — Pendaftaran rumah tangga baru.
- `POST /api/v1/rts/{rt}/households/import-csv` — Impor massal data rumah via CSV.
- `GET /api/v1/rts/{rt}/assembly-points` — Titik kumpul evakuasi terdaftar beserta kapasitasnya.
- `GET /api/v1/rts/{rt}/volunteers` — Daftar relawan aktif dan penugasan blok.
- `GET /api/v1/rts/{rt}/audit-logs` — Jejak audit akses data sensitif per RT.

### Insiden & Pelaporan Darurat (`/api/v1/incidents/*`)
- `POST /api/v1/incidents/draft` — Inisiasi draf aktivasi siaga (langkah 1).
- `POST /api/v1/incidents/confirm` — Konfirmasi aktivasi siaga dengan token (langkah 2).
- `POST /api/v1/incidents/direct` — Aktivasi langsung mode latihan tanpa konfirmasi ganda.
- `POST /api/v1/incidents/{id}/reports` — Ingest laporan status rumah (Aman, Titik Kumpul, Butuh Bantuan).
- `GET /api/v1/incidents/{id}/households` — Tabel triase real-time terurut skor prioritas.
- `GET /api/v1/incidents/{id}/unreported` — Daftar rumah yang belum melapor (urut kerentanan).
- `POST /api/v1/incidents/{id}/end` — Pengakhiran masa siaga bencana oleh pengurus.

### Realtime & Sinkronisasi (`/api/v1/ws/*` & `/api/v1/posko/*`)
- `GET /api/v1/ws/{incident_id}` — Endpoint WebSocket event pub-sub (mendukung pemulihan `last_event_id`).
- `GET /api/v1/posko/status` — Status mode posko, kursor sinkronisasi, dan pending queue.
- `POST /api/v1/posko/snapshot/export` — Ekspor snapshot terenkripsi AES-256-GCM (Argon2id KDF).
- `POST /api/v1/posko/snapshot/import` — Impor snapshot terenkripsi ke database lokal.
- `GET /api/v1/posko/pull` — Penarikan mutasi data dari Cloud berbasis kursor.
- `POST /api/v1/posko/push` — Pengiriman mutasi event lokal ke Cloud.
- `POST /api/v1/posko/conflicts/{id}/resolve` — Resolusi manual atas konflik data offline.

### Rekapitulasi & Pasca-Bencana (`/api/v1/recaps/*`)
- `POST /api/v1/incidents/{id}/recap` — Agregasi laporan, verifikasi pengurus, catatan resmi.
- `GET /api/v1/recaps/{id}/pdf` — Unduh dokumen PDF resmi pasca-insiden (Maroto engine).
- `GET /api/v1/recaps/{id}/csv` — Ekspor data tabular rekapitulasi.
- `GET /api/v1/regions/{id}/aggregate` — Agregat multi-RT untuk Admin Wilayah (FR-RCP-05: zero medical PII).
