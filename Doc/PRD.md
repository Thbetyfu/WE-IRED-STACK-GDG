# Product Requirements Document (PRD) — WE-IRED

> **Koordinasi Kesiapsiagaan Bencana Tingkat RT, tetap berjalan saat sinyal hilang**

| Atribut | Keterangan |
|---|---|
| Produk | WE-IRED |
| Kompetisi | STACK 2026 by GDGoC ITB — *Case 2: Stronger Communities and Everyday Services* |
| Versi dokumen | 0.1 (draf) |
| Tanggal | 23 Oktober 2026 |
| Dokumen terkait | [SRS.md](SRS.md) · [SDD.md](SDD.md) · [HRD.md](HRD.md) |

> **Catatan bahasa.** Dokumen ini adalah dokumen internal tim dan ditulis dalam bahasa Indonesia. Seluruh materi yang dikumpulkan ke STACK 2026 (abstrak, proposal, video, deck, pitching) wajib berbahasa Inggris, sehingga isi dokumen ini perlu diterjemahkan saat digunakan untuk submission.

---

## 1. Ringkasan Produk

WE-IRED adalah sistem koordinasi kesiapsiagaan dan tanggap darurat bencana untuk tingkat Rukun Tetangga (RT). Sistem ini membantu pengurus RT dan relawan untuk:

1. **Sebelum bencana:** mendata rumah dan warga yang membutuhkan bantuan evakuasi (lansia, penyandang disabilitas, ibu hamil, balita), menetapkan titik kumpul, membagi tugas relawan per blok, serta meningkatkan kesiapsiagaan keluarga melalui edukasi dan latihan.
2. **Saat bencana:** mengaktifkan mode siaga, mengumpulkan status setiap rumah ("aman", "sudah di titik kumpul", atau "butuh bantuan"), melihat rumah yang belum melapor, dan mengarahkan relawan ke warga yang paling membutuhkan, **termasuk ketika jaringan seluler dan internet terputus** melalui relay Bluetooth, mesh antar-HP, WE-IRED Beacon di titik kumpul, dan Posko Lokal.
3. **Setelah bencana:** menyusun rekap kebutuhan secara otomatis untuk dilaporkan ke kelurahan.

Sistem terdiri dari lima komponen:

| Komponen | Platform | Pengguna utama |
|---|---|---|
| Aplikasi Warga | Flutter (Android) | Kepala keluarga |
| Aplikasi Relawan | Flutter (Android) | Relawan |
| Dashboard Pengurus | Flutter Web / Desktop | Pengurus RT, Admin Wilayah |
| Backend | Go + PostgreSQL (cloud atau Posko Lokal) | — |
| WE-IRED Beacon | ESP32 (perangkat keras) | Dipasang di titik kumpul |

Sebagai kanal tambahan saat online, sistem terhubung dengan **WhatsApp Cloud API resmi**, sehingga warga yang tidak memasang aplikasi tetap dapat menerima peringatan dan melapor dengan satu ketukan tombol.

---

## 2. Latar Belakang

### 2.1 Asal Ide

WE-IRED menggabungkan dua sumber inspirasi:

1. **NALARIA (Navigasi Belajar Siaga Bencana)** — karya Tim PKM-PM Universitas Ahmad Dahlan (Aida Calista Uparengga, Nanda Puspita Sari, Baiq Najwa Raissa Fitri, dan Qorni Syihab Alfaritzi), peraih medali emas PKM-PM di PIMNAS ke-37 (14–19 Oktober 2024, Universitas Airlangga). NALARIA adalah program edutainment untuk meningkatkan pemahaman dan kesiapsiagaan bencana siswa sekolah dasar di daerah rawan bencana. WE-IRED **mengadaptasi konsepnya** menjadi fitur edukasi kesiapsiagaan keluarga. Konten edukasi, kode, dan materi WE-IRED dibuat sendiri oleh tim.
2. **Resku (Rescue and Knowledge Utility)** — prototipe internal tim sebelumnya (belum pernah diikutkan lomba) berupa platform komunikasi darurat offline-first berbasis mesh Bluetooth, data mule, dan dashboard triase. WE-IRED **membawa pengalaman dan konsep teknis** Resku (relay Bluetooth, epidemic routing, skor prioritas, sinkronisasi lokal) ke konteks koordinasi RT. **Seluruh kode WE-IRED dibangun ulang dari nol di repositori baru** untuk STACK 2026.

