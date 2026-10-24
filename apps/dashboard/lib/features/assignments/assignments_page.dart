import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ui/ui.dart';

import '../../app/auth_provider.dart';

class TaskItem {
  final String id;
  final String householdNumber;
  final String headName;
  final String address;
  final String block;
  final String urgency;
  final List<String> needs;
  final double priorityScore;
  final String status; // 'suggested', 'in_progress', 'completed'
  final String? assignedVolunteer;
  final DateTime createdAt;
  final bool isOverdue;

  const TaskItem({
    required this.id,
    required this.householdNumber,
    required this.headName,
    required this.address,
    required this.block,
    required this.urgency,
    required this.needs,
    required this.priorityScore,
    required this.status,
    this.assignedVolunteer,
    required this.createdAt,
    this.isOverdue = false,
  });
}

class AssignmentsPage extends ConsumerStatefulWidget {
  const AssignmentsPage({super.key});

  @override
  ConsumerState<AssignmentsPage> createState() => _AssignmentsPageState();
}

class _AssignmentsPageState extends ConsumerState<AssignmentsPage> {
  // Initial task state modeled after greedy assignment algorithm (SDD 6.3)
  late List<TaskItem> _tasks;
  String _selectedBlock = 'all';
  String _selectedUrgency = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tasks = [
      TaskItem(
        id: 'tsk-01',
        householdNumber: '04',
        headName: 'Keluarga Bpk. Santoso',
        address: 'Jl. Merak No. 4, Blok A',
        block: 'Blok A',
        urgency: 'kritis',
        needs: ['Evakuasi Medis', 'Lansia Tirah Baring'],
        priorityScore: 84.5,
        status: 'in_progress',
        assignedVolunteer: 'Budi (Relawan Blok A)',
        createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
        isOverdue: true, // > 5 minutes
      ),
      TaskItem(
        id: 'tsk-02',
        householdNumber: '12',
        headName: 'Keluarga Ibu Ratna',
        address: 'Jl. Merak No. 12, Blok B',
        block: 'Blok B',
        urgency: 'kritis',
        needs: ['Balita Sakit', 'Air Bersih'],
        priorityScore: 78.0,
        status: 'suggested',
        assignedVolunteer: null,
        createdAt: DateTime.now().subtract(const Duration(minutes: 3)),
        isOverdue: false,
      ),
      TaskItem(
        id: 'tsk-03',
        householdNumber: '19',
        headName: 'Keluarga Bpk. Heru',
        address: 'Jl. Kutilang No. 3, Blok C',
        block: 'Blok C',
        urgency: 'biasa',
        needs: ['Makanan / Logistik', 'Terisolir'],
        priorityScore: 52.0,
        status: 'suggested',
        assignedVolunteer: null,
        createdAt: DateTime.now().subtract(const Duration(minutes: 6)),
        isOverdue: true,
      ),
      TaskItem(
        id: 'tsk-04',
        householdNumber: '02',
        headName: 'Keluarga Bpk. Wijaya',
        address: 'Jl. Merak No. 2, Blok A',
        block: 'Blok A',
        urgency: 'biasa',
        needs: ['Evakuasi Titik Kumpul'],
        priorityScore: 45.0,
        status: 'completed',
        assignedVolunteer: 'Ahmad (Relawan Blok A)',
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
        isOverdue: false,
      ),
    ];
  }

  void _assignTask(TaskItem task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tugaskan Relawan: Rumah ${task.householdNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kepala Keluarga: ${task.headName}'),
            Text('Alamat: ${task.address}'),
            const SizedBox(height: 12),
            const Text('Pilih Relawan Terdekat:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              leading: const Icon(Icons.person, color: AppTheme.primaryBlue),
              title: const Text('Budi Santoso (Blok A - Siaga)'),
              subtitle: const Text('Kapasitas aktif: 1 tugas'),
              onTap: () {
                setState(() {
                  final index = _tasks.indexWhere((t) => t.id == task.id);
                  if (index != -1) {
                    _tasks[index] = TaskItem(
                      id: task.id,
                      householdNumber: task.householdNumber,
                      headName: task.headName,
                      address: task.address,
                      block: task.block,
                      urgency: task.urgency,
                      needs: task.needs,
                      priorityScore: task.priorityScore,
                      status: 'in_progress',
                      assignedVolunteer: 'Budi Santoso',
                      createdAt: DateTime.now(),
                      isOverdue: false,
                    );
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tugas Rumah ${task.householdNumber} berhasil ditugaskan ke Budi Santoso.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.person, color: AppTheme.primaryBlue),
              title: const Text('Siti Aminah (Blok B - Siaga)'),
              subtitle: const Text('Kapasitas aktif: 0 tugas'),
              onTap: () {
                setState(() {
                  final index = _tasks.indexWhere((t) => t.id == task.id);
                  if (index != -1) {
                    _tasks[index] = TaskItem(
                      id: task.id,
                      householdNumber: task.householdNumber,
                      headName: task.headName,
                      address: task.address,
                      block: task.block,
                      urgency: task.urgency,
                      needs: task.needs,
                      priorityScore: task.priorityScore,
                      status: 'in_progress',
                      assignedVolunteer: 'Siti Aminah',
                      createdAt: DateTime.now(),
                      isOverdue: false,
                    );
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tugas Rumah ${task.householdNumber} berhasil ditugaskan ke Siti Aminah.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        ],
      ),
    );
  }

  void _markCompleted(TaskItem task) {
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = TaskItem(
          id: task.id,
          householdNumber: task.householdNumber,
          headName: task.headName,
          address: task.address,
          block: task.block,
          urgency: task.urgency,
          needs: task.needs,
          priorityScore: task.priorityScore,
          status: 'completed',
          assignedVolunteer: task.assignedVolunteer,
          createdAt: task.createdAt,
          isOverdue: false,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tugas Rumah ${task.householdNumber} selesai dijangkau.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _approveAllSuggested() {
    setState(() {
      for (int i = 0; i < _tasks.length; i++) {
        if (_tasks[i].status == 'suggested') {
          final t = _tasks[i];
          _tasks[i] = TaskItem(
            id: t.id,
            householdNumber: t.householdNumber,
            headName: t.headName,
            address: t.address,
            block: t.block,
            urgency: t.urgency,
            needs: t.needs,
            priorityScore: t.priorityScore,
            status: 'in_progress',
            assignedVolunteer: 'Budi Santoso',
            createdAt: DateTime.now(),
            isOverdue: false,
          );
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Seluruh rencana tugas yang disarankan sistem telah disetujui dan dialokasikan ke relawan.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTaskDetail(TaskItem task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Detail Penugasan: Rumah ${task.householdNumber}'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kepala Keluarga: ${task.headName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Alamat: ${task.address}'),
              Text('Blok: ${task.block}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Urgensi: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(task.urgency.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: task.urgency == 'kritis' ? AppTheme.statusKritis : AppTheme.slate700,
                      )),
                  const SizedBox(width: 14),
                  const Text('Skor Prioritas: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(task.priorityScore.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Kebutuhan Khusus:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: task.needs.map((n) {
                  return Chip(
                    label: Text(n, style: const TextStyle(fontSize: 11)),
                    backgroundColor: const Color(0xFFFEF3C7),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              if (task.assignedVolunteer != null)
                Text('Relawan Penanggung Jawab: ${task.assignedVolunteer}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue))
              else
                const Text('Relawan: Belum Ditugaskan (Menunggu Persetujuan)',
                    style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.slate500)),
              if (task.isOverdue) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.statusKritisBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.statusKritisBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: AppTheme.statusKritis),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Peringatan Keterlambatan: Tugas belum ditindaklanjuti lebih dari 5 menit.',
                          style: TextStyle(fontSize: 11, color: AppTheme.statusKritis, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          if (task.status == 'suggested')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _assignTask(task);
              },
              child: const Text('Tugaskan Relawan'),
            )
          else if (task.status == 'in_progress')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _markCompleted(task);
              },
              child: const Text('Tandai Selesai'),
            ),
        ],
      ),
    );
  }

  List<TaskItem> _filterTasks(List<TaskItem> list) {
    return list.where((t) {
      if (_selectedBlock != 'all' && t.block != _selectedBlock) return false;
      if (_selectedUrgency != 'all' && t.urgency != _selectedUrgency) return false;
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        return t.householdNumber.toLowerCase().contains(q) ||
            t.headName.toLowerCase().contains(q) ||
            t.address.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final suggested = _filterTasks(_tasks.where((t) => t.status == 'suggested').toList());
    final inProgress = _filterTasks(_tasks.where((t) => t.status == 'in_progress').toList());
    final completed = _filterTasks(_tasks.where((t) => t.status == 'completed').toList());

    final totalSuggested = _tasks.where((t) => t.status == 'suggested').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OperationalPageHeader(
              title: 'Papan Penugasan Relawan: ${authState.selectedRT?.name ?? "RT 05"}',
              subtitle: 'Rencana penugasan otomatis (Greedy U+V+W+N+D), pemantauan relawan, dan peringatan keterlambatan > 5 menit (FR-TSK-01..05).',
              statusBadge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Text(
                  '${_tasks.where((t) => t.status == "suggested").length} Rencana • ${_tasks.where((t) => t.status == "in_progress").length} Berjalan • ${_tasks.where((t) => t.status == "completed").length} Selesai',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.slate700),
                ),
              ),
              actions: [
                if (totalSuggested > 0)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.done_all, size: 16),
                    label: const Text('Setujui Semua Rencana'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF15803D),
                      side: const BorderSide(color: Color(0xFF86EFAC)),
                    ),
                    onPressed: _approveAllSuggested,
                  ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.auto_mode, size: 16),
                  label: const Text('Hitung Ulang Rencana'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Algoritma greedy SDD 6.3 telah memperbarui skor prioritas seluruh tugas.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Filter Toolbar
            Card(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 36,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Cari tugas / KK...',
                          prefixIcon: const Icon(Icons.search, size: 16),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedBlock,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate800),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Semua Blok')),
                            DropdownMenuItem(value: 'Blok A', child: Text('Blok A')),
                            DropdownMenuItem(value: 'Blok B', child: Text('Blok B')),
                            DropdownMenuItem(value: 'Blok C', child: Text('Blok C')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedBlock = val);
                          },
                        ),
                      ),
                    ),
                    DropdownButtonHideUnderline(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedUrgency,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.slate800),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Semua Urgensi')),
                            DropdownMenuItem(value: 'kritis', child: Text('Hanya Kritis')),
                            DropdownMenuItem(value: 'biasa', child: Text('Hanya Biasa')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedUrgency = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3-Column Responsive Kanban Board
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 960;

                  final col1 = _KanbanColumn(
                    title: 'Disarankan Sistem',
                    count: suggested.length,
                    accentColor: const Color(0xFF2563EB),
                    items: suggested,
                    onAction: _assignTask,
                    onTapCard: _showTaskDetail,
                    actionLabel: 'Tugaskan',
                  );

                  final col2 = _KanbanColumn(
                    title: 'Sedang Berjalan',
                    count: inProgress.length,
                    accentColor: const Color(0xFFD97706),
                    items: inProgress,
                    onAction: _markCompleted,
                    onTapCard: _showTaskDetail,
                    actionLabel: 'Selesaikan',
                  );

                  final col3 = _KanbanColumn(
                    title: 'Selesai / Terjangkau',
                    count: completed.length,
                    accentColor: const Color(0xFF16A34A),
                    items: completed,
                    onAction: null,
                    onTapCard: _showTaskDetail,
                  );

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: col1),
                        const SizedBox(width: 16),
                        Expanded(child: col2),
                        const SizedBox(width: 16),
                        Expanded(child: col3),
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 300, child: col1),
                        const SizedBox(width: 16),
                        SizedBox(width: 300, child: col2),
                        const SizedBox(width: 16),
                        SizedBox(width: 300, child: col3),
                      ],
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
}

