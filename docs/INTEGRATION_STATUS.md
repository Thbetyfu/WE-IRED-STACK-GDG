# WE-IRED Integration Status & Division of Work

Dokumen pelacakan komprehensif mengenai status implementasi, pembagian tugas anggota tim, kontrak data yang telah dibekukan (*frozen*), dependensi yang masih menunggu (*pending*), serta pembedaan antara validasi simulasi/vektor uji dengan integrasi fisik perangkat keras.

---

## 1. PEMBAGIAN TUGAS ANGGOTA TIM

Sistem WE-IRED dikembangkan oleh tiga insinyur dengan pembagian peran arsitektural sebagai berikut:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 TIM PENGEMBANG WE-IRED                                 │
├──────────────────────────┬─────────────────────────────┬───────────────────────────────┤
│ NOPAL (Tech Lead)        │ JOSHUA                      │ THORIQ                        │
│ Lead Integrator & Backend│ Firmware & Embedded Systems │ UI/UX Lead & Mobile Apps      │
├──────────────────────────┼─────────────────────────────┼───────────────────────────────┤
│ • Arsitektur Monorepo    │ • Firmware WE-IRED Beacon   │ • Design System (`ui`)        │
│ • Go Backend Platform    │   (ESP32-S3, PlatformIO)    │ • Shared Map Widget (T-03)    │
│ • PostgreSQL & Migrasi   │ • Driver BLE Relay Mesh     │ • Aplikasi Warga (`warga`)    │
│ • Posko Lokal & Sync     │ • Hardware BOM & Wiring     │ • Aplikasi Relawan (`relawan`)│
│ • Web Dashboard Features │ • Integrasi BMKG / InaRISK  │ • Konten Edukasi & P3K        │
│ • Docker, Caddy, & Test  │ • Vektor Uji Paket Biner    │ • Model Core Dart (`core`)    │
└──────────────────────────┴─────────────────────────────┴───────────────────────────────┘
```

---

## 2. STATUS FITUR SPESIFIKASI (F-01 s/d F-30)

Status fitur merujuk pada dokumen [`docs/SDD.md`](file:///c:/Users/gresn/Documents/Lomba/Hackathon%20GDG%20ITB/Project_Hackathon/WE-IRED-STACK-GDG/docs/SDD.md) dan pembagian tanggung jawab fungsional:

| ID | Nama Fitur | PIC | Status Implementasi | Status Integrasi & Keterbatasan Pengujian |
| :---: | :--- | :---: | :---: | :--- |
| **F-01** | Pendataan Rumah & Keluarga | Nopal | **Selesai (100%)** | **Verified.** Validasi NIK, enkripsi AES-256-GCM kolom sensitif (`health_notes_enc`), impor CSV baris-per-baris teruji di unit test. |
| **F-02** | Manajemen Titik Kumpul | Nopal | **Selesai (100%)** | **Verified.** Terhubung ke shared map widget T-03 dan skema database. |
| **F-03** | Manajemen Relawan & Blok | Nopal | **Selesai (100%)** | **Verified.** Penugasan blok, kapasitas tugas, dan status ketersediaan. |
| **F-04** | Edukasi Kesiapsiagaan | Thoriq | **Model Ready** | **Pending UI Mobile.** DTO dan data model di `packages/core` siap; menunggu layar mobile selesai. |
| **F-05** | Mode Latihan | Nopal | **Selesai (100%)** | **Verified.** Label `[LATIHAN]` pada semua tampilan; teruji di `TestAC11`. |
| **F-06** | Manajemen WE-IRED Beacon | Joshua | **Backend Ready** | **Pending Hardware.** API pendaftaran, status sinkronisasi, dan baterai siap di backend; menunggu firmware ESP32 fisik. |
| **F-07** | Aktivasi Mode Siaga | Nopal | **Selesai (100%)** | **Verified.** Konfirmasi 2-langkah dengan token konfirmasi teruji di `TestAC01`. |
| **F-08** | Laporan Status Rumah | Thoriq | **Backend & Dashboard Ready** | **Pending Mobile UI.** Ingest backend selesai; Dashboard Triage selesai; menunggu layar mobile Warga. |
| **F-09** | Laporan Atas Nama Warga | Thoriq | **Backend Ready** | **Pending Mobile UI.** Ingest proksi relawan dengan ID pencatat selesai di backend. |
| **F-10** | Dashboard Real-time | Nopal | **Selesai (100%)** | **Verified.** WebSocket pub-sub hub per insiden, event bus, dan sinkronisasi `last_event_id`. |
| **F-11** | Peta Interaktif | Thoriq | **Selesai (100%)** | **Verified.** Widget `SharedLocationPickerMap` (T-03) terpasang di Triage & Data RT tanpa modul duplikat. |
| **F-12** | Tabel Triase | Nopal | **Selesai (100%)** | **Verified.** Sorting mutlak berbasis skor prioritas backend, filter blok/urgensi, tab belum melapor. |
| **F-13** | Skor Prioritas & Penugasan | Nopal | **Selesai (100%)** | **Verified.** Algoritma greedy $U+V+W+N+D$ per SDD 6.1–6.3 dan rekalkulasi periodik 60s teruji di `TestAC08`. |
| **F-14** | Penugasan Relawan | Nopal | **Selesai (100%)** | **Verified.** State machine tugas (`suggested` $\to$ `assigned` $\to$ `accepted` $\to$ `completed`) dengan timeout 5m. |
| **F-15** | Siaran Pengumuman | Nopal | **Selesai (100%)** | **Verified.** Penandatanganan digital Ed25519, batas 160 karakter, kanal push/WhatsApp/relay. |
| **F-16** | Panduan P3K Offline | Thoriq | **Model Ready** | **Pending Mobile UI.** Struktur konten JSON lokal tersedia. |
| **F-17** | Antrean Offline & Sinkronisasi | Nopal | **Selesai (100%)** | **Verified.** Outbox worker Drift SQLite, batch sync idempotensi, deduplikasi `already_exists` di `TestAC04`. |
| **F-18** | Relay BLE Warga $\to$ Relawan | Joshua | **Codec Ready** | **Test-Vector Verified (Pending Hardware).** Parser 46-byte lulus uji vektor `relay_packet.json`; transmisi radio fisik menunggu hari-H. |
| **F-19** | Relay BLE Multi-Hop | Joshua | **Codec Ready** | **Test-Vector Verified (Pending Hardware).** Hop count tracking dan proteksi TTL teruji di `TestAC05`. |
| **F-20** | Konfirmasi Laporan (ACK) | Joshua | **Backend Ready** | **Pending Hardware.** ACK packet pool dan penghapusan antrean offline. |
| **F-21** | Posko Lokal Mandiri | Nopal | **Selesai (100%)** | **Verified.** Ekspor/impor snapshot AES-256-GCM (Argon2id), kursor pull/push, dan TLS self-signed teruji di `TestAC07`. |
| **F-22** | Check-in Otomatis Beacon | Joshua | **Backend Ready** | **Test-Vector Verified (Pending Hardware).** Decode beacon packet 21-byte teruji di `TestAC06`. |
| **F-23** | Graf Topologi Relay | Joshua | **Backend & Dashboard Ready** | Endpoint `/api/v1/incidents/{id}/topology` dan UI graf node tersedia. |
| **F-24** | Mode Hemat Baterai | Joshua | **Spesifikasi Ready** | Logika duty cycle Bluetooth diatur di layer firmware. |
| **F-25** | Retensi Cache 72 Jam | Joshua | **Spesifikasi Ready** | Pembersihan berkas cache laporan darurat lokal setelah 72 jam. |
| **F-26** | Rekap Kebutuhan Pasca-Bencana | Nopal | **Selesai (100%)** | **Verified (End-to-End).** Agregasi otomatis, persetujuan pengurus, ekspor PDF Maroto (`%PDF-1.4`) teruji di `TestAC09`. |
| **F-27** | Asisten AI (Privasi Terjaga) | Nopal | **Selesai (100%)** | **Verified.** Anonimisasi PII (`[WARGA_n]`), adapter ganda Ollama/Gemini, saklar aktivasi per RT. |
| **F-28** | Peringatan BMKG / InaRISK | Joshua | **Model Ready** | **Simulated.** Banner BMKG ditampilkan berdasarkan kontrak skema JSON teruji. |
| **F-29** | Skala Multi-RT (Admin Wilayah)| Nopal | **Selesai (100%)** | **Verified.** Halaman wilayah lintas-RT, agregasi numerik tanpa kebocoran data kesehatan (kepatuhan FR-RCP-05). |
| **F-30** | Kanal WhatsApp Cloud API | Nopal | **Selesai (100%)** | **Simulated / Test-API Verified.** 5 template resmi, alur interaktif butuh bantuan, pengingat T+10/T+25 teruji di `TestAC03`. |

---

## 3. KONTRAK DATA YANG TELAH DIBEKUKAN (*FROZEN CONTRACTS*)

Kontrak berikut telah disepakati dan **tidak boleh diubah secara sepihak**:

1. **Paket Biner Relay BLE (46 Byte):**
   - Rujukan: [`docs/test-vectors/relay_packet.json`](file:///c:/Users/gresn/Documents/Lomba/Hackathon%20GDG%20ITB/Project_Hackathon/WE-IRED-STACK-GDG/docs/test-vectors/relay_packet.json) & [`backend/internal/relay/codec.go`](file:///c:/Users/gresn/Documents/Lomba/Hackathon%20GDG%20ITB/Project_Hackathon/WE-IRED-STACK-GDG/backend/internal/relay/codec.go).
   - Format: `version(1)`, `type(1)`, `household_short_id(8)`, `incident_short_id(4)`, `seq(4)`, `created_at(4)`, `status(1)`, `urgency(1)`, `needs(1)`, `member_mask(1)`, `battery(1)`, `flags(1)`, `lat_e6(4)`, `lon_e6(4)`, `ttl(1)`, `hop_count(1)`, `mac(8)` (HMAC-SHA256), `path(0-12)`.
2. **Paket Beacon Check-in (21 Byte):**
   - Format: `UUID titik kumpul (16 byte)` + `Major/Minor RT (4 byte)` + `RSSI threshold (1 byte)`.
3. **Shared Map Widget (T-03):**
   - Komponen `SharedLocationPickerMap` pada `packages/ui/lib/src/map/shared_location_picker_map.dart` menjadi satu-satunya standar tampilan peta pada antarmuka Flutter monorepo.
4. **Amplop Snapshot Posko Lokal (`WRSN`):**
   - Format amplop terenkripsi: Magic `WRSN`, 16-byte Salt, 12-byte Nonce, Ciphertext terotentikasi AES-256-GCM dengan Argon2id KDF (time=1, memory=64MB, threads=2, keyLength=32).

---

## 4. INTEGRASI: SIMULASI VS IMPLEMENTASI PRODUKSI

Untuk menjamin kejujuran akademik dan transparansi di hadapan dewan juri, status integrasi dibagi menjadi dua kategori:

```
┌───────────────────────────────────────┬───────────────────────────────────────┐
│     TERVERIFIKASI LOGIKA & PROTOKOL   │    MENUNGGU INTEGRASI FISIK/PRODUKSI  │
│          (Simulated / Vektor Uji)     │        (Pending Field Hardware)       │
├───────────────────────────────────────┼───────────────────────────────────────┤
│ • Parser biner 46-byte relay BLE      │ • Antena radio BLE chip ESP32-S3      │
│ • Webhook WhatsApp & signature HMAC   │ • Nomor telepon WhatsApp bisnis Meta  │
│ • Beacon Check-in channel parser      │ • Perangkat beacon fisik di lapangan  │
│ • Fallback AI Anonymizer              │ • Cluster Ollama GPU / Gemini API Key │
│ • Outbox SQLite batching & deduplikasi│ • Uji radio multi-HP Android warga    │
└───────────────────────────────────────┴───────────────────────────────────────┘
```

---

## 5. BUKTI PENGUJIAN AKTUAL TERSEDIA

Berikut adalah ringkasan bukti pengujian aktual yang dapat direproduksi di lingkungan repositori:

1. **Uji Skenario Penerimaan Sistem (AC-01 s/d AC-11):**
   - Perintah: `go test -v -count=1 ./internal/integration`
   - Hasil: **11/11 LULUS (100% PASS, durasi 0.346s)**.
2. **Uji Race Detector Backend:**
   - Perintah: `go test -race -count=1 ./...`
   - Hasil: **29/29 package backend berstatus `ok` tanpa data race terdeteksi**.
3. **Uji Beban HTTP Berkelanjutan (NFR-PERF-01):**
   - Perintah: `go run ./cmd/loadtest -target=http -mode=sustained -rps=250 -duration=5`
   - Hasil: **1.250/1.250 request sukses (100%), throughput 247,79 RPS, latensi p95 = 0,69 ms (target $\le 500\text{ ms}$)**.
4. **Uji Beban Lonjakan HTTP (Burst):**
   - Perintah: `go run ./cmd/loadtest -target=http -mode=burst -rts=50 -reports=300`
   - Hasil: **15.000/15.000 request sukses (100%), throughput 21.552,77 RPS, latensi p95 = 6,15 ms**.
5. **Uji Kepatuhan Vektor Uji Relay Joshua:**
   - Perintah: `go test -v ./internal/relay`
   - Hasil: **Kasus Laporan Kritis & Kasus Beacon Check-in PASS**.
