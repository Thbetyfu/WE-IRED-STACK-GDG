# Aplikasi Warga

Aplikasi Android untuk **kepala keluarga**: aktivasi akun, melapor status saat siaga, menerima pengumuman, edukasi kesiapsiagaan, dan panduan P3K offline.

**PIC:** Thoriq · **Pendukung:** Joshua (`beacon_checkin`, integrasi `ble_relay`), Nopal (`packages/core`, push)

| Folder `lib/features/` | Isi | Fitur | PIC |
|---|---|---|---|
| `onboarding/` | Kode undangan → nomor WA → OTP | F-01, F-30 | Thoriq |
| `home/` | Beranda normal & mode siaga, banner LATIHAN | F-07, F-05 | Thoriq |
| `report/` | 3 tombol lapor, form "Butuh bantuan", status pengiriman | F-08, F-17 | Thoriq |
| `household/` | Data rumah & anggota, persetujuan, unduh/hapus data | F-01 | Thoriq |
| `education/` | Modul, kuis, checklist tas siaga, rencana evakuasi, skor | F-04 | Thoriq |
| `first_aid/` | Panduan P3K offline | F-16 | Thoriq |
| `announcements/` | Carousel pengumuman | F-15, F-20 | Thoriq |
| `beacon_checkin/` | Deteksi beacon & tawaran check-in | F-22 | Joshua |
| `settings/` | Mode baterai, check-in otomatis, izin | F-24 | Thoriq |

`lib/services/`: outbox worker, push handler, foreground service BLE (memakai `packages/core` dan `packages/ble_relay`).

**Target:** Android 8.0+ · Spesifikasi: [SRS](../../docs/SRS.md) Bagian 3.7, 3.5, 3.12 · Layar: [SDD](../../docs/SDD.md) Bagian 4.3