class _KanbanColumn extends StatelessWidget {
  final String title;
  final int count;
  final Color accentColor;
  final List<TaskItem> items;
  final void Function(TaskItem)? onAction;
  final void Function(TaskItem)? onTapCard;
  final String? actionLabel;

  const _KanbanColumn({
    required this.title,
    required this.count,
    required this.accentColor,
    required this.items,
    this.onAction,
    this.onTapCard,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 11)),
                ),
              ],
            ),
          ),

          // Cards List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 32, color: AppTheme.slate400),
                        const SizedBox(height: 6),
                        const Text('Tidak ada tugas', style: TextStyle(fontSize: 12, color: AppTheme.slate500)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      return _TaskCard(
                        task: item,
                        onAction: onAction != null ? () => onAction!(item) : null,
                        onTap: onTapCard != null ? () => onTapCard!(item) : null,
                        actionLabel: actionLabel,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final String? actionLabel;

  const _TaskCard({
    required this.task,
    this.onAction,
    this.onTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: task.isOverdue ? AppTheme.statusKritis : AppTheme.borderSubtle,
            width: task.isOverdue ? 1.5 : 1.0,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.slate100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'No. ${task.householdNumber} • ${task.block}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.slate700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Priority Score Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: task.priorityScore >= 70
                        ? AppTheme.statusKritisBg
                        : (task.priorityScore >= 40 ? AppTheme.statusButuhBantuanBg : AppTheme.statusAmanBg),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Skor ${task.priorityScore.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: task.priorityScore >= 70
                          ? AppTheme.statusKritis
                          : (task.priorityScore >= 40 ? AppTheme.statusButuhBantuan : AppTheme.statusAman),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Text(
              task.headName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.slate900),
            ),
            Text(
              task.address,
              style: const TextStyle(fontSize: 11, color: AppTheme.slate500),
            ),
            const SizedBox(height: 6),

            // Needs Tags
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: task.needs.map((need) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    need,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                  ),
                );
              }).toList(),
            ),

            // Overdue Warning Banner
            if (task.isOverdue) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.statusKritisBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.statusKritisBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 12, color: AppTheme.statusKritis),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Tugas belum direspons > 5 menit!',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.statusKritis),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (task.assignedVolunteer != null) ...[
              const SizedBox(height: 6),
              Text(
                'Relawan: ${task.assignedVolunteer}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
              ),
            ],

            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onAction,
                  child: Text(actionLabel!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
