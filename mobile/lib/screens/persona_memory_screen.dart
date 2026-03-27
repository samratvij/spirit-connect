import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/persona.dart';
import '../providers/memory_provider.dart';

class PersonaMemoryScreen extends ConsumerWidget {
  final Persona persona;
  const PersonaMemoryScreen({super.key, required this.persona});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(memoryProvider);
    final memories = state.memories.where((m) => m.personaId == persona.modelName).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0E1117),
      appBar: AppBar(
        title: Text('${persona.name}\'s Memories', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: memories.isEmpty
          ? _EmptyState(persona: persona)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: memories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final memory = memories[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memory.content,
                        style: GoogleFonts.inter(color: Colors.white, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy').format(memory.updatedAt),
                            style: GoogleFonts.inter(color: const Color(0xFF484F58), fontSize: 11),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF8B949E)),
                                onPressed: () {
                                  // Re-use logic from old MemoryScreen
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFF8B949E)),
                                onPressed: () {
                                   ref.read(memoryProvider.notifier).delete(memory.id);
                                },
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
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Persona persona;
  const _EmptyState({required this.persona});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(persona.icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'Keep chatting with ${persona.name}',
            style: GoogleFonts.inter(color: const Color(0xFF8B949E)),
          ),
          Text(
            'Memories will appear here automatically.',
            style: GoogleFonts.inter(color: const Color(0xFF484F58), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
