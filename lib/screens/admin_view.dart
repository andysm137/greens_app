import 'package:flutter/material.dart';

import '../models/team_member.dart';
import '../services/admin_auth_service.dart';
import '../services/member_display_settings.dart';
import '../services/notification_settings_repository.dart';
import '../services/team_repository.dart';

class AdminView extends StatefulWidget {
  const AdminView({Key? key}) : super(key: const Key('admin_view'));

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView>
    with SingleTickerProviderStateMixin {
  final TeamRepository _teamRepository = TeamRepository();
  final AdminAuthService _adminAuthService = AdminAuthService();
  final NotificationSettingsRepository _notificationSettingsRepository =
      NotificationSettingsRepository();
    final MemberDisplaySettingsRepository _memberDisplaySettingsRepository =
      MemberDisplaySettingsRepository();
  late TabController _tabController;

  bool _isLoading = true;
  List<TeamMember> _members = [];
  List<String> _danceList = [];
  Map<String, MemberInviteStatus> _memberStatuses = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Fetch initial data for team members and dance catalog
  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _teamRepository.fetchTeamMembers();
      final dances = await _teamRepository.fetchDanceNames();
      Map<String, MemberInviteStatus> statuses = {};
      try {
        statuses = await _adminAuthService.fetchMemberInviteStatuses();
      } catch (_) {
        statuses = {
          for (final member in members) member.id: member.inviteStatus,
        };
      }

      setState(() {
        _members = members;
        _danceList = List<String>.from(dances)
          ..sort(
            (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
          );
        _memberStatuses = statuses;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading admin data: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Open dialog to create or edit a team member
  Future<void> _openMemberDialog([TeamMember? member]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddEditMemberDialog(
        member: member,
        inviteStatus: member == null ? null : _statusFor(member),
      ),
    );

    if (result?['_action'] == 'invite' && member != null) {
      await _inviteExistingMember(member);
      return;
    }

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        if (member == null) {
          // Create new member
          await _teamRepository.createTeamMember(result);
        } else {
          // Update existing member
          await _teamRepository.updateTeamMember(member.id, result);
        }
        await _loadAdminData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save team member: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  MemberInviteStatus _statusFor(TeamMember member) =>
      _memberStatuses[member.id] ?? member.inviteStatus;

  Future<void> _inviteExistingMember(TeamMember member) async {
    setState(() => _isLoading = true);
    try {
      await _adminAuthService.inviteExistingMember(member.id);
      await _loadAdminData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitation sent to ${member.email}.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_invitationErrorMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _invitationErrorMessage(Object error) {
    final details = error.toString().toLowerCase();

    if (details.contains('email rate limit exceeded') ||
        details.contains('rate limit exceeded')) {
      return 'Invitation not sent: Supabase email limit reached. Please wait before trying again.';
    }
    if (details.contains('invalid format') ||
        details.contains('unable to validate email address')) {
      return 'Invitation not sent: please check the email address format.';
    }
    if (details.contains('already been invited') ||
        details.contains('already exists')) {
      return 'Invitation not sent: this member already has an invitation or account.';
    }
    if (details.contains('admin access required')) {
      return 'Invitation not sent: your admin session is not recognised by Supabase.';
    }
    if (details.contains('no email address')) {
      return 'Invitation not sent: add an email address to this member first.';
    }

    return 'Failed to send invitation: $error';
  }

  Future<void> _deleteMember(TeamMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Team Member'),
        content: Text(
          'Delete ${member.fullName}? This removes their profile, musician data, and sign-in account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _adminAuthService.deleteMember(member.id);
      await _loadAdminData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.fullName} was deleted.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete member: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Open dialog to create or edit a dance name
  Future<void> _openDanceDialog([String? oldDanceName]) async {
    final controller = TextEditingController(text: oldDanceName ?? '');
    final catalog = oldDanceName == null
        ? null
        : (await _teamRepository.fetchDanceCatalog()).firstWhere(
            (dance) => dance['dance_name'] == oldDanceName,
            orElse: () => <String, dynamic>{},
          );
    if (!mounted) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DanceCatalogDialog(
        controller: controller,
        initialPositions: catalog?['standard_positions'] as int? ?? 8,
        initialMaf: catalog?['has_maf'] as bool? ?? false,
        initialMab: catalog?['has_mab'] as bool? ?? false,
        initialNotes: catalog?['notes']?.toString(),
        isEditing: oldDanceName != null,
      ),
    );

    if (result != null && (result['dance_name'] as String).isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        if (oldDanceName == null) {
          await _teamRepository.addDance(
            result['dance_name'] as String,
            notes: result['notes'] as String?,
            standardPositions: result['standard_positions'] as int,
            hasMaf: result['has_maf'] as bool,
            hasMab: result['has_mab'] as bool,
          );
        } else {
          await _teamRepository.updateDanceCatalog(
            oldDanceName: oldDanceName,
            danceName: result['dance_name'] as String,
            notes: result['notes'] as String?,
            standardPositions: result['standard_positions'] as int,
            hasMaf: result['has_maf'] as bool,
            hasMab: result['has_mab'] as bool,
          );
        }
        await _loadAdminData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save dance: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  /// Delete a dance with safety prompt
  Future<void> _deleteDance(String danceName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Dance'),
        content: Text(
          'Are you sure you want to delete "$danceName"? This will remove associated competencies.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _teamRepository.deleteDance(danceName);
        await _loadAdminData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete dance: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Team Roster'),
            Tab(icon: Icon(Icons.music_note), text: 'Dance Catalog'),
            Tab(icon: Icon(Icons.notifications), text: 'Notifications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Team Roster Management
          _buildRosterTab(),

          // Tab 2: Dance Catalog Management
          _buildCatalogTab(),

          _NotificationSettingsTab(repository: _notificationSettingsRepository),
        ],
      ),
    );
  }

  /// Roster Tab View
  Widget _buildRosterTab() {
    return Scaffold(
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Use nicknames across the app'),
            value: MemberDisplaySettings.useNicknames.value,
            onChanged: (value) async {
              await _memberDisplaySettingsRepository.setUseNicknames(value);
              if (mounted) setState(() {});
            },
          ),
          Expanded(
            child: _members.isEmpty
                ? const Center(child: Text('No team members found.'))
                : ListView.builder(
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                final isMusician =
                    member.instruments != null &&
                    member.instruments!.trim().isNotEmpty;

                return ListTile(
                  title: Text(
                    member.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text(
                          isMusician
                              ? 'Musician: ${member.instruments}'
                              : 'Dancer',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10,0,0,0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                            child: Text(
                                member.lastSignInAt != null
                                  ? 'Last login: ${_formatDateTime(member.lastSignInAt!)}'
                                  : 'Last login: Never',
                                style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                           ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: _statusChip(_statusFor(member), compact: true),
                        ),
                      ),
                    ],
                  ),
                  leading: CircleAvatar(
                    backgroundColor: isMusician
                        ? Colors.purple.shade100
                        : Colors.blue.shade100,
                    child: Icon(
                      isMusician ? Icons.music_note : Icons.person,
                      color: isMusician ? Colors.purple : Colors.blue,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit member',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _openMemberDialog(member),
                      ),
                      IconButton(
                        tooltip: 'Delete member',
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteMember(member),
                      ),
                    ],
                  ),
                );
              },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMemberDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Member'),
      ),
    );
  }

  Widget _statusChip(MemberInviteStatus status, {bool compact = false}) {
    final (label, color) = switch (status) {
      MemberInviteStatus.registered => ('Registered', Colors.green),
      MemberInviteStatus.inviteSent => ('Invite sent', Colors.orange),
      MemberInviteStatus.notInvited => ('Not invited', const Color.fromARGB(255, 248, 185, 185)),
    };

    return Chip(
      label: Text(label, style: TextStyle(fontSize: compact ? 9 : 12)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  /// Dance Catalog Tab View
  Widget _buildCatalogTab() {
    return Scaffold(
      body: _danceList.isEmpty
          ? const Center(child: Text('No dances found in catalog.'))
          : ListView.builder(
              itemCount: _danceList.length,
              itemBuilder: (context, index) {
                final danceName = _danceList[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.directions_run),
                  ),
                  title: Text(
                    danceName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _openDanceDialog(danceName),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDance(danceName),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDanceDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Dance'),
      ),
    );
  }
}

class _NotificationSettingsTab extends StatefulWidget {
  const _NotificationSettingsTab({required this.repository});

  final NotificationSettingsRepository repository;

  @override
  State<_NotificationSettingsTab> createState() =>
      _NotificationSettingsTabState();
}

class _NotificationSettingsTabState extends State<_NotificationSettingsTab> {
  static const _definitions = <String, String>{
    'event_created': 'New event created',
    'deadline_reminder': 'Response deadline reminder',
    'event_status_changed': 'Event marked Go or No-go',
    'rsvp_changed': 'RSVP response changed',
    'event_details_changed': 'Event details changed',
    'competency_updated': 'Competency updated',
  };

  bool _isLoading = true;
  List<Map<String, dynamic>> _settings = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await widget.repository.fetchSettings();
      if (mounted) setState(() => _settings = settings);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to load notification settings: $error'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _settingFor(String type) => _settings.firstWhere(
    (setting) => setting['notification_type'] == type,
    orElse: () => {
      'notification_type': type,
      'is_enabled': true,
      'reminder_days': type == 'deadline_reminder' ? [3, 1] : <int>[],
      'message_template': null,
    },
  );

  Future<void> _editSetting(String type) async {
    final setting = _settingFor(type);
    final templateController = TextEditingController(
      text: setting['message_template']?.toString() ?? '',
    );
    var enabled = setting['is_enabled'] as bool? ?? true;
    var reminderDays = List<int>.from(setting['reminder_days'] as List? ?? []);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(_definitions[type]!),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enabled'),
                  value: enabled,
                  onChanged: (value) => setDialogState(() => enabled = value),
                ),
                if (type == 'deadline_reminder')
                  TextFormField(
                    initialValue: reminderDays.join(', '),
                    decoration: const InputDecoration(
                      labelText: 'Days before deadline',
                      helperText:
                          'Comma-separated whole days, for example 3, 1',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => reminderDays =
                        value
                            .split(',')
                            .map((item) => int.tryParse(item.trim()))
                            .whereType<int>()
                            .where((day) => day >= 0)
                            .toSet()
                            .toList()
                          ..sort((left, right) => right.compareTo(left)),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: templateController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message template override',
                    hintText: 'Leave blank to use the standard message',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      await widget.repository.saveSetting(
        notificationType: type,
        isEnabled: enabled,
        reminderDays: reminderDays,
        messageTemplate: templateController.text,
      );
      await _loadSettings();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save notification setting: $error'),
          ),
        );
      }
    } finally {
      templateController.dispose();
    }
  }

  Future<void> _sendTest(String type) async {
    try {
      final result = await widget.repository.sendTest(type);
      if (!mounted) return;
      final disabled = result['disabled'] == true;
      final delivered = result['delivered'] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            disabled
                ? 'This notification is disabled, so no test was sent.'
                : delivered > 0
                ? 'Test notification sent to your subscribed browser.'
                : 'No subscribed browser was found for this account.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send test notification: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return ListView(
      children: _definitions.entries.map((entry) {
        final setting = _settingFor(entry.key);
        final enabled = setting['is_enabled'] as bool? ?? true;
        final reminderDays = List<int>.from(
          setting['reminder_days'] as List? ?? [],
        );
        return ListTile(
          leading: Icon(
            enabled ? Icons.notifications_active : Icons.notifications_off,
          ),
          title: Text(entry.value),
          subtitle: entry.key == 'deadline_reminder'
              ? Text(
                  reminderDays.isEmpty
                      ? 'No reminders configured'
                      : '${reminderDays.join(' and ')} days before deadline',
                )
              : Text(enabled ? 'Enabled' : 'Disabled'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Send test to this browser',
                icon: const Icon(Icons.send_outlined),
                onPressed: () => _sendTest(entry.key),
              ),
              const Icon(Icons.tune),
            ],
          ),
          onTap: () => _editSetting(entry.key),
        );
      }).toList(),
    );
  }
}

/// Dialog for Adding/Editing a Team Member with Musician Field Toggle
class AddEditMemberDialog extends StatefulWidget {
  final TeamMember? member;
  final MemberInviteStatus? inviteStatus;

  const AddEditMemberDialog({super.key, this.member, this.inviteStatus});

  @override
  State<AddEditMemberDialog> createState() => _AddEditMemberDialogState();
}

class InviteMemberDialog extends StatefulWidget {
  const InviteMemberDialog({super.key});

  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class DanceCatalogDialog extends StatefulWidget {
  final TextEditingController controller;
  final int initialPositions;
  final bool initialMaf;
  final bool initialMab;
  final String? initialNotes;
  final bool isEditing;

  const DanceCatalogDialog({
    super.key,
    required this.controller,
    required this.initialPositions,
    required this.initialMaf,
    required this.initialMab,
    required this.initialNotes,
    required this.isEditing,
  });

  @override
  State<DanceCatalogDialog> createState() => _DanceCatalogDialogState();
}

class _DanceCatalogDialogState extends State<DanceCatalogDialog> {
  late int _positions;
  late bool _hasMaf;
  late bool _hasMab;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _positions = widget.initialPositions == 12 ? 12 : 8;
    _hasMaf = widget.initialMaf;
    _hasMab = widget.initialMab;
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop({
      'dance_name': widget.controller.text.trim(),
      'standard_positions': _positions,
      'has_maf': _hasMaf,
      'has_mab': _hasMab,
      'notes': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Dance' : 'Add New Dance'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Dance Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _positions,
              decoration: const InputDecoration(
                labelText: 'Standard positions',
              ),
              items: const [
                DropdownMenuItem(value: 8, child: Text('8')),
                DropdownMenuItem(
                  value: 12,
                  child: Text('Can be performed as 12'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _positions = value);
              },
            ),
            SwitchListTile(
              title: const Text('MAF'),
              subtitle: const Text('Middle Ahead Front'),
              value: _hasMaf,
              onChanged: (value) => setState(() => _hasMaf = value),
            ),
            SwitchListTile(
              title: const Text('MAB'),
              subtitle: const Text('Middle Along Back'),
              value: _hasMab,
              onChanged: (value) => setState(() => _hasMab = value),
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instrumentsController = TextEditingController();

  bool _isAdmin = false;
  bool _isLeader = false;
  bool _isMusician = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _instrumentsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop({
      'full_name': _nameController.text.trim(),
      'nickname': _nicknameController.text.trim().isEmpty
          ? null
          : _nicknameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'is_admin': _isAdmin,
      'is_leader': _isLeader,
      'instruments': _isMusician ? _instrumentsController.text.trim() : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invite Team Member'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: 'Nickname'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email *'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email address'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              SwitchListTile(
                title: const Text('Team Leader'),
                value: _isLeader,
                onChanged: (value) => setState(() => _isLeader = value),
              ),
              SwitchListTile(
                title: const Text('Admin Access'),
                value: _isAdmin,
                onChanged: (value) => setState(() => _isAdmin = value),
              ),
              SwitchListTile(
                title: const Text('Is Musician?'),
                value: _isMusician,
                onChanged: (value) => setState(() {
                  _isMusician = value;
                  if (!value) _instrumentsController.clear();
                }),
              ),
              if (_isMusician)
                TextFormField(
                  controller: _instrumentsController,
                  decoration: const InputDecoration(
                    labelText: 'Instrument(s)',
                    hintText: 'Accordion, Melodeon, Fiddle',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter at least one instrument'
                      : null,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send Invite')),
      ],
    );
  }
}

class _AddEditMemberDialogState extends State<AddEditMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instrumentsController = TextEditingController();

  bool _isAdmin = false;
  bool _isLeader = false;
  bool _isMusician = false;

  @override
  void initState() {
    super.initState();
    if (widget.member != null) {
      _nameController.text = widget.member!.fullName;
      _nicknameController.text = widget.member!.nickname ?? '';
      _emailController.text = widget.member!.email ?? '';
      _phoneController.text = widget.member!.phone ?? '';
      _instrumentsController.text = widget.member!.instruments ?? '';
      _isAdmin = widget.member!.isAdmin;
      _isLeader = widget.member!.isLeader;
      _isMusician =
          widget.member!.instruments != null &&
          widget.member!.instruments!.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _instrumentsController.dispose();
    super.dispose();
  }

  void _saveMember() {
    if (_formKey.currentState!.validate()) {
      final payload = {
        'full_name': _nameController.text.trim(),
        'nickname': _nicknameController.text.trim().isEmpty
          ? null
          : _nicknameController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'is_admin': _isAdmin,
        'is_leader': _isLeader,
        'instruments': _isMusician ? _instrumentsController.text.trim() : null,
      };

      Navigator.of(context).pop(payload);
    }
  }

  Widget _buildInviteStatus() {
    final status = widget.inviteStatus ?? MemberInviteStatus.notInvited;
    final (label, color) = switch (status) {
      MemberInviteStatus.registered => ('Member registered', Colors.green),
      MemberInviteStatus.inviteSent => ('Invite sent', Colors.orange),
      MemberInviteStatus.notInvited => ('Not invited', Colors.grey),
    };

    final lastLogin = widget.member?.lastSignInAt;

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            label: Text(label),
            avatar: Icon(Icons.verified_user, size: 16, color: color),
            backgroundColor: color.withValues(alpha: 0.15),
            side: BorderSide(color: color),
          ),
          if (lastLogin != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last login: ${_AdminViewState._formatDateTime(lastLogin)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.member == null ? 'Add Team Member' : 'Edit Member'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.member != null) ...[
                _buildInviteStatus(),
                const SizedBox(height: 8),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name *'),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nicknameController,
                decoration: const InputDecoration(labelText: 'Nickname'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Admin Access'),
                value: _isAdmin,
                onChanged: (val) => setState(() => _isAdmin = val),
              ),
              SwitchListTile(
                title: const Text('Team Leader'),
                value: _isLeader,
                onChanged: (val) => setState(() => _isLeader = val),
              ),
              SwitchListTile(
                title: const Text('Is Musician?'),
                subtitle: const Text('Toggle to enter instrument details'),
                value: _isMusician,
                onChanged: (val) {
                  setState(() {
                    _isMusician = val;
                    if (!_isMusician) {
                      _instrumentsController.clear();
                    }
                  });
                },
              ),
              if (_isMusician) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _instrumentsController,
                  decoration: const InputDecoration(
                    labelText: 'Instrument(s)',
                    hintText: 'e.g., Accordion, Melodeon, Fiddle',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (_isMusician && (val == null || val.trim().isEmpty)) {
                      return 'Please enter at least one instrument';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (widget.member != null &&
            widget.inviteStatus == MemberInviteStatus.notInvited &&
            _emailController.text.trim().isNotEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.mail_outline),
            label: const Text('Send Invite'),
            onPressed: () => Navigator.of(context).pop({'_action': 'invite'}),
          ),
        ElevatedButton(onPressed: _saveMember, child: const Text('Save')),
      ],
    );
  }
}
