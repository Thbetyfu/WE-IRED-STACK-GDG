# WE-IRED Troubleshooting Guide

Panduan pemecahan masalah (*troubleshooting*) komprehensif untuk pengembang dan operator sistem **WE-IRED-STACK-GDG**. Setiap skenario mencakup **gejala**, **kemungkinan penyebab**, **cara memeriksa log**, **langkah perbaikan langkah-demi-langkah**, dan **cara memverifikasi bahwa masalah telah terselesaikan**.

---

## MATRIKS DIAGNOSIS CEPAT

| Kategori Masalah | Gejala Utama | Bagian Rujukan |
| :--- | :--- | :---: |
| **Database & Migrasi** | Backend log: `database ping failed`, atau migrasi error `dirty database` | [Bagian 1](#1-masalah-basis-data--migrasi) |
| **Port & Jaringan** | Error startup: `bind: address already in use` (8080, 5432, 8443) | [Bagian 2](#2-masalah-port-bentrok--jaringan) |
| **Autentikasi & RBAC** | Respons HTTP `401 Unauthorized` atau `403 Forbidden` pada rute `/rts/*` | [Bagian 3](#3-masalah-autentikasi--otorisasi) |
| **Environment** | Error startup: `konfigurasi DATABASE_URL wajib diisi` atau `.env` diabaikan | [Bagian 4](#4-masalah-konfigurasi--environment) |
| **Sinkronisasi Posko** | Error saat impor snapshot: `kata sandi enkripsi snapshot tidak valid` | [Bagian 5](#5-masalah-posko-lokal--sinkronisasi-offline) |
| **Sertifikat TLS Posko** | Browser/App menolak koneksi HTTPS ke Posko Lokal (`ERR_CERT_AUTHORITY_INVALID`) | [Bagian 6](#6-masalah-sertifikat-https-posko) |
| **WhatsApp Webhook** | Meta webhook ditolak HTTP 401 atau pesan masuk tidak memicu perubahan status | [Bagian 7](#7-masalah-whatsapp-cloud-api--webhook) |
| **WebSocket & Realtime**| Dashboard terputus atau tidak menerima pembaruan status laporan secara langsung | [Bagian 8](#8-masalah-websocket--real-time-hub) |
| **Docker & Kontainer** | Container PostgreSQL gagal lolos healthcheck (`unhealthy`), API crash loop | [Bagian 9](#9-masalah-docker--kontainer) |
| **Flutter & Toolchain** | Perintah `flutter` atau `dart` tidak dikenali (`CommandNotFoundException`) | [Bagian 10](#10-masalah-lingkungan-flutter--melos) |

---

## 1. MASALAH BASIS DATA & MIGRASI

### Kasus 1.1: Koneksi PostgreSQL Gagal (`database ping failed`)
* **Gejala:**  
  Log backend mencetak pesan peringatan:
  ```text
  WARN database connection pool initialization error error="dial tcp [::1]:5432: connectex: No connection could be made because the target machine actively refused it."
  INFO using in-memory domain stores
  ```
* **Penyebab:**  
  Layanan PostgreSQL lokal belum berjalan atau port 5432 belum siap menerima koneksi TCP.
* **Langkah Perbaikan:**
  1. Periksa apakah kontainer PostgreSQL berjalan:
     ```bash
     docker ps | grep postgres
     ```
  2. Jika belum berjalan, jalankan via Docker:
     ```bash
     docker compose -f deploy/docker-compose.cloud.yml up -d postgres
     ```
  3. Uji koneksi manual:
     ```bash
     pg_isready -h localhost -p 5432 -U weired_user -d weired_db
     ```
* **Verifikasi Sukses:**  
  Restart backend dan periksa log: `INFO connected to PostgreSQL successfully`. Endpoint `GET /healthz` harus mengembalikan `"database": "connected"`.

---

### Kasus 1.2: Status Migrasi Kotor (*Dirty Database*)
* **Gejala:**  
  Eksekusi migrasi gagal dengan pesan: `Dirty database version X. Fix and force version`.
* **Penyebab:**  
  Salah satu skrip migrasi SQL mengalami galat di tengah jalan saat transaksi belum selesai.
* **Langkah Perbaikan:**
  1. Periksa tabel `schema_migrations`:
     ```sql
     SELECT version, dirty FROM schema_migrations;
     ```
  2. Perbaiki sintaks SQL yang bermasalah pada file migrasi di `backend/db/migrations/`.
  3. Paksa versi migrasi kembali ke versi bersih terakhir menggunakan `golang-migrate`:
     ```bash
     migrate -path backend/db/migrations -database "$DATABASE_URL" force <VERSI_BERSIH_SEBELUMNYA>
     ```
  4. Jalankan kembali migrasi:
     ```bash
     migrate -path backend/db/migrations -database "$DATABASE_URL" up
     ```
* **Verifikasi Sukses:**  
  Jalankan `SELECT dirty FROM schema_migrations;` dan pastikan nilainya bernilai `f` (false).

---

## 2. MASALAH PORT BENTROK & JARINGAN

### Kasus 2.1: Port 8080 atau 5432 Sedang Digunakan
* **Gejala:**  
  Backend atau Docker Compose gagal memulai proses dengan pesan:
  ```text
  listen tcp :8080: bind: address already in use
  ```
* **Langkah Perbaikan:**
  **Di Windows (PowerShell):**
  1. Cari PID proses yang menguasai port:
     ```powershell
     Get-NetTCPConnection -LocalPort 8080 | Select-Object OwningProcess
     ```
  2. Hentikan proses tersebut:
     ```powershell
     Stop-Process -Id <PID> -Force
     ```
  **Di Linux / macOS:**
  1. Cari dan bunuh proses:
     ```bash
     lsof -i :8080 -t | xargs kill -9
     ```
  2. Atau ubah konfigurasi port di `backend/.env` menjadi `HTTP_ADDR=:8081`.
* **Verifikasi Sukses:**  
  Jalankan kembali backend dan pastikan tidak ada error *bind address*.

---

## 3. MASALAH AUTENTIKASI & OTORISASI

### Kasus 3.1: Token Ditolak (`401 Unauthorized`)
* **Gejala:**  
  Permintaan API mengembalikan:
  ```json
  {"status": "error", "error": {"code": "UNAUTHORIZED", "message": "Token akses tidak valid atau sudah kedaluwarsa"}}
  ```
* **Penyebab:**  
  Token JWT melebihi masa berlaku (15 menit per `auth.AccessTokenDuration`) atau `JWT_SECRET` pada backend telah diganti setelah token diterbitkan.
* **Langkah Perbaikan:**
  1. Periksa header request: pastikan terdapat `Authorization: Bearer <token>`.
  2. Perbarui token menggunakan refresh token:
     ```bash
     curl -X POST http://localhost:8080/api/v1/auth/refresh -H "Content-Type: application/json" -d '{"refresh_token": "..."}'
     ```
  3. Jika gagal, minta OTP login baru melalui `POST /api/v1/auth/request-otp`.

---

### Kasus 3.2: Penolakan Akses Lintas-RT (`403 Forbidden`)
* **Gejala:**  
  Pengurus RT 01 mencoba mengakses data RT 02 dan menerima:
  ```json
  {"status": "error", "error": {"code": "FORBIDDEN", "message": "Anda tidak memiliki kewenangan untuk mengakses data RT ini"}}
  ```
* **Penyebab:**  
  Ini adalah **perilaku keamanan sistem yang diharapkan (security by design)**. Middleware `auth.RequireRTScope()` mencegah kebocoran data antar-RT.
* **Langkah Perbaikan:**
  Pastikan pengurus melakukan request ke wilayah RT miliknya sendiri (`/api/v1/rts/{rt_sendiri}/*`). Jika pengguna adalah Admin Wilayah (RW), pastikan token memiliki peran `admin_wilayah` yang mencakup sub-wilayah RT target.

---

## 4. MASALAH KONFIGURASI & ENVIRONMENT

### Kasus 4.1: Nilai `.env` Tidak Terbaca
* **Gejala:**  
  Konfigurasi selalu kembali ke nilai bawaan (*default*).
* **Penyebab:**  
  File `.env` tidak diletakkan di direktori kerja saat menjalankan biner, atau flag `--config` tidak diarahkan dengan benar.
* **Langkah Perbaikan:**
  1. Pastikan file `.env` berada tepat di folder `backend/.env` jika menjalankan dari folder `backend/`.
  2. Jika biner dijalankan dari root monorepo, sertakan flag:
     ```bash
     go run ./backend/cmd/weired --config=./backend/.env
     ```
  3. Pastikan tidak ada spasi di sekitar tanda `=` pada file `.env`.

---

## 5. MASALAH POSKO LOKAL & SINKRONISASI OFFLINE

### Kasus 5.1: Gagal Dekripsi Snapshot Posko (`ErrInvalidSnapshotPassword`)
* **Gejala:**  
  Endpoint `POST /api/v1/posko/snapshot/import` mengembalikan HTTP 400:
  ```json
  {"status": "error", "error": {"code": "INVALID_PASSWORD", "message": "kata sandi enkripsi snapshot tidak valid (dekripsi GCM gagal)"}}
  ```
* **Penyebab:**  
  1. Kata sandi yang dimasukkan pengurus posko berbeda dari kata sandi saat snapshot diekspor di Cloud.
  2. Berkas snapshot terkorupsi saat dipindahkan via flashdisk (tag autentikasi AES-256-GCM tidak cocok).
* **Langkah Perbaikan:**
  1. Konfirmasikan kata sandi kepada pengurus RT yang mengekspor snapshot.
  2. Ekspor ulang snapshot dari Cloud jika berkas fisik terkorupsi:
     ```bash
     curl -X POST http://cloud-server:8080/api/v1/posko/snapshot/export \
       -H "Authorization: Bearer <TOKEN>" \
       -d '{"rt_id": "rt-01", "password": "PasswordSama123!"}'
     ```

---

### Kasus 5.2: Konflik Sinkronisasi Tertunda (*Sync Conflicts*)
* **Gejala:**  
  Log Posko menunjukkan mutasi event tidak bertambah di Cloud dan tercatat di tabel `sync_conflicts`.
* **Langkah Perbaikan:**
  1. Buka halaman Posko di Dashboard Web (`/posko`).
  2. Periksa tabel **Daftar Konflik Sinkronisasi**.
  3. Lakukan resolusi manual menggunakan salah satu strategi (`cloud_wins`, `posko_wins`, atau `merged`):
     ```bash
     curl -X POST http://localhost:8080/api/v1/posko/conflicts/<CONFLICT_ID>/resolve \
       -H "Authorization: Bearer <TOKEN_PENGURUS>" \
       -d '{"resolution_strategy": "posko_wins"}'
     ```

---

## 6. MASALAH SERTIFIKAT HTTPS POSKO

### Kasus 6.1: Peringatan Sertifikat Self-Signed di Browser
* **Gejala:**  
  Saat mengakses `https://192.168.4.1:8443`, browser menampilkan `Your connection is not private`.
* **Penyebab:**  
  Posko Lokal membangkitkan sertifikat ECDSA mandiri tanpa otoritas sertifikat (CA) publik karena laptop posko tidak terhubung ke internet untuk validasi Let's Encrypt (FR-PSK-04 & NFR-SEC-01).
* **Langkah Perbaikan:**
  1. **Untuk Pengurus di Browser:** Klik *Advanced* $\to$ *Proceed to 192.168.4.1 (unsafe)*.
  2. **Untuk Relawan:** Buka menu Posko di Aplikasi Relawan dan **pindai QR Konfigurasi Posko** dari dashboard. Aplikasi relawan secara otomatis menyimpan sidik jari SHA-256 (*fingerprint pinning*) sehingga koneksi HTTPS diterima secara aman tanpa perlu CA publik.

---

## 7. MASALAH WHATSAPP CLOUD API & WEBHOOK

### Kasus 7.1: Tanda Tangan Webhook Gagal (`INVALID_SIGNATURE`)
* **Gejala:**  
  Log backend mencetak: `WARN invalid whatsapp webhook signature`. Permintaan Meta ditolak HTTP 401.
* **Penyebab:**  
  Nilai `WA_APP_SECRET` di `.env` tidak sesuai dengan *App Secret* pada Meta App Dashboard.
* **Langkah Perbaikan:**
  1. Buka Meta for Developers $\to$ App Settings $\to$ Basic.
  2. Salin *App Secret* dan tempelkan pada `WA_APP_SECRET` di berkas `.env`.
  3. Pastikan tidak ada karakter spasi atau newline yang tidak sengaja tersalin.
  4. Restart server backend.

---

## 8. MASALAH WEBSOCKET & REAL-TIME HUB

### Kasus 8.1: Dashboard Tidak Menerima Pembaruan Laporan
* **Gejala:**  
  Laporan masuk di database, namun tabel Triase di dashboard tidak bergeser secara real-time.
* **Pemeriksaan:**
  1. Buka Developer Tools di browser (F12) $\to$ tab *Console* atau *Network* $\to$ filter *WS*.
  2. Periksa apakah status WebSocket `/api/v1/ws/{incident_id}` adalah `101 Switching Protocols` atau `Disconnected`.
* **Langkah Perbaikan:**
  1. Jika menggunakan reverse proxy Caddy / Nginx, pastikan header upgrade WebSocket diteruskan:
     ```caddy
     @websockets {
         header Connection *Upgrade*
         header Upgrade websocket
     }
     reverse_proxy @websockets api:8080
     ```
  2. Jika koneksi sempat terputus, kirimkan parameter kueri `?last_event_id=<ID>` saat rekoneksi agar event bus memutar ulang (*replay*) event yang terlewat.

---

## 9. MASALAH DOCKER & KONTAINER

### Kasus 9.1: Service PostgreSQL Berstatus `unhealthy`
* **Gejala:**  
  Kontainer `weired-cloud-api` menolak menyala karena `postgres: condition service_healthy` gagal terpenuhi.
* **Langkah Periksa Log:**
  ```bash
  docker logs weired-cloud-postgres
  ```
* **Langkah Perbaikan:**
  1. Pastikan volume database tidak korup:
     ```bash
     docker compose -f deploy/docker-compose.cloud.yml down -v
     docker compose -f deploy/docker-compose.cloud.yml up -d
     ```
     *(Perhatian: flag `-v` akan menghapus seluruh data lokal volume)*.
  2. Periksa apakah kapasitas disk penyimpanan laptop/server mencukupi.

---

## 10. MASALAH LINGKUNGAN FLUTTER & MELOS

### Kasus 10.1: `CommandNotFoundException` untuk Flutter/Dart
* **Gejala:**  
  Menjalankan `flutter run` atau `melos bootstrap` gagal karena toolchain tidak terdaftar pada PATH terminal.
* **Langkah Perbaikan:**
  1. Unduh Flutter SDK resmi dari [flutter.dev](https://flutter.dev).
  2. Ekstrak ke direktori tanpa spasi (misalnya: `C:\src\flutter` di Windows atau `/usr/local/flutter` di Linux).
  3. Tambahkan direktori `bin` Flutter ke PATH sistem lingkungan.
  4. Buka terminal baru dan validasi:
     ```bash
     flutter doctor
     ```