### 2.2 Kebutuhan yang Ingin Dijawab

- BNPB mencatat 2.107 kejadian bencana sepanjang 2024 dengan sekitar 400 korban meninggal. Banjir, tanah longsor, dan banjir bandang menjadi penyebab korban terbanyak. BNPB juga menyebut penurunan jumlah kejadian dari 2023 terutama disebabkan perubahan metode pencatatan. *(Sumber: dokumen ide awal [25]; perlu diverifikasi ulang dan dikutip lengkap.)*
- BNPB sudah menyediakan **InaRISK**, yang menampilkan peta risiko, kajian kerentanan dan kesiapsiagaan keluarga/komunitas, serta informasi ancaman di lokasi pengguna. InaRISK berfokus pada **informasi dan kajian risiko**.
- Kebutuhan yang belum terlihat terlayani adalah **koordinasi operasional warga pada jam-jam pertama kejadian di tingkat RT**: siapa yang sudah aman, siapa yang belum melapor, warga rentan mana yang belum dijangkau, dan relawan mana yang harus bergerak ke mana. Kebutuhan ini justru paling sulit dipenuhi ketika jaringan seluler terganggu.

> **[PLACEHOLDER — BUKTI LAPANGAN]** Hasil wawancara dengan pengurus RT di wilayah rawan bencana belum tersedia. Bagian ini wajib diisi dengan temuan nyata sebelum abstrak dan proposal dikirim (bobot *Problem Clarity* 30% di preliminary). Jangan mengisi dengan data rekaan.

### 2.3 Posisi Terhadap Solusi yang Ada

| Solusi | Fokus | Perbedaan dengan WE-IRED |
|---|---|---|
| NALARIA | Edukasi kesiapsiagaan untuk siswa SD | WE-IRED adalah alat koordinasi operasional untuk pengurus lingkungan; edukasi hanya salah satu fitur dan ditujukan ke keluarga. |
| InaRISK | Informasi & kajian risiko bencana | WE-IRED mengelola data warga, status per rumah, dan penugasan relawan saat kejadian. |
| Grup WhatsApp RT | Komunikasi umum | Pesan tenggelam, tidak ada status per rumah, tidak ada daftar "belum melapor", tidak berfungsi tanpa sinyal. WE-IRED memakai WhatsApp sebagai kanal, bukan sebagai sistem koordinasi. |
| Resku (prototipe internal) | SAR di area blackout total | Resku hanya mengetahui korban yang melapor. WE-IRED mengetahui **daftar seluruh warga sejak awal**, sehingga rumah yang diam langsung terlihat. |

**Nilai pembeda utama:** *"Yang diam justru yang paling perlu dicari."* Karena WE-IRED memiliki data seluruh rumah dan warga rentan sebelum kejadian, sistem dapat menandai dan memprioritaskan rumah yang belum melapor, dan laporan tetap dapat sampai ke relawan walaupun sinyal hilang.

---

## 3. Tujuan dan Non-Tujuan

### 3.1 Tujuan Produk

| ID | Tujuan |
|---|---|
| G-1 | Pengurus RT mengetahui dalam hitungan menit rumah mana yang sudah aman, butuh bantuan, atau belum melapor. |
| G-2 | Warga rentan menjadi prioritas penjangkauan relawan secara otomatis. |
| G-3 | Laporan warga tetap dapat sampai ke pengurus walaupun jaringan seluler/internet terputus. |
| G-4 | Warga dapat melapor tanpa harus memasang aplikasi (melalui WhatsApp) dan warga tanpa HP tetap tercatat (melalui relawan). |
| G-5 | Rekap kebutuhan untuk kelurahan tersusun otomatis tanpa pencatatan manual. |
| G-6 | Kesiapsiagaan keluarga meningkat dan dapat diukur melalui edukasi dan latihan evakuasi. |
| G-7 | Data pribadi spesifik warga (kesehatan, anak, disabilitas) terlindungi dan hanya dapat diakses pihak yang berwenang. |

