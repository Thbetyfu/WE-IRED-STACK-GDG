# Dashboard Pengurus

Aplikasi Flutter **Web dan Windows** untuk Pengurus RT dan Admin Wilayah: kelola data RT, aktifkan siaga, pantau status real-time, atur penugasan, kirim pengumuman, susun rekap. Build Windows dipakai sebagai Dashboard Posko Lokal.

**PIC:** Nopal · **Pendukung:** Thoriq (`map`, `education_admin`), Joshua (`topology`, `beacons`)

| Folder `lib/features/` | Isi | Fitur | PIC |
|---|---|---|---|
| `incident_overview/` | Kartu ringkasan, aktivasi/akhir insiden, metrik, banner BMKG | F-05, F-07, F-10, F-28 | Nopal |
| `map/` | Peta pin rumah, titik kumpul, radius, beacon, relawan | F-11 | Thoriq |
| `triage/` | Tabel triase + daftar Belum Melapor | F-10, F-12 | Nopal |
| `assignments/` | Rencana penugasan, persetujuan, papan tugas | F-13, F-14 | Nopal |
| `announcements/` | Editor pengumuman 160 karakter & pilihan kanal | F-15 | Nopal |
| `rt_data/` | Rumah, anggota, persetujuan, blok, relawan, titik kumpul, impor CSV | F-01–F-03 | Nopal |
| `education_admin/` | Kelola modul/kuis, skor kesiapsiagaan per rumah & blok | F-04 | Thoriq |
| `history_drills/` | Riwayat insiden & perbandingan metrik latihan | F-05 | Nopal |
| `recap/` | Pratinjau, draf AI, persetujuan, ekspor PDF/CSV, kirim WA | F-26, F-27, F-30 | Nopal |
| `topology/` | Graf relay & node | F-23 | Joshua |
| `beacons/` | Registrasi beacon, token provisioning, telemetri | F-06 | Joshua |
| `region/` | Agregat multi-RT untuk Admin Wilayah | F-29 | Nopal |
| `audit/` | Audit log | — | Nopal |
| `posko/` | Snapshot, status sinkron cloud, QR konfigurasi relawan | F-21 | Nopal |

Spesifikasi: [SRS](../../docs/SRS.md) Bagian 3.9–3.11, 3.17 · Halaman: [SDD](../../docs/SDD.md) Bagian 4.5
