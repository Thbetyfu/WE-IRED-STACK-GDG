# Aplikasi Relawan

Aplikasi Android untuk **relawan dan pengurus di lapangan**: menerima tugas, melapor atas nama warga, mengumpulkan laporan offline lewat Bluetooth, terhubung ke Posko Lokal, dan menyiapkan beacon.

**PIC:** Thoriq (layar operasional) & Joshua (layar Bluetooth/beacon)

| Folder `lib/features/` | Isi | Fitur | PIC |
|---|---|---|---|
| `tasks/` | Daftar tugas berurutan prioritas, ubah status tugas | F-14 | Thoriq |
| `block_map/` | Peta rumah di blok, status, rute | F-11 | Thoriq |
| `proxy_report/` | Lapor atas nama warga tanpa HP | F-09 | Thoriq |
| `posko/` | Pindai QR Posko, status koneksi | F-21 | Thoriq |
| `first_aid/` | Panduan P3K (memakai `packages/content`) | F-16 | Thoriq |
| `collector/` | Mode kolektor BLE (data mule), sinkron paket | F-18, F-20 | Joshua |
| `topology/` | Daftar node sekitar & graf relay | F-23 | Joshua |
| `beacon_tools/` | Provisioning, diagnostik, kalibrasi RSSI beacon | F-06, F-22 | Joshua |

**Target:** Android 8.0+ · Spesifikasi: [SRS](../../docs/SRS.md) Bagian 3.8, 3.10, 3.14–3.16 · Layar: [SDD](../../docs/SDD.md) Bagian 4.4