### 3.2 Non-Tujuan

- WE-IRED **bukan** pengganti sistem peringatan dini resmi (BMKG/BNPB). Integrasi BMKG/InaRISK hanya memberi saran, keputusan aktivasi siaga tetap di tangan pengurus.
- WE-IRED **bukan** sistem SAR profesional skala besar dan tidak mencakup integrasi drone (dihapus dari lingkup).
- WE-IRED **tidak** menyediakan layanan medis; panduan P3K hanya bersifat panduan pertolongan pertama.
- Aplikasi iOS tidak termasuk lingkup saat ini (fokus Android).

---

## 4. Pengguna dan Persona

### 4.1 Peran Pengguna

| Peran | Deskripsi | Komponen |
|---|---|---|
| **Pengurus RT** | Ketua/sekretaris RT. Mengelola data warga, titik kumpul, relawan, beacon; mengaktifkan siaga; memantau; menyusun rekap. | Dashboard Pengurus (juga dapat memakai Aplikasi Relawan) |
| **Relawan** | Warga yang ditugaskan per blok. Menjangkau warga, melapor atas nama warga tanpa HP, menampung laporan offline. | Aplikasi Relawan |
| **Kepala Keluarga (Warga)** | Melapor status rumahnya, menerima pengumuman, mengikuti edukasi. | Aplikasi Warga atau WhatsApp |
| **Admin Wilayah** | Pengurus RW atau petugas kelurahan. Melihat agregat beberapa RT, menerima rekap. | Dashboard Pengurus (mode wilayah) |
| **Operator Sistem** | Tim pengembang/pengelola instalasi. Mengelola wilayah dan akun pengurus. | Dashboard (super admin) |

### 4.2 Persona

**Pak Darto (54), Ketua RT 05** — Wilayahnya langganan banjir. Saat banjir terakhir, ia menelepon satu per satu warga dan baru tahu dua jam kemudian bahwa seorang lansia masih terjebak di rumah. Ia butuh satu layar yang menunjukkan siapa yang belum aman.

**Rina (23), relawan blok B** — Mahasiswa yang tinggal bersama orang tuanya. Saat kejadian ia ingin tahu rumah mana yang harus didatangi lebih dulu, tanpa menunggu instruksi lewat grup WA yang ramai.

**Bu Sari (38), kepala keluarga** — Memiliki balita dan mertua yang memakai kursi roda. Ia tidak mau memasang banyak aplikasi, tetapi selalu membuka WhatsApp.

**Mbah Kardi (78), warga tanpa HP** — Tinggal sendiri. Ia hanya dapat tercatat aman jika relawan mendatanginya.

---

## 5. Alur Pengguna Utama

### 5.1 Pra-Bencana

1. Pengurus RT membuat data RT, blok, dan titik kumpul, lalu mendaftarkan WE-IRED Beacon di setiap titik kumpul.
2. Pengurus mendata rumah dan anggota keluarga. Data warga rentan hanya disimpan **setelah persetujuan warga dicatat**.
3. Kepala keluarga mengaktifkan akun melalui kode undangan rumah dan OTP WhatsApp, lalu melengkapi data, rencana evakuasi keluarga, dan checklist tas siaga.
4. Pengurus menugaskan relawan per blok.
5. Warga mengikuti modul edukasi dan kuis. Pengurus memantau skor kesiapsiagaan per rumah.
6. Pengurus menjalankan **Mode Latihan** (simulasi evakuasi) untuk mengukur kesiapan dan melatih alur.

### 5.2 Saat Bencana

