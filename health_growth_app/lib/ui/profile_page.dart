import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show themeModeNotifier;
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final service = FirestoreService();
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode') ?? 'system';
    setState(() {
      _darkMode = saved == 'dark';
    });
  }

  Future<void> _toggleTheme(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    final mode = val ? ThemeMode.dark : ThemeMode.light;
    await prefs.setString('themeMode', val ? 'dark' : 'light');
    themeModeNotifier.value = mode;
    setState(() => _darkMode = val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder(
        stream: service.getUserStats(),
        builder: (context, snapshot) {
          // Proteção contra dados nulos
          final data = snapshot.hasData && snapshot.data!.exists
              ? snapshot.data!.data() ?? <String, dynamic>{}
              : <String, dynamic>{};
          final totalPoints = (data['totalPoints'] as num?)?.toInt() ?? 0;
          final level = (data['level'] as num?)?.toInt() ?? 1;

          return CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildAvatar(context, totalPoints),
                      const SizedBox(height: 24),
                      _buildStatsRow(context, totalPoints, level),
                      const SizedBox(height: 24),
                      _buildSettingsCard(context),
                      const SizedBox(height: 24),
                      _buildGameInfoCard(context),
                      const SizedBox(height: 80),
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

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 180,
      backgroundColor: AppColors.primaryDark,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, Color(0xFF2D1B69)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Meu Perfil',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, int points) {
    final emoji = _levelEmoji(points);

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 48)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Heitor',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '🎮 Health Growth Player',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(BuildContext context, int totalPoints, int level) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: '💰',
            label: 'Total ganho',
            value: 'R\$$totalPoints',
            color: AppColors.accent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: '🎮',
            label: 'Nível atual',
            value: 'Nível $level',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: '🎯',
            label: 'Meta',
            value: 'R\$5.000',
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: _darkMode,
            onChanged: _toggleTheme,
            title: const Text(
              'Modo escuro',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Economiza bateria à noite'),
            secondary: const Icon(Icons.dark_mode),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildGameInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🎮 Sobre o Health Growth',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _InfoRow(icon: '📅', text: 'Tarefas diárias por pilar'),
            _InfoRow(icon: '✅', text: 'Admin aprova e paga missões'),
            _InfoRow(icon: '💰', text: 'Meta: R\$5.000 (Nintendo Switch)'),
            _InfoRow(icon: '⭐', text: '6 níveis de evolução'),
            _InfoRow(icon: '🏆', text: 'Badges e conquistas desbloqueáveis'),
          ],
        ),
      ),
    );
  }

  String _levelEmoji(int points) {
    if (points >= 5000) return '⭐';
    if (points >= 4500) return '🎮';
    if (points >= 3500) return '🎯';
    if (points >= 2500) return '🎁';
    if (points >= 1500) return '📚';
    if (points >= 500) return '💪';
    return '🌱';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final String icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
