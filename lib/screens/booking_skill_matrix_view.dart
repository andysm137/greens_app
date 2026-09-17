// lib/screens/booking_skill_matrix_view.dart
//
// Skill-matrix-style view scoped to a single booking: pick a future event and
// a dance, see only the attendees, and tap a qualified chip to make that
// dancer primary for the position at that booking. Reads/writes the same
// booking_dance_assignments / booking_dance_settings rows as Dance Builder so
// the two views stay in sync.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/competency.dart';
import '../models/event_model.dart';
import '../models/team_member.dart';
import '../services/team_repository.dart';

class BookingSkillMatrixView extends StatefulWidget {
  const BookingSkillMatrixView({super.key});

  @override
  State<BookingSkillMatrixView> createState() =>
      _BookingSkillMatrixViewState();
}

class _BookingSkillMatrixViewState extends State<BookingSkillMatrixView> {
  final TeamRepository _repository = TeamRepository();
  final SupabaseClient _supabase = Supabase.instance.client;

  static const int musicianPosition = 0;
  static const int mabPosition = 98;
  static const int mafPosition = 99;

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
  bool _isLoading = true;

  // Keeps the frozen header's horizontal scroll in step with the body.
  final ScrollController _headerHScroll = ScrollController();
  final ScrollController _bodyHScroll = ScrollController();
  bool _syncingHScroll = false;

  Map<String, dynamic>? get _dance {
    for (final item in _dances) {
      if (item['dance_name'] == _selectedDance) return item;
    }
    return null;
  }