1. Pengurus mengaktifkan **mode siaga** (atau menerima saran aktivasi dari integrasi BMKG). Sistem mengirim push notification dan pesan WhatsApp ke seluruh kepala keluarga.
2. Kepala keluarga melapor melalui Aplikasi Warga atau tombol WhatsApp: **Aman di rumah / Sudah di titik kumpul / Butuh bantuan** (dengan tingkat urgensi, jenis kebutuhan, anggota yang butuh bantuan, dan pesan singkat).
3. Saat warga tiba di titik kumpul, Aplikasi Warga mendeteksi WE-IRED Beacon dan menawarkan **check-in otomatis**.
4. Jika tidak ada sinyal, laporan disimpan di HP lalu diteruskan melalui **mesh antar-HP warga**, **HP relawan** yang lewat, atau **WE-IRED Beacon**, hingga mencapai backend (cloud atau Posko Lokal).
5. Dashboard menampilkan status per rumah secara real-time di peta dan tabel. Rumah yang belum melapor dan memiliki warga rentan berada di urutan atas daftar prioritas.
6. Pengurus menerima rencana penugasan otomatis dan menugaskan relawan. Relawan menuju rumah, melapor atas nama warga jika diperlukan, dan menandai "sudah dijangkau".
7. Pengurus mengirim pengumuman (misalnya perubahan titik kumpul) yang menyebar melalui aplikasi, WhatsApp, mesh, dan beacon.
8. Sistem mengirim pengingat WhatsApp otomatis ke rumah yang belum melapor.

### 5.3 Pasca-Bencana

1. Pengurus mengakhiri mode siaga.
2. Sistem menyusun **rekap kebutuhan** (jumlah KK per status, warga rentan terjangkau, kebutuhan agregat, daftar tindak lanjut, linimasa). AI dapat membantu menyusun ringkasan naratif yang ditinjau pengurus.
3. Rekap diekspor ke PDF/CSV dan dikirim ke kelurahan melalui WhatsApp.
4. Cache relay di HP dan beacon terhapus otomatis setelah 72 jam.

---

## 6. Daftar Fitur

Seluruh 30 fitur berikut berstatus **Wajib** dan menjadi lingkup produk.

### A. Persiapan (Pra-Bencana)

| ID | Fitur | Deskripsi | Komponen |
|---|---|---|---|
| F-01 | Pendataan Rumah & Anggota Keluarga | Data rumah (alamat, blok, lokasi di peta), anggota keluarga, kategori kerentanan (lansia, disabilitas, ibu hamil, balita, penyakit kronis), kontak, dan pencatatan persetujuan warga. | Dashboard, App Warga |
| F-02 | Manajemen Titik Kumpul | Membuat, mengubah, dan menonaktifkan titik kumpul beserta lokasi, kapasitas, dan fasilitas. | Dashboard |
| F-03 | Manajemen Relawan & Blok | Mendaftarkan relawan, membagi wilayah RT menjadi blok, dan menugaskan relawan per blok. | Dashboard |
| F-04 | Edukasi Kesiapsiagaan Keluarga | Modul per jenis bencana, kuis interaktif, checklist tas siaga, rencana evakuasi keluarga, dan skor kesiapsiagaan per rumah (adaptasi konsep NALARIA). | App Warga, Dashboard |
| F-05 | Mode Latihan | Simulasi evakuasi dengan alur yang sama seperti siaga nyata, ditandai jelas sebagai latihan, beserta metrik waktu dan jangkauan. | Semua |
| F-06 | Manajemen WE-IRED Beacon | Mendaftarkan beacon ke titik kumpul, provisioning, dan memantau status (baterai, jumlah laporan, waktu sinkronisasi terakhir). | Dashboard, App Relawan, Beacon |

### B. Saat Kejadian

