import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class WeekProgressPage extends StatefulWidget {
  const WeekProgressPage({super.key});

  @override
  State<WeekProgressPage> createState() => _WeekProgressPageState();
}

class _WeekProgressPageState extends State<WeekProgressPage> {
  final service = FirestoreService();

  // Semana atual: segunda a domingo
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _currentWeekStart();
  }

  DateTime _currentWeekStart() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    // Semana começa na segunda (weekday == 1)
    return d.subtract(Duration(days: d.weekday - 1));
  }

  String _weekKey(DateTime weekStart) {
    final weekOfYear = int.parse(DateFormat('w').format(weekStart));
    return '${weekStart.year}-$weekOfYear';
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  bool get _isCurrentWeek => _isSameDay(_weekStart, _currentWeekStart());

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _previousWeek() =>
      setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));

  void _nextWeek() {
    if (_isCurrentWeek) return;
    setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
  }

  @override
  Widget build(BuildContext context) {
    final weekKey = _weekKey(_weekStart);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildWeekNav(context)),
          SliverToBoxAdapter(child: _buildGoalCard(context, weekKey)),
          SliverToBoxAdapter(child: _buildWeekChart(context)),
          SliverToBoxAdapter(child: _buildSummaryGrid(context)),
          SliverToBoxAdapter(child: _buildReflection(context, weekKey)),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.secondary,
      title: const Text(
        '📊 Andamento da Semana',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildWeekNav(BuildContext context) {
    final startFmt = DateFormat('dd/MM').format(_weekStart);
    final endFmt = DateFormat('dd/MM/yyyy').format(_weekDays.last);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: _previousWeek,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              '$startFmt – $endFmt',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.filledTonal(
            onPressed: _isCurrentWeek ? null : _nextWeek,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, String weekKey) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: service.getWeeklyGoal(weekKey),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      color: Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Nenhuma meta semanal definida pelo admin.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!.data()!;
        final goal = data['goal']?.toString() ?? 'Meta';
        final percentByDay =
            (data['percentByDay'] as Map<String, dynamic>?) ?? {};
        final days = percentByDay.keys.toList()..sort();
        final avg = days.isEmpty
            ? 0.0
            : percentByDay.values.fold<num>(0, (a, b) => a + (b as num)) /
                  days.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.flag,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Meta da semana',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    goal,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _ProgressRing(value: avg / 100, size: 64),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${avg.toStringAsFixed(0)}% atingido',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: (avg / 100).clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.15,
                                ),
                                valueColor: const AlwaysStoppedAnimation(
                                  AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Percentual por dia
                            ...days.map((d) {
                              final pct =
                                  (percentByDay[d] as num?)?.toDouble() ?? 0;
                              final label = DateFormat(
                                'EEE dd/MM',
                                'pt_BR',
                              ).format(DateTime.parse(d));
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.grey),
                                      ),
                                    ),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: (pct / 100).clamp(0.0, 1.0),
                                          minHeight: 6,
                                          backgroundColor: Colors.grey
                                              .withValues(alpha: 0.15),
                                          valueColor: AlwaysStoppedAnimation(
                                            _goalColor(pct),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${pct.toStringAsFixed(0)}%',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: _goalColor(pct),
                                          ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _goalColor(double pct) {
    if (pct >= 80) return AppColors.success;
    if (pct >= 50) return AppColors.accent;
    return AppColors.danger;
  }

  /// Gráfico de barras por dia (tarefas concluídas em cada dia da semana)
  Widget _buildWeekChart(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '📅 Missões por dia',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              _WeekBarChart(weekDays: _weekDays, service: service),
            ],
          ),
        ),
      ),
    );
  }

  /// Cards de resumo: concluídas vs aprovadas vs pagas
  Widget _buildReflection(BuildContext context, String weekKey) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: _WeekReflectionCard(weekKey: weekKey, service: service),
    );
  }

  Widget _buildSummaryGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📈 Resumo da semana',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _WeekSummaryCards(weekDays: _weekDays, service: service),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// WEEK BAR CHART
// ─────────────────────────────────────────────

class _WeekBarChart extends StatelessWidget {
  const _WeekBarChart({required this.weekDays, required this.service});

  final List<DateTime> weekDays;
  final FirestoreService service;

