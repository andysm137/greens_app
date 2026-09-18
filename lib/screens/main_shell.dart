// lib/screens/main_shell.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:greens_app/screens/admin_view.dart';
import 'package:greens_app/screens/events_screen.dart';
import 'package:greens_app/models/team_member.dart';

import '../services/notification_subscription_service.dart';
import '../services/notifications_repository.dart';
import 'skill_matrix_view.dart';
import 'booking_skill_matrix_view.dart';
import 'dance_builder_view.dart';
import 'set_sheet_view.dart';

class MainShell extends StatefulWidget {
  final TeamMember currentMember;

  const MainShell({super.key, required this.currentMember});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  String? _pendingEventId;
  String? _pendingHighlightMemberId;
  String? _pendingDancerId;
  String? _pendingDanceName;
  final NotificationSubscriptionService _notificationSubscriptionService =
      NotificationSubscriptionService();
  final NotificationsRepository _notificationsRepository =
      NotificationsRepository();
  int _unreadNotificationCount = 0;
  RealtimeChannel? _notificationsChannel;

  bool get _isLeaderOrAdmin =>
      widget.currentMember.isLeader || widget.currentMember.isAdmin;

  List<String> get _workspaceTitles => [
    'Bookings',
    'Skill Matrix',
    if (_isLeaderOrAdmin) 'Dance Builder',
    if (_isLeaderOrAdmin) 'Booking Skill Matrix',
    if (_isLeaderOrAdmin) 'Set Sheet',
    if (widget.currentMember.isAdmin) 'Admin',
  ];

