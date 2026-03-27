import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/persona.dart';

final personasProvider = Provider<List<Persona>>((ref) {
  return const [
    Persona(
      id: 'spirit',
      name: 'Spirit',
      description: 'Your empathetic CBT therapist and guide.',
      icon: '🧠',
      modelName: 'qwen-spirit',
    ),
    Persona(
      id: 'general',
      name: 'Assistant',
      description: 'Knowledgeable and helpful for any task.',
      icon: '🤖',
      modelName: 'qwen3.5:35b',
    ),
    Persona(
      id: 'creative',
      name: 'Creative',
      description: 'Imaginative storyteller and brainstormer.',
      icon: '🎨',
      modelName: 'llama3.2', // Or another creative model if available
    ),
  ];
});

final selectedPersonaProvider = StateProvider<Persona>((ref) {
  final personas = ref.watch(personasProvider);
  return personas.first;
});

final selectedTabProvider = StateProvider<int>((ref) => 1); // Default to Chat tab (index 1)
