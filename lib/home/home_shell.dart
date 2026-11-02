import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import 'home_page.dart';
import 'profile_page.dart';
import 'services_page.dart';

/// Tab indexes of the bottom navigation bar.
abstract final class AppTab {
  static const home = 0;
  static const assistant = 1;
  static const services = 2;
  static const profile = 3;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = AppTab.home;

  void _open(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab alive, so a chat in progress survives tab switches.
      body: IndexedStack(
        index: _tab,
        children: [
          HomePage(onOpenTab: _open),
          const ChatScreen(),
          ServicesPage(onOpenTab: _open),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _open,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: 'Anasayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_rounded),
            label: 'Asistan',
          ),
          NavigationDestination(
            icon: Icon(Icons.view_list_rounded),
            label: 'Hizmetler',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profilim',
          ),
        ],
      ),
    );
  }
}
