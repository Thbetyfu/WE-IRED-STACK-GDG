import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

class AnnouncementItem {
  final String id;
  final String title;
  final String content;
  final String level; // 'info', 'peringatan', 'darurat'
  final DateTime createdAt;
  final bool isEd25519Verified;
  final List<String> channels;
  final String author;

  const AnnouncementItem({
    required this.id,
    required this.title,
    required this.content,
    required this.level,
    required this.createdAt,
    this.isEd25519Verified = true,
    this.channels = const ['WhatsApp', 'Push Notifikasi', 'Relay BLE'],
    this.author = 'Pengurus RT 05',
  });
}

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  String _selectedFilter = 'all'; // 'all', 'darurat', 'peringatan', 'info'

  static final List<AnnouncementItem> _allAnnouncements = [
    AnnouncementItem(
      id: 'ann-01',
      title: 'Instruksi Kesiapsiagaan Siaga 1 Banjir',
      content:
          'Debit air Kali Ciliwung mencapai status Siaga 1. Seluruh warga RT 05 Blok A dan B dimohon segera menaikkan dokumen penting ke lantai dua, mematikan saklar listrik utama, dan bersiap menuju Titik Kumpul Balai RW bila sirine dibunyikan.',
      level: 'darurat',
      createdAt: DateTime.now().subtract(const Duration(minutes: 42)),
      isEd25519Verified: true,
      channels: ['WhatsApp', 'Push Notifikasi', 'Relay BLE'],
      author: 'Ketua RT 05 Bpk. Budi',
    ),
    AnnouncementItem(
      id: 'ann-02',
      title: 'Jadwal Simulasi Evakuasi Bersama RT',
      content:
          'Simulasi evakuasi mandiri dan uji coba check-in otomatis WE-IRED Beacon akan diselenggarakan pada hari Minggu pukul 09.00 WIB. Mohon seluruh warga membawa Tas Siaga Bencana masing-masing.',
      level: 'peringatan',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      isEd25519Verified: true,
      channels: ['WhatsApp', 'Push Notifikasi'],
      author: 'Seksi Siaga Bencana RT',
    ),
    AnnouncementItem(
      id: 'ann-03',
      title: 'Pembagian Wilayah & Kontak Relawan Per Blok',
      content:
          'Relawan Blok A dipegang Bpk Hendra, Blok B Ibu Siti, dan Blok C Sdr Denny. Jika listrik dan sinyal padam total, laporan darurat dapat dititipkan secara offline saat relawan melintas di depan rumah Anda.',
      level: 'info',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      isEd25519Verified: true,
      channels: ['WhatsApp', 'Relay BLE'],
      author: 'Pengurus RT 05',
    ),
  ];

  List<AnnouncementItem> get _filteredAnnouncements {
    if (_selectedFilter == 'all') return _allAnnouncements;
    return _allAnnouncements.where((a) => a.level.toLowerCase() == _selectedFilter.toLowerCase()).toList();
  }

  void _showDetailModal(AnnouncementItem item) {
    final isDarurat = item.level == 'darurat';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDarurat ? AppTheme.statusKritisBg : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDarurat ? AppTheme.statusKritisBorder : AppTheme.statusAmanBorder,
                      ),
                    ),
                    child: Text(
                      isDarurat ? 'STATUS DARURAT' : item.level.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDarurat ? AppTheme.statusKritis : AppTheme.statusAman,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.slate900),
              ),
              const SizedBox(height: 6),
              Text(
                'Diterbitkan oleh ${item.author}',
                style: const TextStyle(fontSize: 12, color: AppTheme.slate600),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Text(
                  item.content,
                  style: const TextStyle(fontSize: 14, color: AppTheme.slate800, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kanal Distribusi Resmi:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.slate700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: item.channels.map((ch) {
                  return Chip(
                    label: Text(ch, style: const TextStyle(fontSize: 11)),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.borderSubtle),
                    avatar: const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.statusAman),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: AppTheme.statusAman),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pesan terverifikasi tanda tangan digital Ed25519. Bebas dari manipulasi pihak luar.',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.statusAman),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredAnnouncements;

    return Scaffold(
      backgroundColor: AppTheme.bgCanvas,
      appBar: AppBar(
        title: const Text(
          'Pengumuman Resmi RT',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chip Selector
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Semua (${_allAnnouncements.length})',
                      isSelected: _selectedFilter == 'all',
                      onTap: () => setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Darurat',
                      isSelected: _selectedFilter == 'darurat',
                      onTap: () => setState(() => _selectedFilter = 'darurat'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Peringatan',
                      isSelected: _selectedFilter == 'peringatan',
                      onTap: () => setState(() => _selectedFilter = 'peringatan'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Info RT',
                      isSelected: _selectedFilter == 'info',
                      onTap: () => setState(() => _selectedFilter = 'info'),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppTheme.borderSubtle),

            // Announcements List View
            Expanded(
              child: list.isEmpty
                  ? EmptyStateView(
                      title: 'Tidak Ada Pengumuman',
                      description: 'Tidak ada pengumuman untuk filter kategori ini.',
                      icon: Icons.campaign_outlined,
                      actionLabel: 'Tampilkan Semua',
                      onAction: () => setState(() => _selectedFilter = 'all'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (ctx, i) {
                        final ann = list[i];
                        final isDarurat = ann.level == 'darurat';

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showDetailModal(ann),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDarurat ? AppTheme.statusKritisBorder : AppTheme.borderSubtle,
                                  width: isDarurat ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isDarurat ? AppTheme.statusKritisBg : const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isDarurat ? 'DARURAT' : (ann.level == 'peringatan' ? 'SIAGA' : 'INFO'),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isDarurat ? AppTheme.statusKritis : AppTheme.statusAman,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.verified, size: 10, color: AppTheme.statusAman),
                                      const SizedBox(width: 2),
                                      const Text(
                                        'Ed25519',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.statusAman),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _timeAgo(ann.createdAt),
                                        style: const TextStyle(fontSize: 9.5, color: AppTheme.slate500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    ann.title,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.slate900),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    ann.content,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.slate700, height: 1.4),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Oleh: ${ann.author}',
                                          style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Baca Selengkapnya →',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt lalu';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    } else {
      return '${diff.inDays} hari lalu';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : AppTheme.slate100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppTheme.primaryBlue : AppTheme.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.slate700,
          ),
        ),
      ),
    );
  }
}
