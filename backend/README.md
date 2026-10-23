# Backend WE-IRED (Go + PostgreSQL)

Satu binary untuk dua mode:
- `--mode=cloud` di VPS: seluruh wilayah, dengan WhatsApp, FCM, BMKG, dan Gemini.
- `--mode=posko` di laptop posko: snapshot RT, menerima beacon dan relawan lewat hotspot, sinkron ke cloud saat online.

**PIC:** Nopal · **Pendukung:** Joshua (`relay`, `beacon`, `external/*`), Thoriq (`education`)

## Modul `internal/`

| Modul | Tanggung jawab | PIC |
|---|---|---|
| `platform/` | Konfigurasi, DB pool, kriptografi, antrean `jobs`, rate limit, logging | Nopal |
| `auth/` | OTP WhatsApp, login sandi, JWT, RBAC | Nopal |
| `region/` | Hierarki kelurahan → RW → RT, peran | Nopal |
| `household/` | Rumah, anggota, persetujuan, impor CSV, kode undangan, kunci rumah | Nopal |
| `assembly/` | Titik kumpul | Nopal |
| `volunteer/` | Blok & relawan | Nopal |
| `education/` | Modul, kuis, progres, checklist, rencana evakuasi, skor kesiapsiagaan | Thoriq |
| `incident/` | Siklus insiden, latihan, metrik | Nopal |
| `report/` | Penerimaan laporan & resolusi status | Nopal |
| `priority/` | Skor prioritas & rencana penugasan | Nopal |
| `task/` | Penugasan relawan | Nopal |
| `announcement/` | Pengumuman + tanda tangan Ed25519 | Nopal |
| `relay/` | Decoder paket biner, verifikasi HMAC, metadata jalur | Joshua |
| `sync/` | Endpoint outbox, snapshot aplikasi, event log | Nopal |
| `posko/` | Snapshot, push/pull, konflik | Nopal |
| `beacon/` | Registrasi, paket provisioning, `/beacon/sync`, telemetri | Joshua |
| `recap/` | Rekap + PDF/CSV | Nopal |
| `ai/` | Penyedia LLM (Ollama, Gemini) + anonimisasi | Nopal |
| `external/bmkg`, `external/inarisk` | Polling & pencocokan wilayah | Joshua |
| `notify/fcm`, `notify/whatsapp` | Push, template & webhook WhatsApp | Nopal |
| `realtime/` | Hub WebSocket | Nopal |
| `audit/` | Audit log | Nopal |

Setiap modul berisi `handler.go` (HTTP), `service.go` (logika), dan `store.go` (akses data via sqlc).

## Folder Lain
- `cmd/weired/`: entry point.
- `db/migrations/`: migrasi berversi (golang-migrate).
- `db/queries/`: query untuk sqlc.
- `tools/seed/`: generator **data sintetis** untuk demo dan uji.
- `.env.example`: daftar variabel lingkungan. Salin menjadi `.env` dan jangan di-commit.

Desain lengkap: [SDD](../docs/SDD.md) Bagian 4.2, 5, 6, 8, 9, 10.
