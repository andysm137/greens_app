import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_model.dart';

class SetSheetView extends StatefulWidget {
  const SetSheetView({super.key});

  @override
  State<SetSheetView> createState() => _SetSheetViewState();
}

class _SetSheetViewState extends State<SetSheetView> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<EventModel> _bookings = [];
  EventModel? _selectedBooking;
  Map<String, dynamic>? _sheet;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    try {
      final response = await _supabase
          .from('events')
          .select()
          .order('event_date', ascending: true);
      final bookings = (response as List)
          .map((item) => EventModel.fromMap(item))
          .toList();
      if (!mounted) return;
      setState(() {
        _bookings = bookings;
        _selectedBooking ??= bookings.isEmpty ? null : bookings.first;
      });
      await _loadSheet();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSheet() async {
    final booking = _selectedBooking;
    if (booking == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _supabase
            .from('booking_dance_assignments')
            .select('dance_name, position_number, member_id, is_primary')
            .eq('booking_id', booking.id),
        _supabase
            .from('booking_dance_settings')
            .select('dance_name, standard_positions, has_maf, has_mab')
            .eq('booking_id', booking.id),
        _supabase
            .from('event_rsvps')
            .select('member_id, rsvp_status')
            .eq('event_id', booking.id),
        _supabase.from('team_members').select('id, full_name, instruments'),
        _supabase.from('musician_profiles').select('member_id, primary_instrument, is_qualified'),
        _supabase.from('competencies').select('member_id, dance_name, position_number, proficiency_level'),
        _supabase.from('dance_catalog').select('dance_name, standard_positions, has_maf, has_mab'),
      ]);

      final assignments = List<Map<String, dynamic>>.from(results[0] as List);
      final settings = List<Map<String, dynamic>>.from(results[1] as List);
      final rsvps = List<Map<String, dynamic>>.from(results[2] as List);
      final members = List<Map<String, dynamic>>.from(results[3] as List);
      final musicianProfiles = List<Map<String, dynamic>>.from(results[4] as List);
      final competencies = List<Map<String, dynamic>>.from(results[5] as List);
      final danceCatalog = List<Map<String, dynamic>>.from(results[6] as List);

      final memberNames = <String, String>{
        for (final member in members)
          member['id'].toString(): member['full_name'].toString(),
      };
      final attendingIds = rsvps
          .where((rsvp) => rsvp['rsvp_status'] == 'Attending')
          .map((rsvp) => rsvp['member_id'].toString())
          .toSet();
      final musicianIds = musicianProfiles
          .where((profile) => profile['is_qualified'] != false && attendingIds.contains(profile['member_id'].toString()))
          .map((profile) => profile['member_id'].toString())
          .toSet();

      final danceNames = <String>{
        ...assignments.map((item) => item['dance_name'].toString()),
        ...settings.map((item) => item['dance_name'].toString()),
      }.toList()..sort();

      final byDance = <String, Map<String, dynamic>>{};
      for (final dance in danceNames) {
        final danceAssignments = assignments
            .where((item) => item['dance_name'] == dance)
            .toList();
        final danceSettings = settings.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['dance_name'] == dance,
          orElse: () => null,
        );
        final positions = <int, List<String>>{};
        for (final assignment in danceAssignments) {
          final position = assignment['position_number'] as int;
          positions.putIfAbsent(position, () => []).add(
                memberNames[assignment['member_id'].toString()] ?? 'Unknown member',
              );
        }
        final catalog = danceCatalog.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['dance_name'] == dance,
          orElse: () => null,
        );
        final positionCount = danceSettings?['standard_positions'] as int? ??
            catalog?['standard_positions'] as int? ?? 8;
        final hasMaf = danceSettings?['has_maf'] == true || catalog?['has_maf'] == true;
        final hasMab = danceSettings?['has_mab'] == true || catalog?['has_mab'] == true;
        final primaryIds = <int, String>{
          for (final assignment in danceAssignments)
            assignment['position_number'] as int: assignment['member_id'].toString(),
        };
        final primaryNames = <int, String>{
          for (final entry in primaryIds.entries)
            entry.key: memberNames[entry.value] ?? 'Unknown member',
        };
        final candidates = <int, List<String>>{};
        final candidateIds = <int, List<String>>{};
        final positionsToCheck = <int>[
          for (var position = 1; position <= positionCount; position++) position,
          if (hasMaf) 99,
          if (hasMab) 98,
        ];
        for (final position in positionsToCheck) {
          final viableIds = competencies
              .where((item) =>
                  item['dance_name'] == dance &&
                  item['position_number'] == position &&
                  ['L', 'Q', 'M'].contains(item['proficiency_level']) &&
                  attendingIds.contains(item['member_id'].toString()))
              .map((item) => item['member_id'].toString());
          final ids = viableIds.toList();
          candidateIds[position] = ids;
          candidates[position] = ids
              .map((id) => memberNames[id] ?? 'Unknown member')
              .toList();
        }
        final activePositions = <int>[
          if (hasMaf) 99,
          for (var position = 1; position <= positionCount; position++) position,
          if (hasMab) 98,
        ];
        final compliant = _hasUniqueCoverage(candidateIds, activePositions);
        byDance[dance] = {
          'settings': danceSettings,
          'positions': positions,
          'candidates': candidates,
          'primaryIds': primaryIds,
          'primaryNames': primaryNames,
          'positionCount': positionCount,
          'hasMaf': hasMaf,
          'hasMab': hasMab,
          'compliant': compliant,
        };
      }

      final musicians = members
          .where((member) => musicianIds.contains(member['id'].toString()))
          .map((member) => member['full_name'].toString())
          .toList()
        ..sort();
        final attendingDancers = members
          .where((member) =>
            attendingIds.contains(member['id'].toString()) &&
            !musicianIds.contains(member['id'].toString()))
          .map((member) => member['full_name'].toString())
          .toList()
        ..sort();

      if (!mounted) return;
      setState(() {
        _sheet = {
          'dances': byDance,
          'musicians': musicians,
          'attendingDancers': attendingDancers,
          'musicianInstruments': musicianProfiles
            .where((profile) => musicianIds.contains(profile['member_id'].toString()))
            .map((profile) => '${memberNames[profile['member_id'].toString()] ?? 'Unknown'} (${profile['primary_instrument']})')
            .toList(),
          'attendingCount': attendingIds.length,
        };
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _printSheet() => html.window.print();

  bool _hasUniqueCoverage(
    Map<int, List<String>> candidateIds,
    List<int> positions,
  ) {
    final assigned = <int, String>{};
    final orderedPositions = [...positions]
      ..sort(
        (left, right) =>
            (candidateIds[left]?.length ?? 0).compareTo(candidateIds[right]?.length ?? 0),
      );

    bool canAssign(int index) {
      if (index == orderedPositions.length) return true;
      final position = orderedPositions[index];
      for (final memberId in candidateIds[position] ?? const <String>[]) {
        if (assigned.containsValue(memberId)) continue;
        assigned[position] = memberId;
        if (canAssign(index + 1)) return true;
        assigned.remove(position);
      }
      return false;
    }

    return canAssign(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _sheet == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _sheet == null) {
      return Center(child: Text('Unable to load set sheet: $_error'));
    }

    final booking = _selectedBooking;
    final dances = (_sheet?['dances'] as Map<String, dynamic>?) ?? {};
    final musicians = List<String>.from((_sheet?['musicians'] as List?) ?? const []);
    final musicianInstruments = List<String>.from(
      (_sheet?['musicianInstruments'] as List?) ?? const [],
    );
    final attendingDancers = List<String>.from(
      (_sheet?['attendingDancers'] as List?) ?? const [],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Sheet'),
        actions: [
          IconButton(
            tooltip: 'Print or save as PDF',
            icon: const Icon(Icons.print),
            onPressed: booking == null ? null : _printSheet,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<EventModel>(
            initialValue: booking,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Booking',
              border: OutlineInputBorder(),
            ),
            items: _bookings
                .map(
                  (event) => DropdownMenuItem(
                    value: event,
                    child: Text('${event.title} - ${_formatDate(event.eventDate)}'),
                  ),
                )
                .toList(),
            onChanged: (event) async {
              if (event == null) return;
              setState(() => _selectedBooking = event);
              await _loadSheet();
            },
          ),
          if (booking != null) ...[
            const SizedBox(height: 16),
            _buildBookingHeader(
              booking,
              attendingDancers,
              musicianInstruments.isEmpty ? musicians : musicianInstruments,
            ),
            const SizedBox(height: 16),
            if (dances.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No dances have been configured for this booking yet.'),
                ),
              ),
            ...dances.entries.map((entry) => _buildDanceBlock(entry.key, entry.value as Map<String, dynamic>)),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingHeader(
    EventModel booking,
    List<String> attendingDancers,
    List<String> musicians,
  ) {
    return Card(
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(booking.title, style: Theme.of(context).textTheme.headlineSmall),
            Text('${booking.eventType} • ${_formatDate(booking.eventDate)}'),
            if (booking.location?.isNotEmpty == true) Text(booking.location!),
            const Divider(),
            Text('Attending members: ${_sheet?['attendingCount'] ?? 0}'),
            const SizedBox(height: 8),
            Text('Attending dancers', style: Theme.of(context).textTheme.titleMedium),
            Text(attendingDancers.isEmpty ? 'No attending dancers recorded.' : attendingDancers.join(', ')),
            const SizedBox(height: 8),
            Text('Musicians', style: Theme.of(context).textTheme.titleMedium),
            Text(musicians.isEmpty ? 'No qualified attending musicians recorded.' : musicians.join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _buildDanceBlock(String danceName, Map<String, dynamic> data) {
    final positions = Map<int, List<String>>.from(data['positions'] as Map);
    final candidates = Map<int, List<String>>.from(data['candidates'] as Map);
    final primaryNames = Map<int, String>.from(data['primaryNames'] as Map);
    final positionCount = data['positionCount'] as int? ?? 8;
    final hasMaf = data['hasMaf'] == true;
    final hasMab = data['hasMab'] == true;
    final compliant = data['compliant'] == true;

    final positionRows = <Widget>[];
    for (var position = 1; position <= positionCount; position++) {
      positionRows.add(_buildPositionRow(
        position,
        positions[position] ?? const [],
        candidates: candidates[position] ?? const [],
        primaryId: primaryNames[position],
      ));
    }

    return Card(
      color: compliant ? null : Colors.grey.shade300,
      surfaceTintColor: compliant ? null : Colors.grey.shade300,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              danceName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: compliant ? null : Colors.grey.shade700,
                  ),
            ),
            if (hasMaf) Center(child: _buildPositionRow(99, positions[99] ?? const [], label: 'MAF', width: 280)),
            _buildPositionGrid(positionRows),
            if (hasMab) Center(child: _buildPositionRow(98, positions[98] ?? const [], label: 'MAB', width: 280)),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionGrid(List<Widget> rows) {
    final paired = <Widget>[];
    for (var index = 0; index < rows.length; index += 2) {
      paired.add(Row(children: [
        Expanded(child: rows[index]),
        const SizedBox(width: 8),
        Expanded(child: index + 1 < rows.length ? rows[index + 1] : const SizedBox()),
      ]));
    }
    return Column(children: paired);
  }

  Widget _buildPositionRow(
    int position,
    List<String> names, {
    List<String> candidates = const [],
    String? primaryId,
    String? label,
    double? width,
  }) {
    final displayNames = <String>{...candidates, ...names}.toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text(label ?? '$position', style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(
            width: width,
            child: displayNames.isEmpty
                ? const Text('Unassigned')
                : Wrap(
                    spacing: 6,
                    children: displayNames.map((name) => Text(
                      name,
                      style: TextStyle(fontWeight: name == primaryId || (primaryId == null && names.contains(name)) ? FontWeight.bold : FontWeight.normal),
                    )).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