  @override
  void initState() {
    super.initState();
    _refreshUnreadNotificationCount();
    _notificationsChannel = Supabase.instance.client
        .channel('notifications-${widget.currentMember.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'member_id',
            value: widget.currentMember.id,
          ),
          callback: (_) => _refreshUnreadNotificationCount(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    final channel = _notificationsChannel;
    if (channel != null) Supabase.instance.client.removeChannel(channel);
    super.dispose();
  }

  Future<void> _refreshUnreadNotificationCount() async {
    try {
      final count = await _notificationsRepository.fetchUnreadCount();
      if (mounted) setState(() => _unreadNotificationCount = count);
    } catch (_) {}
  }

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
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: _showNotificationMenu,
                    ),
                    if (_unreadNotificationCount > 0)
                      Positioned(
                        right: 4,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _unreadNotificationCount > 99
                                ? '99+'
                                : '$_unreadNotificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
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
      ),
      // Workspace content always stays as the last Row child so orientation
      // changes (which flip isMobile) only add/remove the leading rail
      // instead of reparenting the content and resetting its State.
      body: Row(
        children: [
          if (!isMobile) _buildNavigationRail(),
          if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _getSelectedWorkspaceWidget()),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildNavigationBar() : null,
    );
  }

  Future<void> _enableNotifications() async {
    try {
      await _notificationSubscriptionService.enableForMember(
        widget.currentMember.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications enabled for this browser.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to disable notifications: $error')),
        );
      }
    }
  }

  Future<void> _showNotificationMenu() async {
    final notifications = await _notificationsRepository.fetchRecent();
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            children: [
              const ListTile(
                title: Text('Notifications'),
              ),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(child: Text('No notifications'))
                    : ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          final isUnread = notification['read_at'] == null;
                          return ListTile(
                            leading: Icon(
                              isUnread
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                            ),
                            title: Text(notification['title'].toString()),
                            subtitle: Text(notification['body'].toString()),
                            tileColor: isUnread
                                ? Theme.of(context).colorScheme.primaryContainer
                                      .withValues(alpha: 0.25)
                                : null,
                            onTap: () async {
                              if (isUnread) {
                                await _notificationsRepository.markRead(
                                  notification['id'].toString(),
                                );
                              }
                              if (context.mounted) {
                                if (notification['notification_type'] ==
                                    'competency_updated') {
                                  final dancerId =
                                      notification['related_member_id']
                                          ?.toString() ??
                                      '';
                                  final danceName =
                                      notification['dance_name']?.toString() ??
                                      '';
                                  Navigator.pop(
                                    context,
                                    'competency:$dancerId:${Uri.encodeComponent(danceName)}',
                                  );
                                } else {
                                  final eventId =
                                      notification['event_id']?.toString() ??
                                      '';
                                  final relatedMemberId =
                                      notification['related_member_id']
                                          ?.toString();
                                  Navigator.pop(
                                    context,
                                    relatedMemberId != null &&
                                            relatedMemberId.isNotEmpty
                                        ? 'event:$eventId:$relatedMemberId'
                                        : 'event:$eventId',
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
              ),
              ListTile(
                leading: const Icon(Icons.done_all),
                title: const Text('Mark all read'),
                onTap: () => Navigator.pop(context, 'read_all'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: const Text('Clear all notifications'),
                onTap: () => Navigator.pop(context, 'clear_all'),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Enable notifications'),
                onTap: () => Navigator.pop(context, 'enable'),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('Disable on this browser'),
                onTap: () => Navigator.pop(context, 'disable'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'enable') await _enableNotifications();
    if (action == 'disable') await _disableNotifications();
    if (action == 'read_all') {
      await _notificationsRepository.markAllRead();
    }
    if (action == 'clear_all') {
      await _notificationsRepository.clearAll();
    }
    if (action == 'read_all' || action == 'clear_all') {
      await _refreshUnreadNotificationCount();
    }
    if (action?.startsWith('event:') == true) {
      final rest = action!.substring('event:'.length);
      final parts = rest.split(':');
      final eventId = parts.isNotEmpty ? parts[0] : '';
      final highlightMemberId = parts.length > 1 && parts[1].isNotEmpty
          ? parts[1]
          : null;
      if (eventId.isNotEmpty) {
        setState(() {
          _pendingEventId = eventId;
          _pendingHighlightMemberId = highlightMemberId;
          _selectedIndex = 0;
        });
      }
    }
    if (action?.startsWith('competency:') == true) {
      final parts = action!.substring('competency:'.length).split(':');
      final dancerId = parts.isNotEmpty ? parts[0] : '';
      final danceName = parts.length > 1 ? Uri.decodeComponent(parts[1]) : '';
      if (dancerId.isNotEmpty) {
        setState(() {
          _pendingDancerId = dancerId;
          _pendingDanceName = danceName.isNotEmpty ? danceName : null;
          _selectedIndex = 1;
        });
      }
    }
  }

  Future<void> _disableNotifications() async {
    try {
      await _notificationSubscriptionService.disableForCurrentBrowser();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notifications disabled on this browser.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to disable notifications: $error')),
        );
      }
    }
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
    return [
      const NavigationRailDestination(
        icon: Icon(Icons.event_note),
        label: Text('Bookings'),
      ),
      const NavigationRailDestination(
        icon: Icon(Icons.grid_view),
        label: Text('Skills'),
      ),
      if (_isLeaderOrAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.theater_comedy),
          label: Text('Builder'),
        ),
      if (_isLeaderOrAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.checklist),
          label: Text('Booking Matrix'),
        ),
      if (_isLeaderOrAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.description),
          label: Text('Set Sheet'),
        ),
      if (widget.currentMember.isAdmin)
        const NavigationRailDestination(
          icon: Icon(Icons.admin_panel_settings),
          label: Text('Admin'),
        ),
    ];
  }

  void _selectWorkspace(int index) {
    setState(() {
      _selectedIndex = index;
      // Reset pending navigation IDs on manual tab switch
      _pendingEventId = null;
      _pendingHighlightMemberId = null;
      _pendingDancerId = null;
      _pendingDanceName = null;
    });
  }

  Widget _getSelectedWorkspaceWidget() {
    switch (_selectedIndex) {
      case 0:
        return EventsScreen(
          key: ValueKey('events_screen_${_pendingEventId ?? 'default'}'),
          isLeaderOrAdmin: _isLeaderOrAdmin,
          isAdmin: widget.currentMember.isAdmin,
          currentMemberId: widget.currentMember.id,
          initialEventId: _pendingEventId,
          highlightMemberId: _pendingHighlightMemberId,
        );
      case 1:
        return SkillsMatrixView(
          key: ValueKey('skills_screen_${_pendingDancerId ?? 'default'}'),
          currentMember: widget.currentMember,
          initialDancerId: _pendingDancerId,
          highlightDanceName: _pendingDanceName,
        );
      case 2:
        return _isLeaderOrAdmin
            ? DanceBuilderView(currentMemberId: widget.currentMember.id)
            : const Center(child: Text('Leader or admin access required.'));
      case 3:
        return _isLeaderOrAdmin
            ? const BookingSkillMatrixView()
            : const Center(child: Text('Leader or admin access required.'));
      case 4:
        return _isLeaderOrAdmin
            ? const SetSheetView()
            : const Center(child: Text('Leader or admin access required.'));
      case 5:
        return widget.currentMember.isAdmin
            ? const AdminView()
            : const Center(child: Text('Admin access required.'));
      default:
        return const Center(child: Text('Workspace'));
    }
  }
}