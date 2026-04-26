import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';

class WeeklyGoalPage extends StatefulWidget {
  const WeeklyGoalPage({super.key});

  @override
  State<WeeklyGoalPage> createState() => _WeeklyGoalPageState();
}

class _WeeklyGoalPageState extends State<WeeklyGoalPage> {
  final service = AdminService();

  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _currentWeekStart();
  }

  DateTime _currentWeekStart() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  String _weekKey(DateTime weekStart) {
    final weekStr = DateFormat('w').format(weekStart);
    final weekOfYear = int.tryParse(weekStr) ?? 1;
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
    final startFmt = DateFormat('dd/MM').format(_weekStart);
    final endFmt = DateFormat('dd/MM/yyyy').format(_weekDays.last);

    return Scaffold(
      appBar: AppBar(title: const Text('Meta semanal')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: service.getWeeklyGoal(weekKey),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorMessage(error: snapshot.error);
          }
          // Proteção: permitir visualização mesmo sem dados
          final data = snapshot.hasData && snapshot.data!.exists
              ? snapshot.data!.data() ?? <String, dynamic>{}
              : <String, dynamic>{};
          final goal = data['goal']?.toString() ?? '';
          final percentByDayRaw = data['percentByDay'];
          final percentByDay = percentByDayRaw is Map<String, dynamic>
              ? percentByDayRaw
              : <String, dynamic>{};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Week navigation
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _previousWeek,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      '$startFmt – $endFmt',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _isCurrentWeek ? null : _nextWeek,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Goal text card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Texto da meta',
                        style: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              goal.isEmpty ? 'Nenhuma meta definida' : goal,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: goal.isEmpty ? Colors.grey : null,
                                  ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Editar meta',
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _showGoalDialog(context, weekKey, goal),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Per-day percentages
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Percentual atingido por dia',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      ..._weekDays.map((day) {
                        final dateKey = DateFormat('yyyy-MM-dd').format(day);
                        final pct =
                            (percentByDay[dateKey] as num?)?.toDouble() ?? 0;
                        final label = DateFormat(
                          'EEE dd/MM',
                          'pt_BR',
                        ).format(day);
                        final isFuture = day.isAfter(DateTime.now());

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DayPercentTile(
                            label: label,
                            dateKey: dateKey,
                            weekKey: weekKey,
                            percent: pct,
                            isFuture: isFuture,
                            service: service,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showGoalDialog(
    BuildContext context,
    String weekKey,
    String currentGoal,
  ) async {
    final ctrl = TextEditingController(text: currentGoal);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Meta da semana'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Descrição da meta',
            hintText: 'Ex: Foco total nas provas de história',
          ),
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final text = ctrl.text.trim();
              if (text.isEmpty) return;
              await service.setWeeklyGoalText(weekKey: weekKey, goal: text);
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    ctrl.dispose();
  }
}

// ─────────────────────────────────────────────
// DAY PERCENT TILE
// ─────────────────────────────────────────────

class _DayPercentTile extends StatefulWidget {
  const _DayPercentTile({
    required this.label,
    required this.dateKey,
    required this.weekKey,
    required this.percent,
    required this.isFuture,
    required this.service,
  });

  final String label;
  final String dateKey;
  final String weekKey;
  final double percent;
  final bool isFuture;
  final AdminService service;

  @override
  State<_DayPercentTile> createState() => _DayPercentTileState();
}

class _DayPercentTileState extends State<_DayPercentTile> {
  late double _localPct;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _localPct = widget.percent;
  }

  @override
  void didUpdateWidget(_DayPercentTile old) {
    super.didUpdateWidget(old);
    if (!_editing) _localPct = widget.percent;
  }

  Color _pctColor(double pct) {
    if (pct >= 80) return Colors.green;
    if (pct >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final color = _pctColor(_localPct);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                widget.label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                  ),
                ),
                child: Slider(
                  value: _localPct,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  activeColor: color,
                  inactiveColor: color.withValues(alpha: 0.2),
                  onChanged: widget.isFuture
                      ? null
                      : (v) => setState(() {
                          _editing = true;
                          _localPct = v;
                        }),
                  onChangeEnd: widget.isFuture
                      ? null
                      : (v) async {
                          await widget.service.setWeeklyGoalPercent(
                            weekKey: widget.weekKey,
                            dateKey: widget.dateKey,
                            percent: v,
                          );
                          if (!mounted) return;
                          setState(() => _editing = false);
                        },
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${_localPct.round()}%',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 90, right: 44),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_localPct / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ERROR
// ─────────────────────────────────────────────

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Erro ao carregar dados: $error',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
