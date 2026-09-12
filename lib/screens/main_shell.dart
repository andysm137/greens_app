// lib/screens/main_shell.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:greens_app/screens/admin_view.dart';
import 'package:greens_app/screens/events_screen.dart';
import 'package:greens_app/models/team_member.dart';

import 'skill_matrix_view.dart';
import 'dance_builder_view.dart';

class MainShell extends StatefulWidget {
  final TeamMember currentMember;

  const MainShell({super.key, required this.currentMember});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final List<String> _workspaceTitles = [
    'Bookings',
    'Skill Matrix',
    'Dance Builder',
    'Set Sheet',
    'Admin',
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text('Silkstone Greens: ${_workspaceTitles[_selectedIndex]}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  widget.currentMember.isAdmin
                      ? 'Admin'
                      : (widget.currentMember.isLeader ? 'Leader' : 'Member'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout),
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                ),
              ],
            ),
          ),
        ],
      ), //AppBar
      body: isMobile
          ? _getSelectedWorkspaceWidget()
          : Row(
              children: [
                _buildNavigationRail(),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _getSelectedWorkspaceWidget()),
              ],
            ),
      bottomNavigationBar: isMobile ? _buildNavigationBar() : null,
    );
  }

  NavigationRail _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectWorkspace,
      labelType: NavigationRailLabelType.all,
      destinations: _navigationDestinations(),
    );
  }

  NavigationBar _buildNavigationBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectWorkspace,
      destinations: _navigationDestinations()
          .map(
            (destination) => NavigationDestination(
              icon: destination.icon,
              selectedIcon: destination.selectedIcon,
              label: (destination.label as Text).data ?? '',
            ),
          )
          .toList(),
    );
  }

  List<NavigationRailDestination> _navigationDestinations() {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.event_note),
        label: Text('Bookings'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.grid_view),
        label: Text('Skills'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.theater_comedy),
        label: Text('Builder'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.description),
        label: Text('Set Sheet'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.admin_panel_settings),
        label: Text('Admin'),
      ),
    ];
  }

  void _selectWorkspace(int index) {
    setState(() => _selectedIndex = index);
  }

  // This method selects which screen/widget to display based on the active sidebar tab
  Widget _getSelectedWorkspaceWidget() {
    switch (_selectedIndex) {
      case 0:
        return EventsScreen(
          isLeaderOrAdmin:
              widget.currentMember.isLeader || widget.currentMember.isAdmin,
          currentMemberId: widget.currentMember.id,
        );
      case 1:
        return const SkillsMatrixView();
      case 2:
        return DanceBuilderView(
          currentMemberId: widget.currentMember.id,
        );
      //return const StageBuilderView(
      //  danceName: 'Sallys Dance',
      //  standardPositions: 8,
      //  initialMaf: true,
      //);
      case 3:
        return const Center(child: Text('Set Sheet Workspace'));
      case 4:
        return widget.currentMember.isAdmin
            ? const AdminView()
            : const Center(child: Text('Admin access required.'));
      default:
        return const Center(child: Text('Workspace'));
    }
  }
}
