# Firmware WE-IRED Beacon (ESP32-S3)

Firmware untuk beacon di titik kumpul: server BLE (kotak surat laporan + pengumuman), check-in, sinkron Wi-Fi ke Posko Lokal, manajemen daya, OLED, LED, dan buzzer.

**PIC:** Joshua

| Folder | Isi |
|---|---|
| `src/ble/` | Server GATT NimBLE: `NODE_INFO`, `LUV`, `INBOX`, `OUTBOX`, `ANNOUNCE`, `BEACON_PROVISION`, `BEACON_STATUS`, data iklan |
| `src/store/` | `PacketStore` (LittleFS, segmen, deduplikasi, prune 72 jam), `AnnounceStore` (verifikasi Ed25519) |
| `src/sync/` | `WifiSync`: koneksi hotspot Posko, `POST /api/v1/beacon/sync` bertanda tangan HMAC |
| `src/power/` | `PowerMonitor`: ADC baterai, status charger, mode HEMAT/KRITIS/deep sleep |
| `src/timekeeper/` | DS3231 + sinkron waktu dari Posko |
| `src/ui/` | OLED SSD1306, pola LED, buzzer, tombol |
| `include/` | Header, konstanta UUID & format paket, pin map |
| `test/` | Uji unit (codec paket terhadap `docs/test-vectors/`) |

**Toolchain:** PlatformIO, board `esp32-s3-devkitc-1`, framework Arduino, NimBLE-Arduino, RTClib, U8g2.

**Pin map, wiring, anggaran daya, mesin status:** [HRD](../../docs/HRD.md) Bagian 5–7 · **Protokol:** [SDD](../../docs/SDD.md) Bagian 7 & 8.4
