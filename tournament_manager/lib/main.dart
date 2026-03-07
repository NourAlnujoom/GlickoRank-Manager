import 'package:flutter/material.dart';
import 'screens/games_screen.dart';
import 'screens/players_screen.dart';
import 'screens/standings_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tournament Manager',
      debugShowCheckedModeBanner: false,
      
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
      ),
      
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212), 
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
        ),
      ),
      
      themeMode: _themeMode,
      
      home: MainTabsScreen(toggleTheme: _toggleTheme, isDark: _themeMode == ThemeMode.dark),
    );
  }
}

class MainTabsScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const MainTabsScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> {
  int _currentIndex = 1;

  final List<Widget> _screens = [
    const PlayersScreen(),
    const GamesScreen(),
    const StandingsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Glicko Manager"),
        actions: [
          IconButton(
            onPressed: widget.toggleTheme,
            icon: Icon(widget.isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: "Toggle Theme",
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: "Players"),
          NavigationDestination(icon: Icon(Icons.sports_esports), label: "Games"),
          NavigationDestination(icon: Icon(Icons.leaderboard), label: "Standings"),
          NavigationDestination(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}