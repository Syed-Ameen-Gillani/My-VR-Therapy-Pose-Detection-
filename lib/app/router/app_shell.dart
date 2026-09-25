import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;
  static const labels = ['Overview', 'Patients', 'Exercises', 'Settings'];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.people_outline,
    Icons.accessibility_new,
    Icons.settings_outlined,
  ];
  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    final scaled = MediaQuery.textScalerOf(context).scale(14) / 14;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VR Therapy'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Semantics(
              label: 'Demo data only',
              child: Chip(
                label: const Text('DEMO'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: shell.currentIndex,
                onDestinationSelected: _select,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(labels[i]),
                    ),
                ],
              ),
            if (wide) const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              height: 80 + (scaled > 1.3 ? 24 : 0),
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _select,
              destinations: [
                for (var i = 0; i < labels.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
              ],
            ),
    );
  }
}
