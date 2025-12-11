// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:emotional_dairy/screens/dashboard.dart';
import 'package:emotional_dairy/screens/create_entry_screen.dart';
import 'past_entries.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _fabController;

  final _pages = [
    const DashboardScreen(),
    const CreateEntryScreen(),
    const PastEntriesScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    setState(() => _index = index);
    _fabController.forward().then((_) => _fabController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: _pages[_index],
      ),
      floatingActionButton: _index == 0
          ? ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                CurvedAnimation(
                  parent: _fabController,
                  curve: Curves.elasticOut,
                ),
              ),
              child: SizedBox(
                width: 200,
                height: 64,
                child: FloatingActionButton.extended(
                  onPressed: () => _onTabTapped(1),
                  icon: const Icon(Icons.add_rounded, size: 26),
                  label: const Text(
                    'New Entry',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  elevation: 6,
                  backgroundColor: Colors.indigo.shade300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onTabTapped,
            height: 70,
            elevation: 0,
            backgroundColor: Colors.white,
            indicatorColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.15),
            animationDuration: const Duration(milliseconds: 400),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.grid_view_rounded),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.edit_note_rounded),
                selectedIcon: Icon(Icons.edit_note_rounded),
                label: 'New Entry',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_stories_rounded),
                selectedIcon: Icon(Icons.auto_stories_rounded),
                label: 'Entries',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
