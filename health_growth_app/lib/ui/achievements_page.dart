import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.accent,
            title: const Text(
              '🏆 Conquistas',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: StreamBuilder(
              stream: service.getUserStats(),
              builder: (context, snapshot) {
                // Proteção contra dados nulos
                final data = snapshot.hasData && snapshot.data!.exists
                    ? snapshot.data!.data() ?? <String, dynamic>{}
                    : <String, dynamic>{};
                final totalPoints = (data['totalPoints'] as num?)?.toInt() ?? 0;
                final level = (data['level'] as num?)?.toInt() ?? 0;
                final note10 = (data['note10count'] as num?)?.toInt() ?? 0;

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LevelBanner(totalPoints: totalPoints, level: level),
                      const SizedBox(height: 16),
                      _Note10Card(note10count: note10),
                      const SizedBox(height: 24),
                      Text(
                        'Badges',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      _BadgeGrid(totalPoints: totalPoints),
                      const SizedBox(height: 24),
                      Text(
                        'Marcos de conquistas',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      ..._milestones.map(
                        (m) => _MilestoneTile(
                          milestone: m,
                          earned: totalPoints >= m.requiredPoints,
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LEVEL BANNER
// ─────────────────────────────────────────────

class _LevelBanner extends StatelessWidget {
  const _LevelBanner({required this.totalPoints, required this.level});

  final int totalPoints;
  final int level;

  static const _levelThresholds = [500, 1500, 2500, 3500, 4500, 5000];

  int get _currentLevel {
    for (int i = 0; i < _levelThresholds.length; i++) {
      if (totalPoints < _levelThresholds[i]) return i + 1;
    }
    return 6;
  }

  double get _levelProgress {
    final lv = _currentLevel;
    if (lv == 1) return totalPoints / _levelThresholds[0];
    if (lv > _levelThresholds.length) return 1.0;
    final prev = _levelThresholds[lv - 2];
    final next = _levelThresholds[lv - 1];
    return ((totalPoints - prev) / (next - prev)).clamp(0.0, 1.0);
  }

  String get _levelEmoji {
    const emojis = ['�', '🎬', '🎁', '🎯', '🎮', '⭐'];
    final lv = _currentLevel;
    return lv <= emojis.length ? emojis[lv - 1] : '⭐';
  }

  @override
  Widget build(BuildContext context) {
    final lv = _currentLevel;
    final progress = _levelProgress;
    final nextThreshold = lv <= _levelThresholds.length
        ? _levelThresholds[lv - 1]
        : _levelThresholds.last;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(_levelEmoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nível $lv',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'R\$$totalPoints / R\$$nextThreshold',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Faltam R\$${nextThreshold - totalPoints} para o próximo nível',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BADGE GRID
// ─────────────────────────────────────────────

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.totalPoints});

  final int totalPoints;

  static const _badges = [
    _Badge(emoji: '🌱', label: 'Iniciante', requiredPoints: 1),
    _Badge(emoji: '🔥', label: 'Em chamas', requiredPoints: 100),
    _Badge(emoji: '📚', label: 'Estudioso', requiredPoints: 500),
    _Badge(emoji: '💪', label: 'Saudável', requiredPoints: 1000),
    _Badge(emoji: '🏠', label: 'Organizado', requiredPoints: 1500),
    _Badge(emoji: '🎯', label: 'Focado', requiredPoints: 2500),
    _Badge(emoji: '🚀', label: 'Imparável', requiredPoints: 3500),
    _Badge(emoji: '🎮', label: 'Game Master', requiredPoints: 4500),
    _Badge(emoji: '⭐', label: 'Lendário', requiredPoints: 5000),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: _badges.map((b) {
        final unlocked = totalPoints >= b.requiredPoints;
        return _BadgeTile(badge: b, unlocked: unlocked);
      }).toList(),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.unlocked});

  final _Badge badge;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedOpacity(
              opacity: unlocked ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 400),
              child: Text(
                unlocked ? badge.emoji : '🔒',
                style: const TextStyle(fontSize: 32),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: unlocked ? null : Colors.grey,
              ),
            ),
            if (!unlocked)
              Text(
                'R\$${badge.requiredPoints}',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge {
  const _Badge({
    required this.emoji,
    required this.label,
    required this.requiredPoints,
  });

  final String emoji;
  final String label;
  final int requiredPoints;
}

// ─────────────────────────────────────────────
// MILESTONE
// ─────────────────────────────────────────────

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.milestone, required this.earned});

  final _Milestone milestone;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: earned
                  ? AppColors.success.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                earned ? milestone.emoji : '🔒',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          title: Text(
            milestone.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: earned ? null : Colors.grey,
            ),
          ),
          subtitle: Text(
            milestone.desc,
            style: TextStyle(color: earned ? null : Colors.grey),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (earned ? AppColors.success : Colors.grey).withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'R\$${milestone.requiredPoints}',
              style: TextStyle(
                color: earned ? AppColors.success : Colors.grey,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Milestone {
  const _Milestone({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.requiredPoints,
  });

  final String emoji;
  final String title;
  final String desc;
  final int requiredPoints;
}

const _milestones = [
  _Milestone(
    emoji: '🌱',
    title: 'Início oficial',
    desc: 'Primeiros passos no Health Growth',
    requiredPoints: 500,
  ),
  _Milestone(
    emoji: '📚',
    title: 'Rotina estabelecida',
    desc: 'Estudando e evoluindo',
    requiredPoints: 1500,
  ),
  _Milestone(
    emoji: '🎁',
    title: 'Metade do caminho',
    desc: 'Já chegou na metade da meta!',
    requiredPoints: 2500,
  ),
  _Milestone(
    emoji: '🎯',
    title: 'Objetivo palpável',
    desc: 'Switch está cada vez mais perto',
    requiredPoints: 3500,
  ),
  _Milestone(
    emoji: '🎮',
    title: 'Switch garantido!',
    desc: 'Meta quase cumprida, herói!',
    requiredPoints: 4500,
  ),
  _Milestone(
    emoji: '⭐',
    title: 'GAME VENCIDO',
    desc: 'Você completou o Health Growth!',
    requiredPoints: 5000,
  ),
];

// ─────────────────────────────────────────────
// NOTE 10 COUNTER (Chefão das Notas)
// ─────────────────────────────────────────────

class _Note10Card extends StatelessWidget {
  const _Note10Card({required this.note10count});

  final int note10count;

  static const _target = 5;
  static const _reward = 150;

  @override
  Widget build(BuildContext context) {
    final achieved = note10count >= _target;
    final progress = (note10count / _target).clamp(0.0, 1.0);

    return Card(
      color: achieved ? AppColors.accent.withValues(alpha: 0.12) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  achieved ? '⭐' : '📝',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chefão das Notas',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '$_target notas 10 → +R\$$_reward',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: achieved
                        ? AppColors.accent
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$note10count / $_target',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: achieved ? Colors.white : AppColors.primary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(
                  achieved ? AppColors.accent : AppColors.primary,
                ),
              ),
            ),
            if (achieved) ...[
              const SizedBox(height: 8),
              Text(
                '🎉 Meta atingida! Fale com o pai para receber R\$$_reward!',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
