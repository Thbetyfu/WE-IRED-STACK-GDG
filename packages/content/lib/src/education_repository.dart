import 'education_models.dart';

class EducationRepository {
  static const List<EmergencyBagItem> defaultBagItems = [
    EmergencyBagItem(
      id: 'doc_waterproof',
      name: 'Dokumen Penting (Kedap Air)',
      category: 'dokumen',
      description: 'Fotokopi KK, KTP, surat nikah, sertifikat rumah, dan polis asuransi dalam kantong plastik zipper kedap air.',
      isEssential: true,
    ),
    EmergencyBagItem(
      id: 'first_aid_kit',
      name: 'Kotak P3K & Obat Rutin Keluarga',
      category: 'p3k',
      description: 'Kasa steril, perban, antiseptik, plester, obat penurun demam, serta cadangan obat rutin (obat darah tinggi/asma/diabetes minimal 5 hari).',
      isEssential: true,
    ),
    EmergencyBagItem(
      id: 'drinking_water',
      name: 'Air Mineral (3 Liter / Orang)',
      category: 'pangan',
      description: 'Kebutuhan hidrasi minimal darurat untuk bertahan 3 hari sebelum bantuan logistik masuk.',
      isEssential: true,
    ),
    EmergencyBagItem(
      id: 'ration_food',
      name: 'Makanan Siap Saji Tahan Lama',
      category: 'pangan',
      description: 'Biskuit berkalori tinggi, makanan kaleng dengan pembuka mandiri, cokelat batangan, atau sereal kering.',
      isEssential: true,
    ),
    EmergencyBagItem(
      id: 'flashlight_torch',
      name: 'Senter & Baterai Cadangan',
      category: 'alat',
      description: 'Senter LED terang hemat daya beserta 2 set baterai cadangan yang tersimpan terpisah.',
      isEssential: true,
    ),
    EmergencyBagItem(
      id: 'emergency_whistle',
      name: 'Peluit Darurat (Tanpa Bola)',
      category: 'alat',
      description: 'Sangat vital untuk memberi sinyal posisi kepada tim evakuasi jika terjebak reruntuhan tanpa menghabiskan energi berteriak.',
      isEssential: true,
    ),
    EmergencyBagItem(
      id: 'clothes_blanket',
      name: 'Pakaian Ganti & Selimut Termal',
      category: 'sandang',
      description: '1 set pakaian hangat, celana panjang, pakaian dalam, jas hujan ponco, dan selimut darurat foil ringan.',
      isEssential: true,
    ),
    EmergencyBagItem(
      id: 'cash_money',
      name: 'Uang Tunai Pecahan Kecil',
      category: 'dokumen',
      description: 'Uang tunai fisik untuk kebutuhan darurat saat listrik padam dan mesin ATM/QRIS tidak berfungsi.',
      isEssential: true,
    ),
    EmergencyBagItem(
      id: 'mask_hygiene',
      name: 'Masker & Alat Higienitas',
      category: 'sandang',
      description: 'Masker medis / N95 untuk melindungi pernapasan dari debu runtuhan atau abu, tisu basah, dan sabun antiseptik.',
      isEssential: false,
    ),
    EmergencyBagItem(
      id: 'powerbank',
      name: 'Powerbank Terisi Penuh',
      category: 'alat',
      description: 'Kapasitas minimal 10.000 mAh untuk menyuplai daya ponsel pelaporan darurat dan relay Bluetooth.',
      isEssential: false,
    ),
  ];

