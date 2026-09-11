import 'package:flutter/material.dart';

import '../models/team_member.dart';
import '../services/admin_auth_service.dart';
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
  late TabController _tabController;

  bool _isLoading = true;
  List<TeamMember> _members = [];
  List<String> _danceList = [];
  Map<String, MemberInviteStatus> _memberStatuses = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        _danceList = dances;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invitation: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(oldDanceName == null ? 'Add New Dance' : 'Rename Dance'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Dance Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        if (oldDanceName == null) {
          await _teamRepository.createDance(result);
        } else {
          await _teamRepository.updateDanceName(oldDanceName, result);
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
        ],
      ),
    );
  }

  /// Roster Tab View
  Widget _buildRosterTab() {
    return Scaffold(
      body: _members.isEmpty
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
                    member.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isMusician ? 'Musician: ${member.instruments}' : 'Dancer',
                  ),
                  leading: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: isMusician
                            ? Colors.purple.shade100
                            : Colors.blue.shade100,
                        child: Icon(
                          isMusician ? Icons.music_note : Icons.person,
                          color: isMusician ? Colors.purple : Colors.blue,
                        ),
                      ),
                      _statusChip(_statusFor(member), compact: true),
                    ],
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
      MemberInviteStatus.notInvited => ('Not invited', Colors.grey),
    };

    return Chip(
      label: Text(label, style: TextStyle(fontSize: compact ? 9 : 12)),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
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

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _instrumentsController = TextEditingController();

  bool _isAdmin = false;
  bool _isLeader = false;
  bool _isMusician = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _instrumentsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop({
      'full_name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'is_admin': _isAdmin,
      'is_leader': _isLeader,
      'instruments': _isMusician
          ? _instrumentsController.text.trim()
          : null,
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
    _emailController.dispose();
    _phoneController.dispose();
    _instrumentsController.dispose();
    super.dispose();
  }

  void _saveMember() {
    if (_formKey.currentState!.validate()) {
      final payload = {
        'full_name': _nameController.text.trim(),
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

    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        label: Text(label),
        avatar: Icon(Icons.verified_user, size: 16, color: color),
        backgroundColor: color.withValues(alpha: 0.15),
        side: BorderSide(color: color),
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