| ID | Fitur | Deskripsi | Komponen |
|---|---|---|---|
| F-07 | Aktivasi Mode Siaga | Pengurus mengaktifkan siaga (jenis bencana, cakupan blok). Sistem mengirim push notification dan WhatsApp. | Dashboard, Backend |
| F-08 | Laporan Status Rumah | Status *Aman di rumah / Sudah di titik kumpul / Butuh bantuan*, tingkat urgensi, jenis kebutuhan, anggota yang butuh bantuan, pesan singkat, GPS, dan level baterai. | App Warga |
| F-09 | Laporan Atas Nama Warga | Relawan melapor untuk rumah/warga yang tidak memiliki HP atau tidak dapat melapor. | App Relawan |
| F-10 | Dashboard Real-time & Daftar Belum Melapor | Ringkasan status per rumah yang diperbarui secara langsung, dengan daftar khusus rumah yang belum melapor. | Dashboard |
| F-11 | Peta Interaktif | Peta OpenStreetMap dengan pin rumah berwarna sesuai status, titik kumpul, lingkaran radius, posisi beacon, dan cache peta offline. | Dashboard, App Relawan |
| F-12 | Tabel Triase | Tabel rumah yang dapat diurutkan dan difilter (status, blok, kerentanan), dengan tombol *Locate* ke peta. | Dashboard |
| F-13 | Skor Prioritas & Rencana Penugasan | Skor 0–100 per rumah berdasarkan status, kerentanan, lama menunggu, kebutuhan, dan jarak; rencana penugasan relawan yang disarankan. | Backend, Dashboard |
| F-14 | Penugasan Relawan | Pengurus menugaskan relawan ke rumah; relawan menerima, memperbarui progres, dan menandai "sudah dijangkau". | Dashboard, App Relawan |
| F-15 | Siaran Pengumuman | Pengumuman maksimal 160 karakter dari pengurus, ditampilkan sebagai carousel di aplikasi warga. | Dashboard, App Warga |
| F-16 | Panduan P3K Offline | Panduan pertolongan pertama (RJP/CPR, perdarahan, patah tulang, luka bakar, hipotermia, dehidrasi, tenggelam) yang dapat diakses tanpa internet. | App Warga, App Relawan |

### C. Tanpa Sinyal (Offline)

| ID | Fitur | Deskripsi | Komponen |
|---|---|---|---|
| F-17 | Antrean Offline & Sinkronisasi Otomatis | Semua aksi disimpan lokal di antrean (outbox) dan dikirim otomatis saat koneksi tersedia, tanpa duplikasi. | App Warga, App Relawan |
| F-18 | Relay Bluetooth Warga → Relawan | HP relawan menarik laporan dari HP warga di sekitarnya (pola *data mule*), lalu meneruskannya ke backend. | App Warga, App Relawan |
| F-19 | Mesh Multi-hop Antar-HP Warga | Laporan diteruskan dari HP ke HP menggunakan *epidemic routing* dengan *Latest Update Vector* (LUV) dan batas lompatan. | App Warga |
| F-20 | Penyebaran Pengumuman via Mesh | Pengumuman pengurus ikut tersebar ke HP warga melalui mesh, relawan, dan beacon. | Semua |
| F-21 | Mode Posko Lokal | Backend dijalankan di laptop posko dengan hotspot Wi-Fi saat internet putus; data disinkronkan ke cloud saat internet kembali. | Backend |
| F-22 | WE-IRED Beacon | Perangkat ESP32 di titik kumpul: menyimpan dan meneruskan laporan, menyiarkan pengumuman, mendukung check-in otomatis berbasis kedekatan, dan sinkronisasi ke Posko Lokal melalui Wi-Fi. | Beacon |
| F-23 | Daftar Node & Topologi Relay | Visualisasi perangkat di sekitar dan jalur relay, **khusus relawan dan pengurus**. | App Relawan, Dashboard |
| F-24 | Mode Hemat Baterai | Siklus Bluetooth disesuaikan otomatis saat baterai rendah. | App Warga, App Relawan |
| F-25 | Penghapusan Otomatis Cache Relay | Paket relay milik rumah lain dihapus otomatis setelah 72 jam. | App, Beacon |

### D. Pasca-Kejadian & Integrasi

| ID | Fitur | Deskripsi | Komponen |
|---|---|---|---|
| F-26 | Rekap Kebutuhan | Rekap otomatis untuk kelurahan, dapat diekspor ke PDF/CSV. | Dashboard, Backend |
| F-27 | Asisten AI | Ringkasan pesan warga, klasifikasi kebutuhan dari teks, dan draf narasi rekap. LLM lokal di posko saat offline, Gemini saat online. Hasil AI selalu ditinjau manusia. | Backend |
| F-28 | Integrasi BMKG / InaRISK | Menampilkan informasi gempa/cuaca BMKG yang relevan dengan wilayah sebagai saran aktivasi siaga, serta tautan/informasi risiko InaRISK. | Backend, Dashboard |
| F-29 | Skala Multi-RT (RW/Kelurahan) | Satu instalasi melayani banyak RT; Admin Wilayah melihat agregat lintas RT. | Backend, Dashboard |
| F-30 | Kanal WhatsApp | Melalui WhatsApp Cloud API resmi: OTP login, notifikasi siaga, lapor via tombol balasan, pengumuman, pengingat otomatis, dan pengiriman rekap. | Backend |

