// lib/screens/dance_builder_view.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/team_repository.dart';
import '../models/team_member.dart';
import '../models/competency.dart';
import '../models/event_model.dart';

class DanceBuilderView extends StatefulWidget {
  final String currentMemberId;

  const DanceBuilderView({super.key, required this.currentMemberId});

  @override
  State<DanceBuilderView> createState() => _DanceBuilderViewState();
}

class _DanceBuilderViewState extends State<DanceBuilderView> {
  final TeamRepository _teamRepository = TeamRepository();
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _selectedDance;
  List<String> _dances = [];
  List<TeamMember> _allMembers = [];
  List<Competency> _allCompetencies = [];

  // Event Availability Tracking
  List<EventModel> _events = [];
  EventModel? _selectedEvent;
  List<String> _absentMemberIds = [];

  Map<int, String> _positionMemberNames = {};
  bool _includeMaf = false;
  bool _includeMab = false;
  final int _standardPositions = 8;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  /// Initial load for dances, team members, and upcoming events
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final dances = await _teamRepository.fetchDanceNames();
      final members = await _teamRepository.fetchTeamMembers();

      // Fetch upcoming events for attendance cross-referencing
      final eventsResponse = await _supabase
          .from('events')
          .select()
          .order('event_date', ascending: true);

      final events = (eventsResponse as List)
          .map((e) => EventModel.fromMap(e))
          .toList();

      setState(() {
        _dances = dances;
        _allMembers = members;
        _events = events;

        if (_dances.isNotEmpty && _selectedDance == null) {
          _selectedDance = _dances.first;
        }
        if (_events.isNotEmpty && _selectedEvent == null) {
          _selectedEvent = _events.first;
        }
      });

