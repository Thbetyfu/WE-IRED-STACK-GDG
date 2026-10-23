# Vektor Uji Protokol

**PIC:** Joshua

Berisi contoh masukan dan keluaran **yang wajib menghasilkan byte yang sama** di tiga implementasi:
- Dart: `packages/ble_relay`
- Go: `backend/internal/relay`
- C++: `firmware/beacon`

| Berkas (akan dibuat) | Isi |
|---|---|
| `relay_packet.json` | Field laporan → 46 byte paket (hex), kunci rumah uji, HMAC yang diharapkan |
| `luv.json` | Dua LUV → delta yang diharapkan |
| `announcement.json` | Pengumuman + kunci uji Ed25519 → tanda tangan yang diharapkan |
| `beacon_sync.json` | Body `/beacon/sync` + rahasia beacon → header `X-Signature` |

Semua kunci di sini adalah **kunci uji**, bukan kunci produksi. Spesifikasi format: [SDD](../SDD.md) Bagian 7 & 8.4.