  static const _dayLabels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    return FutureBuilder<List<_DayStat>>(
      future: _fetchWeekStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? List.filled(7, const _DayStat(0, 0));
        final maxDone = stats.fold(0, (m, s) => s.done > m ? s.done : m);
        final chartMax = maxDone < 1 ? 1 : maxDone;

        return SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final day = weekDays[i];
              final stat = stats[i];
              final isFuture = day.isAfter(today);
              final isToday =
                  day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;
              final barHeight = isFuture
                  ? 0.0
                  : (stat.total == 0 ? 0.0 : (stat.done / chartMax) * 110);

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (stat.done > 0)
                    Text(
                      '${stat.done}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isToday ? AppColors.primary : AppColors.success,
                      ),
                    ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    width: 30,
                    height: barHeight.clamp(4.0, 110.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: isFuture
                            ? [
                                Colors.grey.withValues(alpha: 0.2),
                                Colors.grey.withValues(alpha: 0.1),
                              ]
                            : isToday
                            ? [AppColors.primary, AppColors.primaryDark]
                            : [
                                AppColors.success,
                                AppColors.success.withValues(alpha: 0.7),
                              ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _dayLabels[i],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.normal,
                      color: isToday ? AppColors.primary : null,
                    ),
                  ),
                ],
              );
            }),
          ),
        );
      },
    );
  }

  Future<List<_DayStat>> _fetchWeekStats() async {
    final results = <_DayStat>[];
    for (final day in weekDays) {
      final key = DateFormat('yyyy-MM-dd').format(day);
      try {
        final doc = await FirebaseFirestore.instance
            .collection('progress')
            .doc(key)
            .get();
        if (!doc.exists) {
          results.add(const _DayStat(0, 0));
          continue;
        }
        final data = doc.data() ?? {};
        int done = 0;
        int total = 0;
        for (final v in data.values) {
          if (v is Map) {
            total++;
            if (v['value'] == true) done++;
          }
        }
        results.add(_DayStat(done, total));
      } catch (_) {
        results.add(const _DayStat(0, 0));
      }
    }
    return results;
  }
}

class _DayStat {
  const _DayStat(this.done, this.total);

  final int done;
  final int total;
}

// ─────────────────────────────────────────────
// WEEK SUMMARY CARDS
// ─────────────────────────────────────────────

class _WeekSummaryCards extends StatelessWidget {
  const _WeekSummaryCards({required this.weekDays, required this.service});

  final List<DateTime> weekDays;
  final FirestoreService service;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WeekSummary>(
      future: _fetchSummary(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final s = snapshot.data!;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: '✅',
                    label: 'Concluídas',
                    value: '${s.done}/${s.total}',
                    color: AppColors.success,
                    subtitle: s.total == 0
                        ? '—'
                        : '${(s.done / s.total * 100).toStringAsFixed(0)}%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    icon: '👍',
                    label: 'Aprovadas',
                    value: '${s.approved}',
                    color: AppColors.secondary,
                    subtitle: s.done == 0
                        ? '—'
                        : '${(s.approved / s.done * 100).toStringAsFixed(0)}% das concluídas',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: '💰',
                    label: 'Pagas',
                    value: '${s.paid}',
                    color: AppColors.accent,
                    subtitle: s.approved == 0
                        ? '—'
                        : '${(s.paid / s.approved * 100).toStringAsFixed(0)}% das aprovadas',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    icon: '💎',
                    label: 'Valor ganho',
                    value: 'R\$${s.earnedPoints}',
                    color: AppColors.primary,
                    subtitle: 'nesta semana',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Mini gráfico pizza de aprovadas/concluídas/pagas
            _StatusPieChart(done: s.done, approved: s.approved, paid: s.paid),
          ],
        );
      },
    );
  }

  Future<_WeekSummary> _fetchSummary() async {
    int done = 0;
    int total = 0;
    int approved = 0;
    int paid = 0;
    int earnedPoints = 0;

    for (final day in weekDays) {
      final key = DateFormat('yyyy-MM-dd').format(day);
      try {
        final doc = await FirebaseFirestore.instance
            .collection('progress')
            .doc(key)
            .get();
        if (!doc.exists) continue;
        final data = doc.data() ?? {};
        for (final v in data.values) {
          if (v is Map) {
            total++;
            if (v['value'] == true) {
              done++;
              earnedPoints += (v['points'] as num?)?.toInt() ?? 0;
            }
            final status = v['status']?.toString() ?? '';
            if (status == 'approved') approved++;
            if (v['paid'] == true) paid++;
          }
        }
      } catch (_) {}
    }

    return _WeekSummary(
      done: done,
      total: total,
      approved: approved,
      paid: paid,
      earnedPoints: earnedPoints,
    );
  }
}

class _WeekSummary {
  const _WeekSummary({
    required this.done,
    required this.total,
    required this.approved,
    required this.paid,
    required this.earnedPoints,
  });

  final int done;
  final int total;
  final int approved;
  final int paid;
  final int earnedPoints;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.subtitle,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MINI GRÁFICO DE STATUS (Pie-like com barras)
// ─────────────────────────────────────────────

class _StatusPieChart extends StatelessWidget {
  const _StatusPieChart({
    required this.done,
    required this.approved,
    required this.paid,
  });

