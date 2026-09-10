// lib/screens/main_shell.dart

import 'package:flutter/material.dart';
import 'package:greens_app/screens/admin_view.dart';
import 'package:greens_app/screens/events_screen.dart';
import 'package:greens_app/models/team_member.dart';

import 'skill_matrix_view.dart';
//import 'stage_builder_view.dart';
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
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.event_note),
                label: Text('Bookings'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.grid_view),
                label: Text('Skill Matrix'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.theater_comedy),
                label: Text('Dance Builder'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description),
                label: Text('Set Sheet'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.admin_panel_settings),
                label: Text('Admin'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _getSelectedWorkspaceWidget()),
        ],
      ), // Body
    );
  }

  // This method selects which screen/widget to display based on the active sidebar tab
  Widget _getSelectedWorkspaceWidget() {
    switch (_selectedIndex) {
      case 0:
        return const EventsScreen(
          isLeaderOrAdmin: false,
          currentMemberId: '',
        );
      case 1:
        return const SkillsMatrixView();
      case 2:
        return const DanceBuilderView(
          currentMemberId: '',
        );
      //return const StageBuilderView(
      //  danceName: 'Sallys Dance',
      //  standardPositions: 8,
      //  initialMaf: true,
      //);
      case 3:
        return const Center(child: Text('Set Sheet Workspace'));
      case 4:
        return const AdminView();
      default:
        return const Center(child: Text('Workspace'));
    }
  }
}
