import 'first_aid_models.dart';

class FirstAidRepository {
  static const List<FirstAidGuide> guides = [
    FirstAidGuide(
      id: 'cpr',
      title: 'Resusitasi Jantung Paru (RJP / CPR)',
      subtitle: 'Korban tidak bernapas & tidak merespons',
      iconName: 'heart_broken',
      urgencyLevel: 'kritis',
      dangerSigns: [
        'Korban tidak sadarkan diri saat dipanggil atau ditepuk pundaknya.',
        'Tidak ada napas atau napas tersengal-sengal (gasping).',
        'Denyut nadi karotis leher tidak teraba dalam 10 detik.',
      ],
      steps: [
        FirstAidStep(
          stepNumber: 1,
          title: 'Pastikan Keamanan Lingkungan (3A)',
          instruction: 'Pastikan Aman Diri (penolong), Aman Lingkungan (bebas dari reruntuhan/arus listrik/banjir), dan Aman Korban.',
        ),
        FirstAidStep(
          stepNumber: 2,
          title: 'Periksa Respon & Panggil Bantuan',
          instruction: 'Tepuk bahu korban dengan tegas: "Buka mata! Kamu dengar saya?". Jika tidak merespons, tunjuk satu orang secara spesifik untuk memanggil medis/posko relawan.',
        ),
        FirstAidStep(
          stepNumber: 3,
          title: 'Kompresi Dada Cepat & Kuat',
          instruction: 'Letakkan tumit salah satu telapak tangan di tengah dada korban (separuh bawah tulang dada). Tautkan jari tangan satunya. Tekan sedalam 5-6 cm dengan kecepatan 100-120 kali per menit (sesuai irama lagu Stayin\' Alive).',
          warning: 'Biarkan dada mengembang sempurna (recoil penuh) di setiap jeda tekanan.',
        ),
        FirstAidStep(
          stepNumber: 4,
          title: 'Kombinasi 30 Kompresi : 2 Napas Bantuan',
          instruction: 'Jika penolong terlatih, buka jalan napas (tengadahkan kepala, angkat dagu) dan berikan 2 hembusan napas tiap 30 kompresi dada. Jika tidak terlatih, lakukan Hands-Only CPR tanpa henti.',
        ),
        FirstAidStep(
          stepNumber: 5,
          title: 'Lanjutkan Hingga Petugas Medis Tiba',
          instruction: 'Jangan berhenti melakukan kompresi kecuali korban mulai bergerak/bernapas, alat AED tiba, atau penolong kelelahan fisik digantikan penolong lain.',
        ),
      ],
      thingsToAvoid: [
        'Jangan menunda kompresi untuk mengecek nadi lebih dari 10 detik.',
        'Jangan meletakkan tangan di bagian ujung bawah tulang dada (tulang taju pedang / processus xiphoideus).',
        'Jangan menyela kompresi lebih dari 10 detik.',
      ],
      sourceAttribution: 'Pedoman Resusitasi Palang Merah Indonesia (PMI) & American Heart Association (AHA)',
    ),
    FirstAidGuide(
      id: 'bleeding',
      title: 'Perdarahan Hebat & Balut Tekan',
      subtitle: 'Darah mengalir deras atau memancar dari luka',
      iconName: 'water_drop',
      urgencyLevel: 'kritis',
      dangerSigns: [
        'Darah memancar (perdarahan arteri) atau mengalir deras tanpa henti.',
        'Pembalut basah kuyup oleh darah dalam waktu kurang dari beberapa menit.',
        'Korban pucat, bibir kebiruan, dingin, atau mengeluh pusing berat (tanda syok hipovolemik).',
      ],
      steps: [
        FirstAidStep(
          stepNumber: 1,
          title: 'Gunakan Sarung Tangan / Plastik Pelindung',
          instruction: 'Hindari kontak langsung dengan darah untuk mencegah penularan penyakit.',
        ),
        FirstAidStep(
          stepNumber: 2,
          title: 'Tekan Langsung pada Luka (Direct Pressure)',
          instruction: 'Tutup luka dengan kain kasa steril atau kain bersih tebal. Tekan kuat-kuat menggunakan telapak tangan langsung di atas sumber darah selama minimal 5-10 menit tanpa dilepas.',
        ),
        FirstAidStep(
          stepNumber: 3,
          title: 'Pasang Balut Tekan',
          instruction: 'Bebat kain penutup dengan perban gulung atau kain mitela secara rapat dan kencang agar tekanan tetap terjaga.',
        ),
        FirstAidStep(
          stepNumber: 4,
          title: 'Tinggikan Bagian yang Luka (Jika Bukan Patah Tulang)',
          instruction: 'Jika luka berada di lengan atau tungkai dan tidak dicurigai patah tulang, posisikan lebih tinggi dari jantung.',
        ),
        FirstAidStep(
          stepNumber: 5,
          title: 'Pertahankan Suhu Tubuh & Pantau Tanda Syok',
          instruction: 'Selimuti korban agar tidak kedinginan. Jangan berikan makan atau minum jika korban lemas/pusing berat.',
        ),
      ],
      thingsToAvoid: [
        'Jangan mencabut kain balutan pertama jika darah merembes; tambahkan kain baru di atasnya dan tekan lebih kuat.',
        'Jangan mencabut benda yang tertancap di tubuh korban (imobilisasi benda tersebut dengan bantalan di sekelilingnya).',
        'Jangan memasang torniket improvisasi sembarangan kecuali pendarahan ekstrem pada anggota gerak yang mengancam nyawa.',
      ],
      sourceAttribution: 'Buku Pedoman Pertolongan Pertama PMI & Stop The Bleed',
    ),
    FirstAidGuide(
      id: 'fracture',
      title: 'Patah Tulang & Imobilisasi (Bidai)',
      subtitle: 'Bentuk tulang abnormal, nyeri hebat saat digerakkan',
      iconName: 'healing',
      urgencyLevel: 'tinggi',
      dangerSigns: [
        'Ujung tulang mencuat menembus kulit (patah tulang terbuka).',
        'Bagian ujung jari tangan atau kaki mati rasa, pucat, atau membiru.',
        'Nyeri tidak tertahankan dan korban tidak dapat menopang beban sama sekali.',
      ],
      steps: [
        FirstAidStep(
          stepNumber: 1,
          title: 'Tenangkan Korban & Istirahatkan Bagian Cedera',
          instruction: 'Minta korban jangan bergerak. Jangan mencoba meluruskan atau menarik tulang yang bengkok ke posisi semula.',
        ),
        FirstAidStep(
          stepNumber: 2,
          title: 'Atasi Perdarahan Terlebih Dahulu',
          instruction: 'Jika terdapat luka terbuka, tutup dengan kain steril tanpa menekan ujung tulang yang menonjol.',
        ),
        FirstAidStep(
          stepNumber: 3,
          title: 'Pasang Bidai (Spalk) Melewati 2 Sendi',
          instruction: 'Gunakan papan kaku, bilah kayu, atau gulungan karton tebal. Panjang bidai harus mencakup sendi di atas dan sendi di bawah tulang yang patah.',
        ),
        FirstAidStep(
          stepNumber: 4,
          title: 'Ikat Bidai dengan Ikatan Rapat tapi Tidak Memutus Darah',
          instruction: 'Ikat bidai menggunakan kain atau perban pada minimal 3 titik. Pastikan denyut nadi dan aliran darah di ujung jari masih teraba hangat.',
        ),
      ],
      thingsToAvoid: [
        'Jangan mencoba memijat, mengurut, atau mereposisi tulang.',
        'Jangan memindahkan korban yang dicurigai cedera leher/tulang belakang tanpa papan evakuasi (spine board).',
        'Jangan mengikat bidai langsung di atas lokasi patahan tulang.',
      ],
      sourceAttribution: 'Panduan Penanganan Trauma Muskuloskeletal PMI & BNPB',
    ),
    FirstAidGuide(
      id: 'burns',
      title: 'Pertolongan Luka Bakar',
      subtitle: 'Akibat api, air panas, atau sengatan panas bencana',
      iconName: 'local_fire_department',
      urgencyLevel: 'tinggi',
      dangerSigns: [
        'Luka bakar meliputi area wajah, leher, dada, persendian, atau selangkangan.',
        'Kulit tampak menghitam arang atau putih kering tanpa rasa sakit (derajat 3 luas).',
        'Korban menghirup asap pekat, suara serak, atau batuk berjelaga (cedera inhalasi).',
      ],
      steps: [
        FirstAidStep(
          stepNumber: 1,
          title: 'Dinginkan dengan Air Mengalir Suhu Ruang',
          instruction: 'Segera alirkan air bersih mengalir pada area luka bakar selama 15-20 menit. Pendinginan air menghentikan kerusakan jaringan ke lapisan dalam.',
        ),
        FirstAidStep(
          stepNumber: 2,
          title: 'Lepaskan Perhiasan & Pakaian Longgar',
          instruction: 'Lepaskan cincin, jam, atau gelang sebelum area membengkak. Jika pakaian menempel lekat pada luka, gunting di sekelilingnya tanpa mencabut paksa.',
        ),
        FirstAidStep(
          stepNumber: 3,
          title: 'Tutup dengan Kain Kasa Bersih / Plastik Wrap',
          instruction: 'Tutup luka secara longgar menggunakan plastik pembungkus makanan bersih atau kain kasa steril non-lengket untuk mencegah kontaminasi kuman.',
        ),
      ],
      thingsToAvoid: [
        'Jangan pernah mengoleskan odol, kecap, mentega, minyak, atau bubuk kopi pada luka bakar.',
        'Jangan menggunakan es batu atau air es langsung karena dapat menyebabkan radang dingin (frostbite tissue damage).',
        'Jangan memecahkan gelembung lepuh (bula).',
      ],
      sourceAttribution: 'World Health Organization (WHO) Burns First Aid Guideline & PMI',
    ),
    FirstAidGuide(
      id: 'hypothermia',
      title: 'Hipotermia & Penurunan Suhu Tubuh',
      subtitle: 'Kedinginan parah akibat basah kuyup banjir/hujan',
      iconName: 'ac_unit',
      urgencyLevel: 'tinggi',
      dangerSigns: [
        'Korban berhenti menggigil padahal masih sangat dingin (tanda hipotermia berat).',
        'Bicara meracau, gagap, mengantuk ekstrem, atau hilang koordinasi gerak.',
        'Pernapasan melambat drastis dan denyut nadi lemah.',
      ],
      steps: [
        FirstAidStep(
          stepNumber: 1,
          title: 'Pindahkan ke Tempat Kering & Terlindung Angin',
          instruction: 'Bawa korban masuk ke dalam ruangan tertutup atau posko yang hangat.',
        ),
        FirstAidStep(
          stepNumber: 2,
          title: 'Ganti Pakaian Basah Segera',
          instruction: 'Tanggalkan pakaian basah dan keringkan tubuh dengan handuk kering.',
        ),
        FirstAidStep(
          stepNumber: 3,
          title: 'Hangatkan Tubuh Bertahap (Pasif ke Aktif)',
          instruction: 'Bungkus korban dengan selimut berlapis termasuk menutupi kepala (biarkan wajah terbuka). Berikan botol air hangat yang dilapisi handuk di ketiak, leher, dan selangkangan.',
        ),
        FirstAidStep(
          stepNumber: 4,
          title: 'Berikan Minuman Hangat Manis',
          instruction: 'Hanya jika korban sadar penuh dan dapat menelan tanpa tersedak.',
        ),
      ],
      thingsToAvoid: [
        'Jangan memijat atau menggosok lengan dan tungkai korban dengan kasar.',
        'Jangan langsung merendam korban ke air panas mendadak (bisa memicu syok aritmia jantung).',
        'Jangan berikan minuman berkafein atau beralkohol.',
      ],
      sourceAttribution: 'Panduan Evakuasi Medis Penanganan Banjir BNPB & PMI',
    ),
    FirstAidGuide(
      id: 'heatstroke',
      title: 'Dehidrasi Berat & Sengatan Panas (Heatstroke)',
      subtitle: 'Suhu tubuh sangat tinggi, pusing, pingsan',
      iconName: 'wb_sunny',
      urgencyLevel: 'tinggi',
      dangerSigns: [
        'Suhu tubuh tinggi (> 40°C), kulit panas kering dan tidak berkeringat sama sekali.',
        'Korban mengalami disorientasi, kejang, atau hilang kesadaran.',
        'Muntah-muntah dan denyut jantung cepat memburu.',
      ],
      steps: [
        FirstAidStep(
          stepNumber: 1,
          title: 'Pindahkan ke Tempat Teduh & Berangin',
          instruction: 'Segera posisikan korban di tempat sejuk dengan sirkulasi udara baik.',
        ),
        FirstAidStep(
          stepNumber: 2,
          title: 'Dinginkan Tubuh Secara Agresif',
          instruction: 'Lepaskan pakaian luar. Basahi tubuh dengan air dingin dan kipasi. Tempelkan kompres dingin di leher, ketiak, dan selangkangan.',
        ),
        FirstAidStep(
          stepNumber: 3,
          title: 'Berikan Cairan Oralit / Air Bertahap',
          instruction: 'Bila korban sadar penuh, berikan larutan oralit atau air dingin secara perlahan-lahan.',
        ),
      ],
      thingsToAvoid: [
        'Jangan memaksa korban pingsan atau setengah sadar untuk minum.',
        'Jangan memberikan obat penurun panas (seperti parasetamol) karena heatstroke bukan disebabkan oleh infeksi pirogen.',
      ],
      sourceAttribution: 'Kementerian Kesehatan RI & Wilderness Medical Society',
    ),
    FirstAidGuide(
      id: 'drowning',
      title: 'Pertolongan Korban Tenggelam',
      subtitle: 'Korban dievakuasi dari genangan banjir / arus deras',
      iconName: 'pool',
      urgencyLevel: 'kritis',
      dangerSigns: [
        'Korban tidak sadarkan diri setelah dievakuasi dari air.',
        'Wajah dan bibir membiru (sianosis akibat kekurangan oksigen).',
        'Tidak bernapas atau dada tidak bergerak naik-turun.',
      ],
      steps: [
        FirstAidStep(
          stepNumber: 1,
          title: 'Keluarkan Korban dari Air dengan Aman',
          instruction: 'Gunakan pelampung, tali, atau perahu. Jangan membahayakan diri sendiri jika arus air terlalu deras.',
        ),
        FirstAidStep(
          stepNumber: 2,
          title: 'Baringkan di Permukaan Rata & Buka Jalan Napas',
          instruction: 'Baringkan telentang, miringkan kepala jika korban muntah air agar cairan keluar dari mulut.',
        ),
        FirstAidStep(
          stepNumber: 3,
          title: 'Mulai dengan 5 Napas Bantuan',
          instruction: 'Pada korban tenggelam, kekurangan oksigen adalah masalah utama. Berikan 5 napas buatan penyelamat awal.',
        ),
        FirstAidStep(
          stepNumber: 4,
          title: 'Lanjutkan dengan RJP 30:2',
          instruction: 'Jika tetap tidak bernapas, lakukan kompresi dada 30 kali diikuti 2 napas buatan secara berulang.',
        ),
      ],
      thingsToAvoid: [
        'Jangan mencoba mengeluarkan air dari perut dengan menekan perut korban (dapat memicu muntah masuk ke paru-paru).',
        'Jangan meninggalkan korban sendirian meskipun tampak pulih (waspadai secondary drowning dalam 24 jam).',
      ],
      sourceAttribution: 'Pedoman Penyelamatan Air & Resusitasi Korban Tenggelam Basarnas & ILS',
    ),
  ];

  static FirstAidGuide? getGuideById(String id) {
    try {
      return guides.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }
}