---

## 7. Prinsip Produk

1. **Satu ketukan untuk melapor.** Laporan dasar harus dapat dikirim dalam maksimal tiga ketukan dari notifikasi.
2. **Yang diam diprioritaskan.** Rumah yang belum melapor, terutama dengan warga rentan, selalu terlihat dan naik ke atas daftar.
3. **Berlapis saat sinyal hilang.** Internet → WhatsApp → mesh/relawan → beacon → Posko Lokal. Setiap lapisan berdiri sendiri.
4. **Privasi sejak desain.** Data kesehatan tidak pernah ikut dalam paket Bluetooth, mesh, atau beacon. Akses berbasis peran dan persetujuan.
5. **Manusia yang memutuskan.** AI dan integrasi BMKG hanya memberi saran. Aktivasi siaga, penugasan, dan rekap final tetap diputuskan pengurus.
6. **Jujur tentang status.** Data latihan, data sintetis, dan fitur simulasi selalu ditandai jelas (sesuai aturan STACK 2026).
7. **Ramah pengguna lanjut usia.** Teks besar, kontras tinggi, bahasa Indonesia sederhana, dan ikon yang jelas.

---

## 8. Metrik Keberhasilan

Metrik diukur melalui **Mode Latihan** (simulasi evakuasi) dan dibandingkan dengan cara manual (telepon/grup WA) sebagai pembanding.

| ID | Metrik | Definisi | Target awal* |
|---|---|---|---|
| M-1 | Waktu lapor 90% | Waktu dari aktivasi siaga sampai 90% rumah melapor | ≤ 15 menit |
| M-2 | Waktu lapor 100% | Waktu sampai seluruh rumah memiliki status (termasuk via relawan) | ≤ 45 menit |
| M-3 | Jangkauan warga rentan | Persentase rumah dengan warga rentan yang dijangkau relawan dalam 30 menit | ≥ 90% |
| M-4 | Waktu rekap | Waktu dari akhir siaga sampai rekap siap dikirim | ≤ 5 menit |
| M-5 | Keberhasilan relay offline | Persentase laporan yang dibuat tanpa sinyal dan berhasil sampai ke backend | ≥ 95% |
| M-6 | Tingkat aktivasi akun | Persentase rumah yang dapat dihubungi (aplikasi atau WhatsApp) | ≥ 80% |
| M-7 | Skor kesiapsiagaan | Rata-rata skor kesiapsiagaan rumah sebelum dan sesudah program edukasi | Naik ≥ 20 poin |

\* Target awal adalah hipotesis tim dan harus disesuaikan setelah wawancara dan simulasi pertama. Hasil pengukuran harus dilaporkan apa adanya.

---

## 9. Asumsi dan Ketergantungan

### 9.1 Asumsi

- Sebagian besar kepala keluarga memiliki HP Android dan/atau WhatsApp.
- Pengurus RT bersedia menjadi admin dan memiliki perangkat (laptop/HP) untuk dashboard.
- Terdapat warga yang bersedia menjadi relawan per blok.
- Warga bersedia memberikan data kerentanan setelah dijelaskan tujuan dan perlindungannya.
- Titik kumpul memiliki tempat aman untuk memasang WE-IRED Beacon.

### 9.2 Ketergantungan Eksternal

