import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';

/// Tela de lançamento de penalidades
/// Baseado em: Growth_Saudavel-prototipo revisado.pdf
class PenaltiesPage extends StatefulWidget {
  const PenaltiesPage({super.key});

  @override
  State<PenaltiesPage> createState() => _PenaltiesPageState();
}

class _PenaltiesPageState extends State<PenaltiesPage> {
  final service = AdminService();

  // Penalidades definidas no PDF
  static const _penalties = [
    _PenaltyTemplate(
      category: 'Mentira',
      amount: -10,
      icon: '🤥',
      description: 'Mentiu sobre tarefa feita',
    ),
    _PenaltyTemplate(
      category: 'Quebrar regra combinada',
      amount: -5,
      icon: '⚠️',
      description: 'Quebrou regra combinada',
    ),
    _PenaltyTemplate(
      category: 'Dia zerado sem esforço',
      amount: -2,
      icon: '😴',
      description: 'Dia zerado sem esforço',
    ),
    _PenaltyTemplate(
      category: 'Dois dias sem estudo',
      amount: -10,
      icon: '📚',
      description: '2 dias seguidos sem estudo',
    ),
    _PenaltyTemplate(
      category: 'Nota abaixo da média',
      amount: -10,
      icon: '📝',
      description: 'Nota abaixo da média mínima',
    ),
    _PenaltyTemplate(
      category: 'Tela/sono fora do horário',
      amount: -5,
      icon: '📵',
      description: 'Desobedeceu regra de tela/sono',
    ),
    _PenaltyTemplate(
      category: 'Perdeu 3 treinos',
      amount: -5,
      icon: '⚽',
      description: 'Perdeu 3 ou mais treinos',
    ),
    _PenaltyTemplate(
      category: 'Esqueceu a descarga',
      amount: -2,
      icon: '🚽',
      description: 'Esqueceu a descarga',
    ),
    _PenaltyTemplate(
      category: 'Quarto zoneado',
      amount: -5,
      icon: '🛏️',
      description: 'Quarto completamente bagunçado',
    ),
    _PenaltyTemplate(
      category: 'Material jogado',
      amount: -2,
      icon: '🎒',
      description: 'Deixou material jogado (dobra se for da escola)',
    ),
    _PenaltyTemplate(
      category: 'Tênis/bola/livro/copo no caminho',
      amount: -2,
      icon: '🪣',
      description: 'Objeto no meio do caminho',
    ),
  ];

  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_selectedDate) ?? DateTime.now(),
      firstDate: DateTime(2026),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
    });
  }

  Future<void> _apply(BuildContext context, _PenaltyTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${template.icon} Confirmar penalidade?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.description),
            const SizedBox(height: 8),
            Text(
              'Valor: R\$${template.amount}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text('Data: $_selectedDate'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await service.applyPenaltyEntry(
      date: _selectedDate,
      category: template.category,
      amount: template.amount,
      description: '${template.icon} ${template.description}',
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Penalidade aplicada: ${template.category} (R\$${template.amount})',
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚠️ Penalidades')),
      body: Column(
        children: [
          // Seletor de data
          Card(
            margin: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Data da penalidade'),
              subtitle: Text(_selectedDate),
              trailing: const Icon(Icons.edit),
              onTap: () => _pickDate(context),
            ),
          ),
          // Lista de penalidades
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _penalties.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = _penalties[i];
                return Card(
                  child: ListTile(
                    leading: Text(p.icon, style: const TextStyle(fontSize: 28)),
                    title: Text(
                      p.category,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(p.description),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'R\$${p.amount}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _apply(context, p),
                          child: const Text(
                            'Aplicar',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
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

class _PenaltyTemplate {
  const _PenaltyTemplate({
    required this.category,
    required this.amount,
    required this.icon,
    required this.description,
  });

  final String category;
  final int amount;
  final String icon;
  final String description;
}
