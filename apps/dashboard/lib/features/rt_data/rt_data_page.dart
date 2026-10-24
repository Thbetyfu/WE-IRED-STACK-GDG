import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../app/auth_provider.dart';
import 'rt_data_provider.dart';

class RtDataPage extends ConsumerStatefulWidget {
  const RtDataPage({super.key});

  @override
  ConsumerState<RtDataPage> createState() => _RtDataPageState();
}

class _RtDataPageState extends ConsumerState<RtDataPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _householdSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final rtState = ref.watch(rtDataProvider);
    final rtNotifier = ref.read(rtDataProvider.notifier);
    final currentRtId = authState.selectedRT?.id ?? 'rt-01';

    ref.listen<RtDataState>(rtDataProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFFE11D48),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (next.successMessage != null && next.successMessage != prev?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(next.successMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Top Bar
            _buildHeader(authState, rtState, rtNotifier, currentRtId),
            const SizedBox(height: 16),

            // Tab Navigation
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: const Color(0xFF0D9488),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF0D9488),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  Tab(text: 'Rumah Tangga (${rtState.households.length})'),
                  Tab(text: 'Impor CSV & Validasi'),
                  Tab(text: 'Blok & Relawan (${rtState.volunteers.length})'),
                  Tab(text: 'Titik Kumpul (${rtState.assemblyPoints.length})'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: rtState.isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF0D9488)),
                          SizedBox(height: 12),
                          Text('Memuat data master RT...', style: TextStyle(color: Color(0xFF64748B))),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildHouseholdsTab(rtState, rtNotifier, currentRtId),
                        _buildCsvImportTab(rtState, rtNotifier, currentRtId),
                        _buildBlocksAndVolunteersTab(rtState, rtNotifier, currentRtId),
                        _buildAssemblyPointsTab(rtState, rtNotifier, currentRtId),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AuthState auth, RtDataState state, RtDataNotifier notifier, String rtId) {
    return OperationalPageHeader(
      title: 'Manajemen Data RT: ${auth.selectedRT?.name ?? "RT 05"}',
      subtitle: 'Data rumah tangga, perlindungan data rentan, alur kode undangan, blok, relawan, dan titik kumpul (F-01 s.d. F-03).',
      actions: [
        OutlinedButton.icon(
          onPressed: () => notifier.loadAllData(rtId),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Muat Ulang'),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF334155)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D9488),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.add_home_outlined, size: 18),
          label: const Text('Tambah Rumah Tangga'),
          onPressed: () => _showAddHouseholdDialog(context, notifier, rtId),
        ),
      ],
    );
  }

  // TAB 1: Rumah Tangga & Anggota
  Widget _buildHouseholdsTab(RtDataState state, RtDataNotifier notifier, String rtId) {
    if (state.households.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text('Belum ada data rumah tangga terdaftar pada RT ini.',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddHouseholdDialog(context, notifier, rtId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Rumah Pertama'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    final filteredHouseholds = state.households.where((hh) {
      if (_householdSearch.trim().isEmpty) return true;
      final q = _householdSearch.toLowerCase().trim();
      return hh.number.toLowerCase().contains(q) ||
          hh.headName.toLowerCase().contains(q) ||
          hh.address.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 240,
              height: 36,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari no. rumah / nama KK...',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  isDense: true,
                ),
                onChanged: (val) => setState(() => _householdSearch = val),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Menampilkan ${filteredHouseholds.length} dari ${state.households.length} Rumah Tangga',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: filteredHouseholds.isEmpty
                ? const Center(
                    child: Text('Tidak ada rumah tangga yang cocok dengan pencarian.', style: TextStyle(color: Color(0xFF64748B))),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredHouseholds.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final hh = filteredHouseholds[index];
                      final inviteCode = hh.inviteCode ?? 'BELUM_ADA';

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 680),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDFA),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF99F6E4)),
                                  ),
                                  child: Center(
                                    child: Text(
                                      hh.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488), fontSize: 13),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 200,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(hh.headName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 2),
                                      Text(hh.address, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      if (hh.lat != null && hh.lon != null)
                                        Text(
                                          'Lokasi: ${hh.lat!.toStringAsFixed(4)}, ${hh.lon!.toStringAsFixed(4)}',
                                          style: const TextStyle(fontSize: 10, color: Color(0xFF0D9488)),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 150,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(hh.waPhone, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        hh.hasDevice ? 'Memiliki Ponsel' : 'Tanpa Ponsel (Butuh Relawan)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: hh.hasDevice ? const Color(0xFF15803D) : const Color(0xFFD97706),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Container(
                                  width: 130,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Kode Undangan:', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                      Text(inviteCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                OutlinedButton.icon(
                                  onPressed: () => notifier.regenerateInvite(hh.id),
                                  icon: const Icon(Icons.send_outlined, size: 14),
                                  label: const Text('Kirim Kode', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF0D9488),
                                    side: const BorderSide(color: Color(0xFF99F6E4)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // TAB 2: Impor CSV & Laporan Galat Per Baris
  Widget _buildCsvImportTab(RtDataState state, RtDataNotifier notifier, String rtId) {
    final csvController = TextEditingController(
      text: 'nomor,nama_kk,alamat,telepon,blok\n'
          'B-01,Suprapto,Jl. Kenanga No 10,081234567891,Blok B\n'
          'B-02,Hartono,Jl. Kenanga No 12,081234567892,Blok B\n'
          ',Salah Baris,Jl. Kosong,081234567893,Blok B\n',
    );

    final result = state.lastImportResult;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: CSV Editor & Uploader
        Expanded(
          flex: 5,
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Impor Data Massal Format CSV (FR-HH-05)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text(
                    'Format: nomor,nama_kk,alamat,telepon,blok. Validasi per baris akan diperiksa oleh server.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.file_copy_outlined, size: 14),
                        label: const Text('Template Standar (Valid)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          csvController.text = 'nomor,nama_kk,alamat,telepon,blok\n'
                              'B-01,Suprapto,Jl. Kenanga No 10,081234567891,Blok B\n'
                              'B-02,Hartono,Jl. Kenanga No 12,081234567892,Blok B\n'
                              'B-03,Kusuma,Jl. Kenanga No 14,081234567893,Blok B\n';
                        },
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.bug_report_outlined, size: 14),
                        label: const Text('Contoh Uji Galat', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          csvController.text = 'nomor,nama_kk,alamat,telepon,blok\n'
                              'B-01,Suprapto,Jl. Kenanga No 10,081234567891,Blok B\n'
                              'B-02,Hartono,Jl. Kenanga No 12,081234567892,Blok B\n'
                              ',Salah Baris,Jl. Kosong,081234567893,Blok B\n';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: csvController,
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                        ),
                        icon: state.isSubmitting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.file_upload, size: 18),
                        label: const Text('Validasi & Impor Data'),
                        onPressed: state.isSubmitting
                            ? null
                            : () => notifier.importCSV(rtId, csvController.text),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),

        // Right: Validation Error Report
        Expanded(
          flex: 4,
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Laporan Validasi & Galat Per Baris',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  if (result == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Belum ada hasil impor. Klik "Validasi & Impor Data" untuk memproses data CSV.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        _buildStatChip('Total Baris', '${result.totalRows}', const Color(0xFF334155)),
                        const SizedBox(width: 8),
                        _buildStatChip('Berhasil', '${result.importedCount}', const Color(0xFF15803D)),
                        const SizedBox(width: 8),
                        _buildStatChip('Gagal', '${result.failedCount}', const Color(0xFFE11D48)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Daftar Kesalahan Baris (Dapat Ditindaklanjuti):',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    if (result.errors.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                            SizedBox(width: 8),
                            Text('Semua baris valid dan berhasil diimpor!',
                                style: TextStyle(color: Color(0xFF166534), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: result.errors.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, idx) {
                            final err = result.errors[idx];
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFECACA)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Baris ${err.row}',
                                        style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Kolom: ${err.field}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                                        Text(err.message,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF7F1D1D))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 11, color: color)),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  // TAB 3: Blok & Relawan
  Widget _buildBlocksAndVolunteersTab(RtDataState state, RtDataNotifier notifier, String rtId) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Blocks
        Expanded(
          flex: 3,
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daftar Blok Wilayah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.blocks.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final b = state.blocks[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.grid_view, color: Color(0xFF0D9488), size: 20),
                          title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('ID: ${b.id}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Right: Volunteers
        Expanded(
          flex: 6,
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daftar Relawan & Ketersediaan (FR-VOL)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.volunteers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final v = state.volunteers[idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: const Color(0xFFF1F5F9),
                                child: Text(v.name.isNotEmpty ? v.name[0] : 'R',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    Text('Kontak: ${v.phone}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      children: v.skills.map((s) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0FDFA),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFF99F6E4)),
                                          ),
                                          child: Text(s, style: const TextStyle(fontSize: 10, color: Color(0xFF0D9488))),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Text(v.available ? 'Siap Operasi' : 'Tidak Tersedia',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: v.available ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                          )),
                                      const SizedBox(width: 8),
                                      Switch(
                                        value: v.available,
                                        activeThumbColor: const Color(0xFF0D9488),
                                        onChanged: (_) => notifier.toggleVolunteerAvailability(rtId, v.userId, v.available),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // TAB 4: Titik Kumpul Evakuasi
  Widget _buildAssemblyPointsTab(RtDataState state, RtDataNotifier notifier, String rtId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Titik Kumpul Evakuasi Resmi RT (FR-AP)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              icon: const Icon(Icons.add_location_alt_outlined, size: 16),
              label: const Text('Tambah Titik Kumpul'),
              onPressed: () => _showAddAssemblyPointDialog(context, notifier, rtId),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.2,
            ),
            itemCount: state.assemblyPoints.length,
            itemBuilder: (context, idx) {
              final ap = state.assemblyPoints[idx];
              return Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place, color: Color(0xFFE11D48), size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(ap.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Kapasitas: ${ap.capacity} jiwa',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Koordinat: ${ap.lat.toStringAsFixed(5)}, ${ap.lon.toStringAsFixed(5)}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      const Spacer(),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (ap.facilities['toilet'] == true) _buildFacilityTag('Toilet'),
                          if (ap.facilities['listrik'] == true) _buildFacilityTag('Listrik'),
                          if (ap.facilities['air'] == true) _buildFacilityTag('Air Bersih'),
                          if (ap.facilities['wheelchair'] == true) _buildFacilityTag('Akses Disabilitas'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFacilityTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF334155))),
    );
  }

  void _showAddHouseholdDialog(BuildContext context, RtDataNotifier notifier, String rtId) {
    final numberCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final headCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '628');
    double selectedLat = -6.2088;
    double selectedLon = 106.8456;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Tambah Rumah Tangga Baru', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: numberCtrl,
                          decoration: const InputDecoration(labelText: 'Nomor Rumah (misal: A-05)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: headCtrl,
                          decoration: const InputDecoration(labelText: 'Nama Kepala Keluarga', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(labelText: 'Alamat Lengkap', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Nomor WhatsApp Aktif', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  const Text('Pilih Lokasi Rumah pada Peta Bersama (Widget T-03):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: SharedLocationPickerMap(
                      initialLat: selectedLat,
                      initialLon: selectedLon,
                      label: 'Klik peta untuk menentukan titik koordinat rumah',
                      onLocationSelected: (lat, lon) {
                        setState(() {
                          selectedLat = lat;
                          selectedLon = lon;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              onPressed: () async {
                if (numberCtrl.text.trim().isEmpty || headCtrl.text.trim().isEmpty) return;
                await notifier.createHousehold(rtId, {
                  'number': numberCtrl.text.trim(),
                  'head_name': headCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'wa_phone': phoneCtrl.text.trim(),
                  'lat': selectedLat,
                  'lon': selectedLon,
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan Rumah'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAssemblyPointDialog(BuildContext context, RtDataNotifier notifier, String rtId) {
    final nameCtrl = TextEditingController();
    final capCtrl = TextEditingController(text: '100');
    double selectedLat = -6.2080;
    double selectedLon = 106.8455;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Tambah Titik Kumpul Evakuasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Fasilitas (misal: Balai RW / Lapangan)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kapasitas (jiwa)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  const Text('Tentukan Posisi Titik Kumpul pada Peta Bersama (Widget T-03):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 220,
                    child: SharedLocationPickerMap(
                      initialLat: selectedLat,
                      initialLon: selectedLon,
                      label: 'Klik peta untuk menentukan lokasi titik kumpul evakuasi',
                      onLocationSelected: (lat, lon) {
                        setState(() {
                          selectedLat = lat;
                          selectedLon = lon;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await notifier.createAssemblyPoint(rtId, {
                  'name': nameCtrl.text.trim(),
                  'capacity': int.tryParse(capCtrl.text.trim()) ?? 100,
                  'lat': selectedLat,
                  'lon': selectedLon,
                  'facilities': {'toilet': true, 'listrik': true, 'air': true},
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Simpan Titik Kumpul'),
            ),
          ],
        ),
      ),
    );
  }
}