  bool _isFutureEvent(EventModel event) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final eventDate = DateTime(
      event.eventDate.year,
      event.eventDate.month,
      event.eventDate.day,
    );
    return !eventDate.isBefore(todayOnly);
  }

  List<EventModel> get _futureEvents => _events.where(_isFutureEvent).toList();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _headerHScroll.addListener(() => _syncHScroll(_headerHScroll, _bodyHScroll));
    _bodyHScroll.addListener(() => _syncHScroll(_bodyHScroll, _headerHScroll));
  }

  @override
  void dispose() {
    _headerHScroll.dispose();
    _bodyHScroll.dispose();
    super.dispose();
  }

  void _syncHScroll(ScrollController from, ScrollController to) {
    if (_syncingHScroll || !to.hasClients) return;
    _syncingHScroll = true;
    to.jumpTo(from.offset);
    _syncingHScroll = false;
  }

  int _compareDancersFirst(TeamMember left, TeamMember right) {
    if (left.isMusician != right.isMusician) {
      return left.isMusician ? 1 : -1;
    }
    return left.fullName.toLowerCase().compareTo(right.fullName.toLowerCase());
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
      final sortedMembers = List<TeamMember>.from(members)
        ..sort(_compareDancersFirst);
      final events = (eventResponse as List)
          .map((item) => EventModel.fromMap(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _dances = sortedDances;
        _members = sortedMembers;
        _events = events;
        _selectedDance ??= sortedDances.isEmpty
            ? null
            : sortedDances.first['dance_name'] as String;
        _selectedEvent ??= _futureEvents.isEmpty ? null : _futureEvents.first;
      });
      await _refreshBookingData();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load booking matrix: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  /// Practice events also count Learners ('L') as qualified; Booking events
  /// require the usual Yes/Yes-Provisional levels.
  bool _isQualifiedLevel(String? level) {
    if (level == 'YP' || level == 'Y') return true;
    if (_selectedEvent?.eventType == 'Practice' && level == 'L') return true;
    return false;
  }

  Color _getBadgeColor(String level) {
    switch (level) {
      case 'L':
        return Colors.orange.shade300;
      case 'YP':
        return Colors.purple.shade300;
      case 'Y':
        return Colors.green.shade400;
      default:
        return Colors.grey.shade300;
    }
  }

  /// A member may only be primary once per booking/dance (DB-enforced), so
  /// assigning them elsewhere first clears their previous position.
  Future<void> _togglePrimary(String memberId, int position) async {
    final event = _selectedEvent;
    final dance = _selectedDance;
    if (event == null || dance == null) return;

    if (_primaryByPosition[position] == memberId) {
      await _repository.clearPrimaryForBookingPosition(
        bookingId: event.id,
        danceName: dance,
        positionNumber: position,
      );
      await _refreshBookingData();
      return;
    }

    final existingPosition = _primaryByPosition.entries
        .where((entry) => entry.value == memberId && entry.key != position)
        .map((entry) => entry.key)
        .firstOrNull;
    if (existingPosition != null) {
      await _repository.clearPrimaryForBookingPosition(
        bookingId: event.id,
        danceName: dance,
        positionNumber: existingPosition,
      );
    }

    await _repository.assignPrimaryForBookingPosition(
      bookingId: event.id,
      danceName: dance,
      positionNumber: position,
      memberId: memberId,
    );
    await _refreshBookingData();
    await _applyAutoFormationRules(position);
  }

  /// Assigning a primary at MAF/MAB turns that flag on; filling all of
  /// positions 9-12 turns on the 12-position formation. Both are saved
  /// immediately so Dance Builder reflects the same booking settings.
  Future<void> _applyAutoFormationRules(int changedPosition) async {
    var changed = false;
    setState(() {
      if (changedPosition == mafPosition && !_includeMaf) {
        _includeMaf = true;
        changed = true;
      }
      if (changedPosition == mabPosition && !_includeMab) {
        _includeMab = true;
        changed = true;
      }
      if ([9, 10, 11, 12].contains(changedPosition) &&
          _positionCount != 12 &&
          [
            9,
            10,
            11,
            12,
          ].every((position) => _primaryByPosition.containsKey(position))) {
        _positionCount = 12;
        changed = true;
      }
    });
    if (changed) await _saveFormationSettings();
  }

  DataCell _buildInfoCell(String memberId, int position) {
    final level = _competency(memberId, position)?.proficiencyLevel ?? '-';
    final scale = _matrixScale;
    return DataCell(
      Container(
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: 10 * scale, vertical: 6 * scale),
        decoration: BoxDecoration(
          color: _getBadgeColor(level),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          level,
          style: TextStyle(
            color: level == '-' ? Colors.black54 : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12 * scale,
          ),
        ),
      ),
    );
  }

  DataCell _buildAssignableCell(String memberId, int position) {
    final level = _competency(memberId, position)?.proficiencyLevel ?? '-';
    final isQualified = _isQualifiedLevel(level);
    final isPrimary = _primaryByPosition[position] == memberId;
    final scale = _matrixScale;


    return DataCell(
      InkWell(
        onTap: isQualified ? () => _togglePrimary(memberId, position) : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 43 * scale,
        child: Center(
            child: Container(
            height: 36 * scale,
            width: 36 * scale,
              alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 4 * scale),
              decoration: BoxDecoration(
                color: _getBadgeColor(level),
                borderRadius: BorderRadius.circular(8),
                border: isPrimary
                    ? Border.all(color: Colors.red, width: 3.75)
                    : null,
              ),
              child: Text(
                level,
                style: TextStyle(
                  color: level == '-' ? Colors.black54 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12 * scale,
                ),
              ),

            ),
          ),
        ),
      ),
    );
  }

  DataCell _buildDisabledCell() {
    return const DataCell(
      Center(child: Text('-', style: TextStyle(color: Colors.grey))),
    );
  }

  Widget _positionHeaderLabel(String label, int position) {
    final hasPrimary = _primaryByPosition.containsKey(position);
    final scale = _matrixScale;
    return Container(
      padding: hasPrimary
          ? EdgeInsets.symmetric(horizontal: 2 * scale, vertical: 2 * scale)
          : null,
      decoration: hasPrimary
          ? BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(2),
            )
          : null,
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 * scale),
      ),
    );
  }

  List<TeamMember> _candidates(int position) {
    return _members.where((member) {
      if (member.isMusician || !_attendingIds.contains(member.id)) {
        return false;
      }
      final level = _competency(member.id, position)?.proficiencyLevel;
      return _isQualifiedLevel(level);
    }).toList();
  }

  bool get _hasUnavailablePosition {
    final positions = <int>[
      if (_includeMaf) mafPosition,
      for (var position = 1; position <= _positionCount; position++) position,
      if (_includeMab) mabPosition,
    ];
    if (positions.any((position) => _candidates(position).isEmpty)) {
      return true;
    }

    // Check whether every active position can receive a different dancer.
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

  static const double _memberColWidth = 160;
  static const double _cellColWidth = 52;
  static const double _musicianColWidth = 70;

  double get _matrixScale {
    final size = MediaQuery.sizeOf(context);
    if (size.width >= 700) return 1;
    final minimum = size.width > size.height ? 0.78 : 0.68;
    return (size.width / 700).clamp(minimum, 1);
  }

  Widget _fixedCell(double width, Widget child, {bool alignLeft = false}) {
    final scale = _matrixScale;
    return SizedBox(
      width: width * scale,
      height: 43 * scale,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 3 * scale),
        child: Align(
          alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
          child: child,
        ),
      ),
    );
  }

  Widget _buildMatrixTable() {
    if (_selectedEvent == null) {
      return const Center(child: Text('No future events available.'));
    }
    if (_selectedDance == null) {
      return const Center(child: Text('No dance selected.'));
    }

    final attendingMembers = _members
        .where((member) => _attendingIds.contains(member.id))
        .toList();

    if (attendingMembers.isEmpty) {
      return const Center(
        child: Text('No attendees recorded for this event yet.'),
      );
    }

    final useCompactHeaders = _matrixScale < 1;
    final headerRow = Row(
      children: [
        _fixedCell(
          _memberColWidth,
          const Text(
            'Team Member',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          alignLeft: true,
        ),
        ...List.generate(
          _positionCount,
          (i) => _fixedCell(
            _cellColWidth,
            _positionHeaderLabel(useCompactHeaders ? '${i + 1}' : 'Pos ${i + 1}', i + 1),
          ),
        ),
        _fixedCell(_cellColWidth, _positionHeaderLabel('MAF', mafPosition)),
        _fixedCell(_cellColWidth, _positionHeaderLabel('MAB', mabPosition)),
        _fixedCell(
          _musicianColWidth,
          const Text(
            'Musician',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );

    return Column(
      children: [
        // Frozen header: scrolls horizontally in step with the body, never vertically.
        SingleChildScrollView(
          controller: _headerHScroll,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: headerRow,
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              controller: _bodyHScroll,
              scrollDirection: Axis.horizontal,
              child: Column(
                children: attendingMembers.map((member) {
                  final isMusician = member.isMusician;
                  return Row(
                    children: [
                      _fixedCell(
                        _memberColWidth,
                        Text(
                          member.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        alignLeft: true,
                      ),
                      ...List.generate(
                        _positionCount,
                        (i) => _fixedCell(
                          _cellColWidth,
                          (isMusician
                                  ? _buildDisabledCell()
                                  : _buildAssignableCell(member.id, i + 1))
                              .child,
                        ),
                      ),
                      _fixedCell(
                        _cellColWidth,
                        (!isMusician && _includeMaf
                                ? _buildAssignableCell(member.id, mafPosition)
                                : _buildDisabledCell())
                            .child,
                      ),
                      _fixedCell(
                        _cellColWidth,
                        (!isMusician && _includeMab
                                ? _buildAssignableCell(member.id, mabPosition)
                                : _buildDisabledCell())
                            .child,
                      ),
                      _fixedCell(
                        _musicianColWidth,
                        (isMusician
                                ? _buildInfoCell(member.id, musicianPosition)
                                : _buildDisabledCell())
                            .child,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
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
          const Text(
            'Booking Skill Matrix',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<EventModel>(
                    initialValue: _futureEvents.contains(_selectedEvent)
                        ? _selectedEvent
                        : null,
                    isExpanded: true,
                    itemHeight: 48,
                    decoration: InputDecoration(
                      labelText: 'Event',
                      border: const OutlineInputBorder(),
                      isDense: compact,
                      contentPadding: compact
                          ? const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            )
                          : null,
                    ),
                    items: _futureEvents
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDance,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Dance',
                      border: const OutlineInputBorder(),
                      isDense: compact,
                      contentPadding: compact
                          ? const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            )
                          : null,
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
                    spacing: 4,
                    children: [
                      const Text('Positions'),
                      SegmentedButton<int>(
                        style: const ButtonStyle(
                          visualDensity: VisualDensity(
                            horizontal: -4,
                            vertical: -4,
                          ),
                          padding: WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 6),
                          ),
                        ),
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
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        value: _includeMaf,
                        onChanged: (value) {
                          setState(() => _includeMaf = value);
                          _saveFormationSettings();
                        },
                      ),
                      const Text('MAF'),
                      Switch(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
          Expanded(child: _buildMatrixTable()),
        ],
      ),
    );
  }
}