  final int done;
  final int approved;
  final int paid;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Funil de aprovação',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _FunnelBar(
              label: 'Concluídas',
              value: done,
              max: done,
              color: AppColors.success,
            ),
            const SizedBox(height: 8),
            _FunnelBar(
              label: 'Aprovadas',
              value: approved,
              max: done,
              color: AppColors.secondary,
            ),
            const SizedBox(height: 8),
            _FunnelBar(
              label: 'Pagas',
              value: paid,
              max: done,
              color: AppColors.accent,
            ),
          ],
        ),
      ),
    );
  }
}

class _FunnelBar extends StatelessWidget {
  const _FunnelBar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 14,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$value',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// PROGRESS RING
// ─────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value, this.size = 64});

  final double value;
  final double size;

  Color get _ringColor {
    if (value >= 0.8) return AppColors.success;
    if (value >= 0.5) return AppColors.accent;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value: value, color: _ringColor),
        child: Center(
          child: Text(
            '${(value * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _ringColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width / 2) - 5;
    const stroke = 6.0;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -pi / 2,
      2 * pi * value.clamp(0.0, 1.0),
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

// ─────────────────────────────────────────────
// REFLEXÃO SEMANAL (3 perguntas do PDF)
// ─────────────────────────────────────────────

class _WeekReflectionCard extends StatefulWidget {
  const _WeekReflectionCard({required this.weekKey, required this.service});

  final String weekKey;
  final FirestoreService service;

  @override
  State<_WeekReflectionCard> createState() => _WeekReflectionCardState();
}

class _WeekReflectionCardState extends State<_WeekReflectionCard> {
  final _pillarUpCtrl = TextEditingController();
  final _obstacleCtrl = TextEditingController();
  final _simplifyCtrl = TextEditingController();
  bool _editing = false;
  bool _saving = false;

  @override
  void dispose() {
    _pillarUpCtrl.dispose();
    _obstacleCtrl.dispose();
    _simplifyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(BuildContext context) async {
    setState(() => _saving = true);
    try {
      await widget.service.saveWeeklyReflection(
        weekKey: widget.weekKey,
        pillarUp: _pillarUpCtrl.text.trim(),
        obstacle: _obstacleCtrl.text.trim(),
        simplify: _simplifyCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reflexão salva! ✅'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.service.getWeeklyReflection(widget.weekKey),
      builder: (context, snap) {
        final data = snap.data?.data();
        final hasData = data != null && data.isNotEmpty;

        // Pre-fill controllers when data arrives (only if not editing)
        if (hasData && !_editing) {
          _pillarUpCtrl.text = data['pillarUp']?.toString() ?? '';
          _obstacleCtrl.text = data['obstacle']?.toString() ?? '';
          _simplifyCtrl.text = data['simplify']?.toString() ?? '';
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🧠', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reflexão da semana',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (!_editing)
                      TextButton.icon(
                        onPressed: () => setState(() => _editing = true),
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(hasData ? 'Editar' : 'Responder'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_editing) ...[
                  _ReflectionField(
                    label: '🏆 Qual pilar foi seu ponto forte esta semana?',
                    controller: _pillarUpCtrl,
                  ),
                  const SizedBox(height: 12),
                  _ReflectionField(
                    label: '⚠️ Qual foi o maior obstáculo?',
                    controller: _obstacleCtrl,
                  ),
                  const SizedBox(height: 12),
                  _ReflectionField(
                    label: '💡 O que pode simplificar sua rotina?',
                    controller: _simplifyCtrl,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => setState(() => _editing = false),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saving ? null : () => _save(context),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Salvar'),
                      ),
                    ],
                  ),
                ] else if (hasData) ...[
                  _ReflectionReadRow(
                    icon: '🏆',
                    question: 'Ponto forte',
                    answer: data['pillarUp']?.toString() ?? '',
                  ),
                  const SizedBox(height: 8),
                  _ReflectionReadRow(
                    icon: '⚠️',
                    question: 'Maior obstáculo',
                    answer: data['obstacle']?.toString() ?? '',
                  ),
                  const SizedBox(height: 8),
                  _ReflectionReadRow(
                    icon: '💡',
                    question: 'Simplificação',
                    answer: data['simplify']?.toString() ?? '',
                  ),
                ] else
                  Text(
                    'Ainda não respondida esta semana.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReflectionField extends StatelessWidget {
  const _ReflectionField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}

class _ReflectionReadRow extends StatelessWidget {
  const _ReflectionReadRow({
    required this.icon,
    required this.question,
    required this.answer,
  });

  final String icon;
  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.grey),
              ),
              Text(
                answer.isEmpty ? '—' : answer,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