| Ketergantungan | Kegunaan | Risiko |
|---|---|---|
| WhatsApp Cloud API (Meta) | OTP, notifikasi, lapor, rekap | Template pesan perlu persetujuan Meta; biaya per pesan untuk pemakaian nyata; mode uji terbatas jumlah penerima. |
| Firebase Cloud Messaging | Push notification | Membutuhkan Google Play Services. |
| OpenStreetMap | Peta | Kebijakan penggunaan tile; perlu cache offline. |
| BMKG (data terbuka) | Saran aktivasi siaga | Format dan ketersediaan data dapat berubah. |
| InaRISK | Informasi risiko | Ketersediaan akses API perlu dikonfirmasi. |
| Gemini API / LLM lokal (Ollama) | Asisten AI | Wajib diungkapkan; data sensitif tidak dikirim ke layanan cloud. |

---

## 10. Risiko Produk dan Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Warga enggan memasang aplikasi | Banyak rumah tidak dapat melapor | Kanal WhatsApp (F-30) dan laporan via relawan (F-09). |
| Sinyal seluler hilang | Laporan tidak sampai | Outbox, relay relawan, mesh, beacon, Posko Lokal (F-17 s.d. F-22). |
| Kebocoran data warga rentan | Pelanggaran UU PDP, hilangnya kepercayaan | Persetujuan, akses berbasis peran, enkripsi, paket relay tanpa data kesehatan, audit log. |
| Laporan palsu/ganda | Data tidak akurat | Paket relay ditandatangani (HMAC) per rumah, ID laporan idempoten, aturan "laporan terbaru menang". |
| Pembatasan Bluetooth latar belakang di Android | Relay/check-in tidak berjalan | Foreground service selama siaga, panduan pengaturan baterai. |
| Beacon kehabisan daya | Titik kumpul tidak terlayani | Baterai 18650 + panel surya, pemantauan baterai di dashboard. |
| Hasil AI keliru | Keputusan salah | AI hanya draf/saran; selalu ditinjau pengurus. |
| Kegagalan demo Bluetooth di lokasi final | Penilaian *Functionality* turun | Skenario demo terdokumentasi, perangkat cadangan, rekaman cadangan. |

---

## 11. Privasi dan Etika Data

- Data kesehatan, data anak, dan data disabilitas termasuk **data pribadi spesifik** menurut UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi. Data ini hanya dikumpulkan dengan persetujuan eksplisit, untuk tujuan kesiapsiagaan, dan dapat dicabut oleh warga.
- Hanya Pengurus RT dan relawan yang ditugaskan pada blok terkait yang dapat melihat detail kerentanan. Admin Wilayah hanya melihat agregat.
- Paket yang tersebar melalui Bluetooth, mesh, atau beacon **hanya berisi ID rumah (pseudonim), status, kode kebutuhan, urgensi, waktu, dan tanda tangan**, tanpa nama atau data kesehatan.
- Data yang dikirim ke layanan AI cloud harus dianonimkan.
- Seluruh demo dan pengujian menggunakan **data sintetis**.

---

## 12. Kepatuhan Terhadap Aturan STACK 2026

| Aturan | Penerapan di WE-IRED |
|---|---|
| Proyek baru untuk STACK 2026 | Repositori dan kode baru; Resku dan NALARIA dicantumkan sebagai inspirasi konsep. |
| Satu kasus utama | Case 2: Stronger Communities and Everyday Services. |
| Pengungkapan bantuan AI | Penggunaan AI dalam pengembangan dan fitur F-27 dicatat di proposal dan README. |
| Fitur rencana tidak diklaim selesai | Status setiap fitur dicatat jujur (selesai / sebagian / simulasi). |
| Data simulasi ditandai | Mode Latihan dan data sintetis diberi label jelas di UI. |
| Perlindungan kredensial | Token WhatsApp, Gemini, dan FCM disimpan di variabel lingkungan, tidak di-commit. |

---

## 13. Pertanyaan Terbuka

1. Wilayah RT mana yang akan menjadi lokasi wawancara dan simulasi?
2. Apakah tim memiliki akses ke perangkat ESP32 dan komponen beacon sebelum final? (lihat [HRD.md](HRD.md))
3. Jenis bencana mana yang menjadi skenario demo utama? (rekomendasi: banjir)
4. Apakah template pesan WhatsApp sudah dapat diajukan ke Meta untuk mode uji?
5. Model LLM lokal mana yang mampu berjalan di laptop posko milik tim?
