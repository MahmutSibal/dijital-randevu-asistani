import 'package:flutter/material.dart';

/// One tab of a staff panel.
class PanelTab {
  const PanelTab({required this.icon, required this.label, required this.page});

  final IconData icon;
  final String label;
  final Widget page;
}

/// Bottom-navigation shell shared by the doctor, hospital admin and super admin panels.
class PanelShell extends StatefulWidget {
  const PanelShell({super.key, required this.tabs});

  final List<PanelTab> tabs;

  @override
  State<PanelShell> createState() => _PanelShellState();
}

class _PanelShellState extends State<PanelShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [for (final t in widget.tabs) t.page],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final t in widget.tabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
