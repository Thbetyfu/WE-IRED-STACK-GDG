# Paket Bersama (Dart/Flutter)

Dipakai oleh ketiga aplikasi di `apps/` dan dikelola dengan **Melos**.

| Paket | Isi | PIC |
|---|---|---|
| [`core/`](core) | Model data, API client (dio), WebSocket client, basis data lokal Drift, outbox & sinkronisasi, sesi & penyimpanan aman, deteksi endpoint cloud/Posko | Nopal |
| [`ble_relay/`](ble_relay) | Codec paket relay 46 byte + HMAC, framing GATT, server/klien GATT, protokol LUV & mesh, siklus peran & hemat baterai, mode kolektor, verifikasi pengumuman Ed25519 | Joshua |
| [`ui/`](ui) | Tema & warna status, komponen aksesibel (tombol besar, kartu status), widget peta bersama (flutter_map) | Thoriq |
| [`content/`](content) | Panduan P3K dan modul edukasi bawaan (JSON + gambar) | Thoriq |

**Aturan:**
- `ble_relay` **wajib** lulus vektor uji di `docs/test-vectors/` agar formatnya sama dengan backend Go dan firmware beacon.
- `core` tidak boleh bergantung pada `ui`. Aplikasi boleh memakai semua paket.
