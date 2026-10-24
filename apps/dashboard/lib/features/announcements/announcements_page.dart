import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:core/core.dart';

import '../../app/auth_provider.dart';
import 'announcements_provider.dart';

class AnnouncementsPage extends ConsumerWidget {
  const AnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final annState = ref.watch(announcementsProvider);
    final annNotifier = ref.read(announcementsProvider.notifier);
    final rtName = authState.selectedRT?.name ?? 'RT 01';
    final rtId = authState.selectedRT?.id ?? 'rt-01';

    // Filter active announcements only per rule (FR-ANN-01..04)
    final activeList = annState.announcements.where((a) => !a.isExpired).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pusat Siaran Pengumuman Darurat: $rtName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Editor siaran pengumuman 160 karakter bertanda tangan Ed25519 dan distribusi multi-jalur (FCM, WhatsApp, BLE Mesh Relay).',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Segarkan data',
                  icon: const Icon(Icons.refresh, color: Color(0xFF475569)),
                  onPressed: () => annNotifier.loadAnnouncements(rtId),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Buat Pengumuman Baru',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showCreateAnnouncementDialog(context, ref, rtId),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Cryptographic Security Banner (SDD 7.6 & 9.1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: Color(0xFF2563EB), size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Integritas Kriptografi: Setiap pengumuman otomatis ditandatangani dengan kunci privat Ed25519 (Format SDD 7.6). Perangkat warga dan beacon hanya menerima siaran dengan tanda tangan terverifikasi.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Active Announcements List or Empty State
            if (annState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (activeList.isEmpty)
              _buildEmptyState()
            else
              Column(
                children: activeList.map((ann) => _AnnouncementCard(announcement: ann)).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.campaign_outlined, size: 64, color: Color(0xFF94A3B8)),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Pengumuman Aktif di RT Ini',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: const Text(
                  'Pengumuman darurat, penting, atau informasi posko yang disiarkan oleh pengurus akan muncul di sini dan disinkronkan ke seluruh warga.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateAnnouncementDialog(BuildContext context, WidgetRef ref, String rtId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AnnouncementEditorDialog(rtId: rtId),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final expiresStr = dateFormat.format(announcement.expiresAt);

    Color badgeBg;
    Color badgeText;
    IconData badgeIcon;
    String badgeLabel;

    switch (announcement.level) {
      case AnnouncementLevel.darurat:
        badgeBg = const Color(0xFFFEE2E2);
        badgeText = const Color(0xFFDC2626);
        badgeIcon = Icons.warning_amber_rounded;
        badgeLabel = 'DARURAT';
        break;
      case AnnouncementLevel.penting:
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        badgeIcon = Icons.priority_high_rounded;
        badgeLabel = 'PENTING';
        break;
      case AnnouncementLevel.info:
        badgeBg = const Color(0xFFEFF6FF);
        badgeText = const Color(0xFF2563EB);
        badgeIcon = Icons.info_outline_rounded;
        badgeLabel = 'INFO';
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Meta Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeText),
                      const SizedBox(width: 6),
                      Text(
                        badgeLabel,
                        style: TextStyle(
                          color: badgeText,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Ed25519 Verified Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, size: 12, color: Color(0xFF059669)),
                      SizedBox(width: 4),
                      Text(
                        'Ed25519 Valid',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Berlaku s/d $expiresStr WIB',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Message Text
            Text(
              announcement.text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 14),

            // Distribution Channels & Short ID
            Row(
              children: [
                const Text(
                  'Kanal Distribusi: ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 6),
                ...announcement.channels.map((ch) => _ChannelPill(channel: ch)),
                const Spacer(),
                Text(
                  'ID Pendek: ${announcement.shortId}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'monospace'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelPill extends StatelessWidget {
  final String channel;

  const _ChannelPill({required this.channel});

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;
    Color color;

    switch (channel.toLowerCase()) {
      case 'push':
        label = 'Push / FCM';
        icon = Icons.notifications_active;
        color = const Color(0xFF2563EB);
        break;
      case 'whatsapp':
        label = 'WhatsApp';
        icon = Icons.chat;
        color = const Color(0xFF059669);
        break;
      case 'relay':
        label = 'BLE Mesh / Beacon';
        icon = Icons.bluetooth;
        color = const Color(0xFF7C3AED);
        break;
      default:
        label = channel;
        icon = Icons.send;
        color = const Color(0xFF475569);
    }

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementEditorDialog extends ConsumerStatefulWidget {
  final String rtId;

  const _AnnouncementEditorDialog({required this.rtId});

  @override
  ConsumerState<_AnnouncementEditorDialog> createState() => _AnnouncementEditorDialogState();
}

class _AnnouncementEditorDialogState extends ConsumerState<_AnnouncementEditorDialog> {
  final _textController = TextEditingController();
  AnnouncementLevel _level = AnnouncementLevel.info;
  int _expireHours = 6;
  bool _channelPush = true;
  bool _channelWhatsApp = true;
  bool _channelRelay = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        if (_textController.text.length > 160) {
          _localError = 'Batas maksimal pengumuman adalah 160 karakter';
        } else {
          _localError = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final annState = ref.watch(announcementsProvider);
    final annNotifier = ref.read(announcementsProvider.notifier);
    final charCount = _textController.text.length;
    final isExceeded = charCount > 160;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dialog Title
              Row(
                children: [
                  const Icon(Icons.campaign, color: Color(0xFF1E3A8A), size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Editor Pengumuman Resmi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Level Selector
              const Text('Tingkat Pengumuman (Level):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _LevelRadio(
                    title: 'Info',
                    level: AnnouncementLevel.info,
                    selectedLevel: _level,
                    onSelected: (lvl) => setState(() => _level = lvl),
                  ),
                  const SizedBox(width: 8),
                  _LevelRadio(
                    title: 'Penting',
                    level: AnnouncementLevel.penting,
                    selectedLevel: _level,
                    onSelected: (lvl) => setState(() => _level = lvl),
                  ),
                  const SizedBox(width: 8),
                  _LevelRadio(
                    title: 'Darurat',
                    level: AnnouncementLevel.darurat,
                    selectedLevel: _level,
                    onSelected: (lvl) => setState(() => _level = lvl),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Message Input & Live Character Counter (max 160 chars per FR-ANN-01)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Teks Pengumuman:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    '$charCount / 160 karakter',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isExceeded
                          ? const Color(0xFFDC2626)
                          : charCount >= 140
                              ? const Color(0xFFD97706)
                              : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _textController,
                maxLines: 4,
                maxLength: 160,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                decoration: InputDecoration(
                  hintText: 'Tulis pesan singkat pengumuman resmi (maksimal 160 karakter)...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  errorText: _localError,
                ),
              ),
              const SizedBox(height: 16),

              // Expiry Duration Selector
              Row(
                children: [
                  const Expanded(
                    child: Text('Masa Berlaku Pengumuman:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  DropdownButton<int>(
                    value: _expireHours,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 Jam')),
                      DropdownMenuItem(value: 3, child: Text('3 Jam')),
                      DropdownMenuItem(value: 6, child: Text('6 Jam')),
                      DropdownMenuItem(value: 12, child: Text('12 Jam')),
                      DropdownMenuItem(value: 24, child: Text('24 Jam (1 Hari)')),
                      DropdownMenuItem(value: 48, child: Text('48 Jam (2 Hari)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _expireHours = val);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Channels Multi-Select
              const Text('Kanal Distribusi:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                children: [
                  FilterChip(
                    label: const Text('Push (FCM Topik RT)'),
                    selected: _channelPush,
                    onSelected: (val) => setState(() => _channelPush = val),
                  ),
                  FilterChip(
                    label: const Text('WhatsApp Blast'),
                    selected: _channelWhatsApp,
                    onSelected: (val) => setState(() => _channelWhatsApp = val),
                  ),
                  FilterChip(
                    label: const Text('BLE Mesh & Beacon Relay'),
                    selected: _channelRelay,
                    onSelected: (val) => setState(() => _channelRelay = val),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Error banner if any
              if (annState.errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          annState.errorMessage!,
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: annState.isSubmitting || isExceeded
                        ? null
                        : () async {
                            final channels = <String>[];
                            if (_channelPush) channels.add('push');
                            if (_channelWhatsApp) channels.add('whatsapp');
                            if (_channelRelay) channels.add('relay');

                            final expiresAt = DateTime.now().add(Duration(hours: _expireHours));

                            final success = await annNotifier.createAnnouncement(
                              rtId: widget.rtId,
                              level: _level,
                              text: _textController.text,
                              expiresAt: expiresAt,
                              channels: channels,
                            );

                            if (success && mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pengumuman bertanda tangan Ed25519 berhasil disiarkan!'),
                                  backgroundColor: Color(0xFF059669),
                                ),
                              );
                            }
                          },
                    child: annState.isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Kirim Pengumuman', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelRadio extends StatelessWidget {
  final String title;
  final AnnouncementLevel level;
  final AnnouncementLevel selectedLevel;
  final ValueChanged<AnnouncementLevel> onSelected;

  const _LevelRadio({
    required this.title,
    required this.level,
    required this.selectedLevel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = level == selectedLevel;
    Color color;

    switch (level) {
      case AnnouncementLevel.darurat:
        color = const Color(0xFFDC2626);
        break;
      case AnnouncementLevel.penting:
        color = const Color(0xFFD97706);
        break;
      case AnnouncementLevel.info:
        color = const Color(0xFF2563EB);
        break;
    }

    return InkWell(
      onTap: () => onSelected(level),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? color : const Color(0xFFCBD5E1), width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
