import 'package:flutter/material.dart';

import '../models/team_member.dart';
import '../services/team_repository.dart';

class AdminView extends StatefulWidget {
  const AdminView({Key? key}) : super(key: const Key('admin_view'));

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView>
    with SingleTickerProviderStateMixin {
  final TeamRepository _teamRepository = TeamRepository();
  late TabController _tabController;

  bool _isLoading = true;
  List<TeamMember> _members = [];
  List<String> _danceList = [];

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

      setState(() {
        _members = members;
        _danceList = dances;
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
      builder: (context) => AddEditMemberDialog(member: member),
    );

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
                  leading: CircleAvatar(
                    backgroundColor: isMusician
                        ? Colors.purple.shade100
                        : Colors.blue.shade100,
                    child: Icon(
                      isMusician ? Icons.music_note : Icons.person,
                      color: isMusician ? Colors.purple : Colors.blue,
                    ),
                  ),
                  title: Text(
                    member.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    isMusician ? 'Musician: ${member.instruments}' : 'Dancer',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _openMemberDialog(member),
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

  const AddEditMemberDialog({super.key, this.member});

  @override
  State<AddEditMemberDialog> createState() => _AddEditMemberDialogState();
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
        ElevatedButton(onPressed: _saveMember, child: const Text('Save')),
      ],
    );
  }
}