  static const List<EducationModule> modules = [
    EducationModule(
      id: 'mod_banjir',
      title: 'Kesiapsiagaan & Tanggap Bencana Banjir',
      disasterType: 'banjir',
      estimatedMinutes: 5,
      summary: 'Langkah taktis keluarga sebelum luapan air, saat evakuasi darurat, dan pencegahan sengatan arus listrik.',
      officialSource: 'Buku Pedoman Siaga Banjir BNPB RI & BMKG',
      bulletPoints: [
        'Ketahui ketinggian air di hulu sungai dan pantau informasi RT.',
        'Matikan MCB listrik utama dan cabut seluruh peralatan elektronik dari stop kontak sebelum air memasuki rumah.',
        'Pindahkan dokumen dan barang elektronik ke tempat tinggi.',
        'Evakuasi warga lansia, balita, dan penyandang disabilitas ke titik kumpul sebelum ketinggian air melebihi 50 cm.',
        'Jangan berjalan atau berkendara menerobos genangan air berarus deras.',
      ],
      quiz: [
        QuizQuestion(
          id: 'q_banjir_1',
          question: 'Apa tindakan pertama yang wajib dilakukan saat air banjir mulai memasuki pekarangan rumah?',
          choices: [
            QuizChoice(
              id: 'c1',
              text: 'Mematikan saklar listrik utama (MCB) di meteran rumah',
              isCorrect: true,
              explanation: 'Benar! Mematikan MCB mencegah risiko korsleting mematikan dan sengatan arus listrik di air genangan.',
            ),
            QuizChoice(
              id: 'c2',
              text: 'Menguras air keluar dengan ember',
              isCorrect: false,
              explanation: 'Salah. Menguras air saat debit terus naik menguras tenaga dan menunda waktu evakuasi keselamatan jiwa.',
            ),
            QuizChoice(
              id: 'c3',
              text: 'Menyalakan pompa air celup di stop kontak lantai',
              isCorrect: false,
              explanation: 'Sangat berbahaya! Memasang peralatan listrik saat ada genangan dapat memicu sengatan arus fatal.',
            ),
          ],
        ),
        QuizQuestion(
          id: 'q_banjir_2',
          question: 'Mengapa dilarang menerobos genangan banjir setinggi lutut yang memiliki arus?',
          choices: [
            QuizChoice(
              id: 'c1',
              text: 'Arus setinggi 15 cm sudah mampu menjatuhkan orang dewasa dan membawa risiko lubang got/saluran terbuka yang tak terlihat',
              isCorrect: true,
              explanation: 'Tepat sekali! Daya dorong air berarus sangat kuat dan dasar genangan sering menyembunyikan lubang selokan maut.',
            ),
            QuizChoice(
              id: 'c2',
              text: 'Hanya karena membuat pakaian basah',
              isCorrect: false,
              explanation: 'Bukan sekadar pakaian basah, melainkan bahaya hanyut dan terperosok ke gorong-gorong terbuka.',
            ),
          ],
        ),
      ],
    ),
    EducationModule(
      id: 'mod_gempa',
      title: 'Mitigasi & Aksi Perlindungan Gempa Bumi',
      disasterType: 'gempa',
      estimatedMinutes: 6,
      summary: 'Prinsip Drop-Cover-Hold On, jalur evakuasi aman, dan prosedur evakuasi pasca guncangan gempa.',
      officialSource: 'Panduan Mitigasi Gempa Bumi BMKG & BNPB',
      bulletPoints: [
        'Saat guncangan kuat: Lakukan Drop, Cover, Hold On (Jatuhkan diri, Lindungi kepala di bawah meja kokoh, Pegangan).',
        'Jauhi jendela kaca, cermin, lemari tinggi, dan lampu gantung.',
        'Jika berada di luar ruangan, jauhi tiang listrik, kabel, pohon tinggi, dan papan reklame.',
        'Setelah guncangan berhenti, keluar melalui tangga darurat (JANGAN gunakan lift) menuju titik kumpul terbuka.',
        'Periksa saluran kompor gas dan meteran listrik sebelum meninggalkan rumah.',
      ],
      quiz: [
        QuizQuestion(
          id: 'q_gempa_1',
          question: 'Apa langkah paling tepat saat berada di dalam rumah dan terjadi guncangan gempa keras?',
          choices: [
            QuizChoice(
              id: 'c1',
              text: 'Berlindung di bawah meja kokoh sambil memegang kaki meja dan melindungi leher/kepala',
              isCorrect: true,
              explanation: 'Benar! Prinsip Drop, Cover, and Hold On melindungi kepala dan leher dari reruntuhan plafon dan benda jatuh.',
            ),
            QuizChoice(
              id: 'c2',
              text: 'Langsung berlari panik keluar rumah menerobos pintu',
              isCorrect: false,
              explanation: 'Berlari saat guncangan meningkatkan risiko tertimpa genteng, kaca jendela, atau roboh tertimpa bingkai pintu.',
            ),
            QuizChoice(
              id: 'c3',
              text: 'Berdiri di dekat lemari kaca untuk menahan barang',
              isCorrect: false,
              explanation: 'Sangat berbahaya! Kaca dan lemari dapat pecah serta menimpa tubuh Anda.',
            ),
          ],
        ),
      ],
    ),
    EducationModule(
      id: 'mod_longsor',
      title: 'Waspada Tanah Longsor & Pergerakan Tanah',
      disasterType: 'longsor',
      estimatedMinutes: 5,
      summary: 'Tanda-tanda alam pergerakan tanah tebing, keretakan lereng, dan prosedur evakuasi malam hari.',
      officialSource: 'Badan Geologi & Pusat Vulkanologi dan Mitigasi Bencana Geologi (PVMBG)',
      bulletPoints: [
        'Waspadai munculnya retakan baru di dinding rumah, halaman, atau lereng tebing setelah hujan deras.',
        'Perhatikan jika pintu dan jendela rumah mendadak sulit dibuka atau macet (tanda pergeseran pondasi).',
        'Air sumur atau mata air lereng mendadak keruh berlumpur.',
        'Terdengar suara gemuruh menggelegar dari arah bukit.',
        'Segera tinggalkan area lereng menuju titik kumpul zona aman berjarak minimal 200 meter dari kaki bukit.',
      ],
      quiz: [
        QuizQuestion(
          id: 'q_longsor_1',
          question: 'Salah satu tanda awal alamiah terjadinya ketidakstabilan lereng bukit sebelum longsor adalah:',
          choices: [
            QuizChoice(
              id: 'c1',
              text: 'Muncul retakan di tanah/dinding, tiang listrik miring, dan air rembesan lereng berubah keruh berlumpur',
              isCorrect: true,
              explanation: 'Benar! Retakan dan air tanah keruh adalah indikator kuat massa tanah lereng mulai jenuh air dan bergerak.',
            ),
            QuizChoice(
              id: 'c2',
              text: 'Udara terasa sangat panas dan terik',
              isCorrect: false,
              explanation: 'Tanah longsor umumnya dipicu oleh curah hujan tinggi yang menjenuhkan pori-pori tanah lereng.',
            ),
          ],
        ),
      ],
    ),
    EducationModule(
      id: 'mod_kebakaran',
      title: 'Tanggap Darurat Kebakaran Pemukiman Padat',
      disasterType: 'kebakaran',
      estimatedMinutes: 5,
      summary: 'Prosedur pemadaman awal, keselamatan dari asap beracun, dan evakuasi rute sempit di lingkungan RT.',
      officialSource: 'Dinas Penanggulangan Kebakaran dan Penyelamatan (Damkar)',
      bulletPoints: [
        'Jika tabung gas bocor, JANGAN menyalakan atau mematikan saklar listrik lampu; segera lepas regulator.',
        'Gunakan karung/kain goni basah untuk memadamkan api wajan penggorengan yang terbakar minyak.',
        'Saat terjebak asap tebal, merayaplah rendah dekat lantai karena udara bersih oksigen berada di bawah.',
        'Tutup hidung dan mulut dengan kain basah.',
        'Sentuh daun pintu dengan punggung tangan; jika terasa panas, cari rute keluar alternatif.',
      ],
      quiz: [
        QuizQuestion(
          id: 'q_kebakaran_1',
          question: 'Bagaimana posisi tubuh yang benar saat harus meloloskan diri dari ruangan yang dipenuhi asap tebal?',
          choices: [
            QuizChoice(
              id: 'c1',
              text: 'Merangkak/merayap rendah di dekat lantai dengan mulut tertutup kain basah',
              isCorrect: true,
              explanation: 'Benar! Udara panas dan gas beracun (karbon monoksida) naik ke atas, sehingga lapisan oksigen aman ada di bawah 30 cm dari lantai.',
            ),
            QuizChoice(
              id: 'c2',
              text: 'Berlari tegak secepat mungkin sambil bernapas dalam-dalam',
              isCorrect: false,
              explanation: 'Menghirup asap panas di posisi tegak dapat menyebabkan luka bakar saluran pernapasan dalam hitungan detik.',
            ),
          ],
        ),
      ],
    ),
  ];

  static EducationModule? getModuleById(String id) {
    try {
      return modules.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}