      if (_selectedEvent != null) {
        await _loadAbsentMembersForEvent(_selectedEvent!.id);
      }
      if (_selectedDance != null) {
        await _loadAssignmentsForDance(_selectedDance!);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Fetches member IDs marked as 'Not Attending' for the selected event
  Future<void> _loadAbsentMembersForEvent(String eventId) async {
    final response = await _supabase
        .from('event_rsvps')
        .select('member_id')
        .eq('event_id', eventId)
        .eq('rsvp_status', 'Not Attending');

    final absentIds = (response as List)
        .map((item) => item['member_id'].toString())
        .toList();

    setState(() {
      _absentMemberIds = absentIds;
    });
  }

  /// Fetches position assignments and competencies for the selected dance
  Future<void> _loadAssignmentsForDance(String danceName) async {
    final assignments = await _teamRepository.fetchDanceAssignments(danceName);
    final competencies = await _teamRepository.fetchCompetenciesForDance(
      danceName,
    );

    Map<int, String> namesMap = {};

    for (var item in assignments) {
      int pos = item['position_number'];
      String memberId = item['member_id'];

      var member = _allMembers.firstWhere(
        (m) => m.id == memberId,
        orElse: () => TeamMember(id: '', fullName: 'Unknown'),
      );
      namesMap[pos] = member.fullName;
    }

    setState(() {
      _positionMemberNames = namesMap;
      _allCompetencies = competencies;
    });
  }

  /// Assign modal that filters out non-qualifying roles AND absent members
  void _showAssignDialog(int positionNumber, String positionLabel) {
    final eligibleMembers = _allMembers.where((m) {
      // 1. Role Filter: Musician (pos 0) vs Dancer (pos != 0)
      final matchesRole = (positionNumber == 0) ? m.isMusician : !m.isMusician;

      // 2. Availability Filter: Hide members who RSVP'd 'Not Attending'
      final isAvailable = !_absentMemberIds.contains(m.id);

      return matchesRole && isAvailable;
    }).toList();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Assign Member to $positionLabel'),
              const SizedBox(height: 4),
              Text(
                'Event: ${_selectedEvent?.title ?? "General"} (${_absentMemberIds.length} unavailable)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: eligibleMembers.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Text(
                      'No available team members match this position for the selected event date.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: eligibleMembers.length,
                    itemBuilder: (context, index) {
                      final member = eligibleMembers[index];

                      int dbPosition = positionNumber;
                      if (positionNumber == -1) dbPosition = 99; // MAF
                      if (positionNumber == -2) dbPosition = 98; // MAB

                      final competency = _allCompetencies.firstWhere(
                        (c) =>
                            c.memberId == member.id &&
                            c.positionNumber == dbPosition,
                        orElse: () => Competency(
                          id: '',
                          memberId: member.id,
                          danceName: _selectedDance!,
                          positionNumber: dbPosition,
                          proficiencyLevel: 'None',
                        ),
                      );

                      final isQualified =
                          competency.proficiencyLevel != 'None' &&
                          competency.proficiencyLevel != '-';

                      return ListTile(
                        title: Text(member.fullName),
                        subtitle: Text(
                          isQualified
                              ? 'Proficiency: ${competency.proficiencyLevel}'
                              : 'Not graded for this slot',
                        ),
                        trailing: isQualified
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.warning, color: Colors.orange),
                        onTap: () async {
                          await _teamRepository.assignMemberToPosition(
                            danceName: _selectedDance!,
                            positionNumber: positionNumber,
                            memberId: member.id,
                          );
                          if (context.mounted) Navigator.pop(context);
                          await _loadAssignmentsForDance(_selectedDance!);
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPositionCard(int positionCode, String label, Color badgeColor) {
    final assignedName = _positionMemberNames[positionCode];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: assignedName != null
                  ? badgeColor
                  : Colors.grey.shade400,
              child: Text(
                positionCode > 0
                    ? '$positionCode'
                    : (positionCode == 0 ? 'MUS' : label.substring(0, 3)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  Text(
                    assignedName ?? 'Unassigned',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: assignedName != null
                          ? Colors.black87
                          : Colors.red.shade300,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (assignedName != null)
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                onPressed: () async {
                  await _teamRepository.removeMemberFromPosition(
                    danceName: _selectedDance!,
                    positionNumber: positionCode,
                  );
                  await _loadAssignmentsForDance(_selectedDance!);
                },
              ),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 28),
              ),
              onPressed: () => _showAssignDialog(positionCode, label),
              child: Text(
                assignedName != null ? 'Change' : 'Assign',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dance Builder & Lineup Selector',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Header Controls: Event Selector & Repertoire Dropdown
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Target Event Dropdown
                      Expanded(
                        child: DropdownButtonFormField<EventModel>(
                          initialValue: _selectedEvent,
                          decoration: const InputDecoration(
                            labelText: 'Target Practice / Event',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: _events.map((e) {
                            return DropdownMenuItem(
                              value: e,
                              child: Text('${e.title} (${e.eventType})'),
                            );
                          }).toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              setState(() => _selectedEvent = val);
                              await _loadAbsentMembersForEvent(val.id);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Dance Repertoire Dropdown
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedDance,
                          decoration: const InputDecoration(
                            labelText: 'Dance Repertoire',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: _dances.map((d) {
                            return DropdownMenuItem(value: d, child: Text(d));
                          }).toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              setState(() => _selectedDance = val);
                              await _loadAssignmentsForDance(val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'MAF:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _includeMaf,
                            activeThumbColor: Colors.deepOrange,
                            onChanged: (val) =>
                                setState(() => _includeMaf = val),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Text(
                            'MAB:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _includeMab,
                            activeThumbColor: Colors.teal,
                            onChanged: (val) =>
                                setState(() => _includeMab = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Formation Stage Layout Visualizer
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Position 0: Musician
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 280,
                        height: 60,
                        child: _buildPositionCard(
                          0,
                          'Musician',
                          Colors.purple.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Optional MAF Slot
                  if (_includeMaf) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          height: 60,
                          child: _buildPositionCard(
                            -1,
                            'MAF (Middle at Front)',
                            Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Standard 8 Positions
                  for (int i = 1; i <= _standardPositions; i += 2) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: _buildPositionCard(
                              i,
                              'Position $i',
                              Colors.indigo,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 60,
                            child: (i + 1 <= _standardPositions)
                                ? _buildPositionCard(
                                    i + 1,
                                    'Position ${i + 1}',
                                    Colors.indigo,
                                  )
                                : const SizedBox(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Optional MAB Slot
                  if (_includeMab) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 280,
                          height: 60,
                          child: _buildPositionCard(
                            -2,
                            'MAB (Middle at Back)',
                            Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
