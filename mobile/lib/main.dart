import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/chat_screen.dart';
import 'screens/history_screen.dart';
import 'screens/memory_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/persona_provider.dart';

void main() {
  runApp(const ProviderScope(child: SpiritConnectApp()));
}

class SpiritConnectApp extends StatelessWidget {
  const SpiritConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spirit Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF8B5CF6),
          surface: const Color(0xFF161B22),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E1117),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF8B949E)),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF161B22),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Color(0xFF161B22),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        useMaterial3: true,
      ),
      home: const _MainShell(),
    );
  }
}

class _MainShell extends ConsumerWidget {
  const _MainShell();

  static const _screens = [
    ChatScreen(),
    MemoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var currentIndex = ref.watch(selectedTabProvider);
    // Adjust index because we removed History (index 0)
    // If History was selected, default to Chat
    if (currentIndex == 0) currentIndex = 1;
    // UI expects 0, 1, 2 for the 3 screens left
    final adjustedIndex = currentIndex - 1;

    return Scaffold(
      body: IndexedStack(
        index: adjustedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF30363D), width: 1)),
        ),
        child: NavigationBar(
          backgroundColor: const Color(0xFF161B22),
          indicatorColor: const Color(0xFF6366F1).withValues(alpha:0.2),
          selectedIndex: adjustedIndex,
          onDestinationSelected: (i) => ref.read(selectedTabProvider.notifier).state = i + 1,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline, color: Color(0xFF8B949E)),
              selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFF6366F1)),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.memory_outlined, color: Color(0xFF8B949E)),
              selectedIcon: Icon(Icons.memory, color: Color(0xFF6366F1)),
              label: 'Memories',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: Color(0xFF8B949E)),
              selectedIcon: Icon(Icons.settings, color: Color(0xFF6366F1)),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
