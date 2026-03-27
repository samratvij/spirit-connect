import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/memory_provider.dart';

import '../providers/persona_provider.dart';
import 'persona_memory_screen.dart';

class MemoryScreen extends ConsumerWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personas = ref.watch(personasProvider);
    final memories = ref.watch(memoryProvider).memories;

    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: Text(
          'Memories',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: personas.length,
        itemBuilder: (context, index) {
          final persona = personas[index];
          final personaMemories = memories.where((m) => m.personaId == persona.modelName).toList();

          return Card(
            color: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFF30363D)),
            ),
            margin: const EdgeInsets.only(bottom: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonaMemoryScreen(persona: persona),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E1117),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF30363D)),
                      ),
                      child: Center(
                        child: Text(persona.icon, style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            persona.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${personaMemories.length} memories stored',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF8B949E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF484F58)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _MemoryTile extends StatelessWidget {
  final String content;
  final DateTime date;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _MemoryTile({
    required this.content,
    required this.date,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha:0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.lightbulb_outline,
              size: 18, color: Color(0xFF6366F1)),
        ),
        title: Text(
          content,
          style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.4),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            DateFormat('MMM d, yyyy').format(date.toLocal()),
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF484F58)),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF8B949E)),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF8B949E)),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMemoryDialog extends StatefulWidget {
  final String initial;
  const _EditMemoryDialog({required this.initial});

  @override
  State<_EditMemoryDialog> createState() => _EditMemoryDialogState();
}

class _EditMemoryDialogState extends State<_EditMemoryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Text('Edit Memory', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF0E1117),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
