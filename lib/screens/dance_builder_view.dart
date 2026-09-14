import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/competency.dart';
import '../models/event_model.dart';
import '../models/team_member.dart';
import '../services/team_repository.dart';

class DanceBuilderView extends StatefulWidget {
  final String currentMemberId;
  const DanceBuilderView({super.key, required this.currentMemberId});

  @override
  State<DanceBuilderView> createState() => _DanceBuilderViewState();
}

class _DanceBuilderViewState extends State<DanceBuilderView> {
  final TeamRepository _repository = TeamRepository();
  final SupabaseClient _supabase = Supabase.instance.client;

  List<EventModel> _events = [];
  List<Map<String, dynamic>> _dances = [];
  List<TeamMember> _members = [];
  List<Competency> _competencies = [];
  Map<int, String> _primaryByPosition = {};
  Set<String> _attendingIds = {};
  EventModel? _selectedEvent;
  String? _selectedDance;
  int _positionCount = 8;
  bool _includeMaf = false;
  bool _includeMab = false;
  bool _hidePastEvents = true;
  bool _isLoading = true;

  Map<String, dynamic>? get _dance {
    for (final item in _dances) {
      if (item['dance_name'] == _selectedDance) return item;
    }
    return null;
  }

  bool _isPastEvent(EventModel event) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final eventDate = DateTime(
      event.eventDate.year,
      event.eventDate.month,
      event.eventDate.day,
    );
    return eventDate.isBefore(todayOnly);
  }

  List<EventModel> get _visibleEvents => _hidePastEvents
      ? _events.where((event) => !_isPastEvent(event)).toList()
      : _events;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final dances = await _repository.fetchDanceCatalog();
      final members = await _repository.fetchTeamMembers();
      final eventResponse = await _supabase
          .from('events')
          .select()
          .order('event_date', ascending: true);
      final sortedDances = List<Map<String, dynamic>>.from(dances)
        ..sort(
          (left, right) => (left['dance_name'] as String)
              .toLowerCase()
              .compareTo((right['dance_name'] as String).toLowerCase()),
        );
      if (!mounted) return;
      setState(() {
        _dances = sortedDances;
        _members = members;
        _events = (eventResponse as List)
            .map((item) => EventModel.fromMap(item))
            .toList();
        _selectedDance ??= sortedDances.isEmpty
            ? null
            : sortedDances.first['dance_name'] as String;
        _selectedEvent ??= _firstAvailableEvent(_events);
      });
      await _refreshBookingData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load builder data: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  EventModel? _firstAvailableEvent(List<EventModel> events) {
    final upcomingEvents = events.where((event) => !_isPastEvent(event));
    if (upcomingEvents.isNotEmpty) return upcomingEvents.first;
    return events.isEmpty ? null : events.first;
  }

  Future<void> _setHidePastEvents(bool hidePastEvents) async {
    final visibleEvents = hidePastEvents
        ? _events.where((event) => !_isPastEvent(event)).toList()
        : _events;
    final selectedEvent = visibleEvents.contains(_selectedEvent)
        ? _selectedEvent
        : (visibleEvents.isEmpty ? null : visibleEvents.first);
    setState(() {
      _hidePastEvents = hidePastEvents;
      _selectedEvent = selectedEvent;
    });
    await _refreshBookingData();
  }

  Future<void> _refreshBookingData() async {
    final event = _selectedEvent;
    final dance = _selectedDance;
    if (event == null || dance == null) return;

    final rsvps = await _supabase
        .from('event_rsvps')
        .select('member_id, rsvp_status')
        .eq('event_id', event.id);
    final attending = (rsvps as List)
        .where((item) => item['rsvp_status'] == 'Attending')
        .map((item) => item['member_id'].toString())
        .toSet();
    final competencies = await _repository.fetchCompetenciesForDance(dance);
    final assignments = await _repository.fetchBookingPrimaryAssignments(
      bookingId: event.id,
      danceName: dance,
    );
    final settings = await _repository.fetchBookingDanceSettings(
      bookingId: event.id,
      danceName: dance,
    );

    if (!mounted) return;
    setState(() {
      _attendingIds = attending;
      _competencies = competencies;
      _primaryByPosition = {
        for (final item in assignments)
          item['position_number'] as int: item['member_id'].toString(),
      };
      _positionCount =
          settings?['standard_positions'] as int? ??
          (_dance?['standard_positions'] == 12 ? 12 : 8);
      _includeMaf = settings?['has_maf'] as bool? ?? _dance?['has_maf'] == true;
      _includeMab = settings?['has_mab'] as bool? ?? _dance?['has_mab'] == true;
    });
  }

  Future<void> _saveFormationSettings() async {
    final event = _selectedEvent;
    final dance = _selectedDance;
    if (event == null || dance == null) return;
    await _repository.saveBookingDanceSettings(
      bookingId: event.id,
      danceName: dance,
      standardPositions: _positionCount,
      hasMaf: _includeMaf,
      hasMab: _includeMab,
    );
  }

  Competency? _competency(String memberId, int position) {
    for (final item in _competencies) {
      if (item.memberId == memberId && item.positionNumber == position) {
        return item;
      }
    }
    return null;
  }

  List<TeamMember> _candidates(int position) {
    final candidates = _members.where((member) {
      if (member.isMusician || !_attendingIds.contains(member.id)) return false;
      final competency = _competency(member.id, position);
      return competency != null &&
          (competency.proficiencyLevel == 'YP' ||
              competency.proficiencyLevel == 'Y');
    }).toList();
    candidates.sort((left, right) => _compareCandidates(position, left, right));
    return candidates;
  }

  int _competentPositionCount(String memberId, String proficiencyLevel) {
    return _competencies
        .where(
          (competency) =>
              competency.memberId == memberId &&
              competency.proficiencyLevel == proficiencyLevel,
        )
        .map((competency) => competency.positionNumber)
        .toSet()
        .length;
  }

  int _compareCandidates(int position, TeamMember left, TeamMember right) {
    final primaryId = _primaryByPosition[position];
    if (left.id == primaryId) return -1;
    if (right.id == primaryId) return 1;

    final leftLevel = _competency(left.id, position)!.proficiencyLevel;
    final rightLevel = _competency(right.id, position)!.proficiencyLevel;
    if (leftLevel != rightLevel) return leftLevel == 'Y' ? -1 : 1;

    final countComparison = _competentPositionCount(
      left.id,
      leftLevel,
    ).compareTo(_competentPositionCount(right.id, leftLevel));
    if (countComparison != 0) return countComparison;
    return left.fullName.compareTo(right.fullName);
  }

  Color _competencyColor(String proficiencyLevel) {
    switch (proficiencyLevel) {
      case 'YP':
        return Colors.green.shade400;
      case 'Y':
        return Colors.purple.shade300;
      case 'L':
        return Colors.orange.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  List<TeamMember> _musicians() {
    return _members.where((member) {
      if (!member.isMusician || !_attendingIds.contains(member.id)) {
        return false;
      }
      return _competencies.any(
        (item) =>
            item.memberId == member.id &&
            item.positionNumber == 0 &&
            (item.proficiencyLevel == 'YP' || item.proficiencyLevel == 'Y'),
      );
    }).toList();
  }

  bool get _hasUnavailablePosition {
    final positions = <int>[
      if (_includeMaf) 99,
      for (var position = 1; position <= _positionCount; position++) position,
      if (_includeMab) 98,
    ];
    if (positions.any((position) => _candidates(position).isEmpty)) {
      return true;
    }

    // Check whether every active position can receive a different dancer.
    // This catches cases where one qualified dancer appears in every position.
    final assignedDancerByPosition = <int, String>{};
    final positionsByCandidateCount = [...positions]
      ..sort(
        (left, right) =>
            _candidates(left).length.compareTo(_candidates(right).length),
      );

    bool canAssign(int index) {
      if (index == positionsByCandidateCount.length) return true;
      final position = positionsByCandidateCount[index];
      for (final dancer in _candidates(position)) {
        if (assignedDancerByPosition.containsValue(dancer.id)) continue;
        assignedDancerByPosition[position] = dancer.id;
        if (canAssign(index + 1)) return true;
        assignedDancerByPosition.remove(position);
      }
      return false;
    }

    return !canAssign(0);
  }

  Future<void> _showPositionDialog(int position, String label) async {
    final candidates = _candidates(position);
    final primaryId = _primaryByPosition[position];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: double.maxFinite,
          child: candidates.isEmpty
              ? const Text(
                  'No attending qualified or master dancers are available.',
                )
              : ListView(
                  shrinkWrap: true,
                  children: candidates.map((member) {
                    final competency = _competency(member.id, position)!;
                    final isPrimary = member.id == primaryId;
                    return ListTile(
                      title: Text(
                        member.fullName,
                        style: TextStyle(
                          fontWeight: isPrimary
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _competencyColor(competency.proficiencyLevel),
                        ),
                      ),
                      subtitle: Text(competency.proficiencyLevel),
                      trailing: isPrimary
                          ? const Icon(Icons.star, color: Colors.amber)
                          : null,
                      onTap: () async {
                        final existingPosition = _primaryByPosition.entries
                            .where(
                              (entry) =>
                                  entry.value == member.id &&
                                  entry.key != position,
                            )
                            .map((entry) => entry.key)
                            .firstOrNull;
                        if (existingPosition != null) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${member.fullName} is already primary at position $existingPosition. Clear that primary before assigning this position.',
                                ),
                              ),
                            );
                          }
                          return;
                        }
                        await _repository.assignPrimaryForBookingPosition(
                          bookingId: _selectedEvent!.id,
                          danceName: _selectedDance!,
                          positionNumber: position,
                          memberId: member.id,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        await _refreshBookingData();
                      },
                    );
                  }).toList(),
                ),
        ),
        actions: [
          if (primaryId != null)
            TextButton(
              onPressed: () async {
                await _repository.clearPrimaryForBookingPosition(
                  bookingId: _selectedEvent!.id,
                  danceName: _selectedDance!,
                  positionNumber: position,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _refreshBookingData();
              },
              child: const Text('Clear primary'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMusicianDialog() async {
    final musicians = _musicians();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Attending musicians'),
        content: SizedBox(
          width: double.maxFinite,
          child: musicians.isEmpty
              ? const Text(
                  'No attending musicians have a competency for this dance.',
                )
              : ListView(
                  shrinkWrap: true,
                  children: musicians.map((member) {
                    final competency = _competencies.firstWhere(
                      (item) =>
                          item.memberId == member.id &&
                          item.positionNumber == 0,
                    );
                    return ListTile(
                      title: Text(member.fullName),
                      subtitle: Text(
                        '${member.instruments ?? 'Musician'} - ${competency.proficiencyLevel}',
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _positionCard(int position, String label) {
    final candidates = _candidates(position);
    final primaryId = _primaryByPosition[position];
    final primary = candidates
        .where((member) => member.id == primaryId)
        .firstOrNull;
    final unavailable = candidates.isEmpty;

    return Card(
      color: unavailable ? Colors.red.shade50 : null,
      child: InkWell(
        onTap: () => _showPositionDialog(position, label),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: unavailable ? Colors.red : Colors.indigo,
                child: Text(
                  '$position',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    if (primary != null)
                      Text(
                        primary.fullName,
                        style: TextStyle(
                          color: _competencyColor(
                            _competency(primary.id, position)!.proficiencyLevel,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    for (final member in candidates.where(
                      (item) => item.id != primaryId,
                    ))
                      Text(
                        member.fullName,
                        style: TextStyle(
                          color: _competencyColor(
                            _competency(member.id, position)!.proficiencyLevel,
                          ),
                        ),
                      ),
                    if (unavailable)
                      Text(
                        'No qualified attending dancer',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.touch_app, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositionGrid() {
    final rows = <Widget>[];
    for (var position = 1; position <= _positionCount; position += 2) {
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _positionCard(position, 'Position $position')),
              const SizedBox(width: 8),
              Expanded(
                child: position + 1 <= _positionCount
                    ? _positionCard(position + 1, 'Position ${position + 1}')
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      );
      rows.add(const SizedBox(height: 8));
    }

    return Column(children: rows);
  }

  Widget _buildSpecialPositionCard(int position, String label) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: _positionCard(position, label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Padding(
      padding: EdgeInsets.all(compact ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dance Builder & Lineup Selector',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const Text('Hide past events'),
              Switch(value: _hidePastEvents, onChanged: _setHidePastEvents),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<EventModel>(
                    initialValue: _visibleEvents.contains(_selectedEvent)
                        ? _selectedEvent
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Event',
                      border: OutlineInputBorder(),
                    ),
                    items: _visibleEvents
                        .map(
                          (event) => DropdownMenuItem(
                            value: event,
                            child: Text(
                              '${event.title} - ${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (event) async {
                      if (event == null) return;
                      setState(() => _selectedEvent = event);
                      await _refreshBookingData();
                    },
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDance,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Dance',
                      border: OutlineInputBorder(),
                    ),
                    items: _dances
                        .map(
                          (dance) => DropdownMenuItem(
                            value: dance['dance_name'] as String,
                            child: Text(dance['dance_name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (dance) async {
                      if (dance == null) return;
                      setState(() => _selectedDance = dance);
                      await _refreshBookingData();
                    },
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      const Text('Positions'),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 8, label: Text('8')),
                          ButtonSegment(value: 12, label: Text('12')),
                        ],
                        selected: {_positionCount},
                        onSelectionChanged: (value) {
                          setState(() => _positionCount = value.first);
                          _saveFormationSettings();
                        },
                      ),
                      Switch(
                        value: _includeMaf,
                        onChanged: (value) {
                          setState(() => _includeMaf = value);
                          _saveFormationSettings();
                        },
                      ),
                      const Text('MAF'),
                      Switch(
                        value: _includeMab,
                        onChanged: (value) {
                          setState(() => _includeMab = value);
                          _saveFormationSettings();
                        },
                      ),
                      const Text('MAB'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: [
                if (_hasUnavailablePosition)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.shade100,
                    child: Text(
                      'There are not enough dancers to perform this dance',
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.music_note)),
                    title: const Text('Musicians'),
                    subtitle: Text(
                      '${_musicians().length} attending qualified musicians',
                    ),
                    onTap: _showMusicianDialog,
                  ),
                ),
                if (_includeMaf) _buildSpecialPositionCard(99, 'MAF'),
                _buildPositionGrid(),
                if (_includeMab) _buildSpecialPositionCard(98, 'MAB'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
