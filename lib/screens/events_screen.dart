// lib/views/events_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_model.dart';

class EventsScreen extends StatefulWidget {
  final bool isLeaderOrAdmin;
  final String currentMemberId;

  const EventsScreen({
    super.key,
    required this.isLeaderOrAdmin,
    required this.currentMemberId,
  });

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events & Practices'),
        actions: [
          if (widget.isLeaderOrAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Create Event',
              onPressed: () => _showCreateEventDialog(context),
            ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase
            .from('events')
            .stream(primaryKey: ['id'])
            .order('event_date', ascending: true),
        builder: (context, snapshot) {
          // Robust Error Handling as per SRS V3 section 5
          if (snapshot.hasError) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.red.shade100,
                child: Text(
                  'Error loading events: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data!
              .map((data) => EventModel.fromMap(data))
              .toList();

          if (events.isEmpty) {
            return const Center(
              child: Text('No upcoming events or practices.'),
            );
          }

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildEventCard(event);
            },
          );
        },
      ),
    );
  }

  Widget _buildEventCard(EventModel event) {
    Color statusColor;
    switch (event.status) {
      case 'Go':
        statusColor = Colors.green;
        break;
      case 'No-go':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.orange;
    }

    final rowColor = switch (event.status) {
      'Go' => Colors.green.shade50,
      'No-go' => Colors.red.shade50,
      _ => Colors.yellow.shade50,
    };

    return _EventStatusCard(
      rowColor: rowColor,
      statusColor: statusColor,
      event: event,
      isLeaderOrAdmin: widget.isLeaderOrAdmin,
      onStatusChanged: (status) => _updateEventStatus(event.id, status),
      rsvpSectionBuilder: () => _buildRsvpSection(event.id),
      membersRsvpListBuilder: () => _buildMembersRsvpList(event.id),
    );
  }

  Widget _buildRsvpSection(String eventId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _supabase.from('event_rsvps').select().eq('event_id', eventId),
      builder: (context, snapshot) {
        String currentRsvp = 'Not Set';
        int attendingCount = 0;

        if (snapshot.hasData) {
          for (var item in snapshot.data!) {
            if (item['rsvp_status'] == 'Attending') attendingCount++;
            if (item['member_id'] == widget.currentMemberId) {
              currentRsvp = item['rsvp_status'];
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attending Count: $attendingCount',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Your RSVP: $currentRsvp',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _rsvpButton(eventId, 'Attending', Colors.green, currentRsvp),
                  _rsvpButton(eventId, 'Maybe', Colors.orange, currentRsvp),
                  _rsvpButton(
                    eventId,
                    'Not Attending',
                    Colors.red,
                    currentRsvp,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rsvpButton(
    String eventId,
    String status,
    Color color,
    String currentStatus,
  ) {
    final bool isSelected = currentStatus == status;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
      ),
      onPressed: () => _setRsvp(eventId, status),
      child: Text(status),
    );
  }

  // Append inside _EventsScreenState in lib/views/events_screen.dart

  /// Builds a list of all team members and their current RSVP status for a given event.
  Widget _buildMembersRsvpList(String eventId) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // Fetch all members from team_members
      stream: _supabase
          .from('team_members')
          .stream(primaryKey: ['id'])
          .order('full_name'),
      builder: (context, membersSnapshot) {
        if (!membersSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = membersSnapshot.data!;

        return StreamBuilder<List<Map<String, dynamic>>>(
          // Stream RSVPs for this specific event to support real-time UI updates
          stream: _supabase
              .from('event_rsvps')
              .stream(primaryKey: ['id'])
              .eq('event_id', eventId),
          builder: (context, rsvpSnapshot) {
            final rsvpMap = <String, String>{};
            if (rsvpSnapshot.hasData) {
              for (var rsvp in rsvpSnapshot.data!) {
                rsvpMap[rsvp['member_id'].toString()] = rsvp['rsvp_status']
                    .toString();
              }
            }

            return Container(
              margin: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: members.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final member = members[index];
                  final String memberId = member['id'].toString();
                  final String memberName =
                      member['full_name'] ?? 'Unknown Member';
                  final String currentStatus =
                      rsvpMap[memberId] ?? 'No Response';

                  return ListTile(
                    dense: true,
                    title: Text(
                      memberName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: widget.isLeaderOrAdmin
                        ? const Text(
                            'Tap a status to override response',
                            style: TextStyle(fontSize: 10),
                          )
                        : null,
                    trailing: widget.isLeaderOrAdmin
                        ? _buildLeaderRsvpSelector(
                            eventId,
                            memberId,
                            currentStatus,
                          )
                        : _buildMemberStatusBadge(currentStatus),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Admin/Leader control: ChoiceChips to set any member's attendance response
  Widget _buildLeaderRsvpSelector(
    String eventId,
    String memberId,
    String currentStatus,
  ) {
    final statuses = ['Attending', 'Maybe', 'Not Attending'];

    return Wrap(
      spacing: 4,
      children: statuses.map((status) {
        final bool isSelected = currentStatus == status;
        Color activeColor;
        switch (status) {
          case 'Attending':
            activeColor = Colors.green;
            break;
          case 'Maybe':
            activeColor = Colors.orange;
            break;
          default:
            activeColor = Colors.red;
        }

        return ChoiceChip(
          label: Text(
            status == 'Not Attending'
                ? 'No'
                : (status == 'Attending' ? 'Yes' : 'Maybe'),
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
          selected: isSelected,
          selectedColor: activeColor,
          visualDensity: VisualDensity.compact,
          onSelected: (_) async {
            await _supabase.from('event_rsvps').upsert({
              'event_id': eventId,
              'member_id': memberId,
              'rsvp_status': status,
              'updated_at': DateTime.now().toIso8601String(),
            }, onConflict: 'event_id,member_id');
            if (mounted) setState(() {});
          },
        );
      }).toList(),
    );
  }

  /// Read-only status chip for standard team members
  Widget _buildMemberStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Attending':
        color = Colors.green;
        break;
      case 'Maybe':
        color = Colors.orange;
        break;
      case 'Not Attending':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _setRsvp(String eventId, String status) async {
    await _supabase.from('event_rsvps').upsert({
      'event_id': eventId,
      'member_id': widget.currentMemberId,
      'rsvp_status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'event_id,member_id');
    setState(() {});
  }

  Future<void> _updateEventStatus(String eventId, String status) async {
    await _supabase.from('events').update({'status': status}).eq('id', eventId);
    setState(() {});
  }

  void _showCreateEventDialog(BuildContext context) {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    String type = 'Practice';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Event / Practice'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              DropdownButtonFormField<String>(
                initialValue: type,
                items: ['Practice', 'Booking']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => type = val ?? 'Practice',
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty) {
                final newEvent = EventModel(
                  id: '',
                  title: titleController.text,
                  eventType: type,
                  eventDate: selectedDate,
                  location: locationController.text,
                  status: 'Pending',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                await _supabase.from('events').insert({
                  'title': newEvent.title,
                  'event_type': newEvent.eventType,
                  'event_date': newEvent.eventDate.toIso8601String(),
                  'location': newEvent.location,
                  'status': newEvent.status,
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _EventStatusCard extends StatefulWidget {
  final Color rowColor;
  final Color statusColor;
  final EventModel event;
  final bool isLeaderOrAdmin;
  final ValueChanged<String> onStatusChanged;
  final Widget Function() rsvpSectionBuilder;
  final Widget Function() membersRsvpListBuilder;

  const _EventStatusCard({
    required this.rowColor,
    required this.statusColor,
    required this.event,
    required this.isLeaderOrAdmin,
    required this.onStatusChanged,
    required this.rsvpSectionBuilder,
    required this.membersRsvpListBuilder,
  });

  @override
  State<_EventStatusCard> createState() => _EventStatusCardState();
}

class _EventStatusCardState extends State<_EventStatusCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          Material(
            color: widget.rowColor,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(4),
              bottom: Radius.circular(_isExpanded ? 0 : 4),
            ),
            child: InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${event.eventType} • ${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year} ${event.eventDate.hour}:${event.eventDate.minute.toString().padLeft(2, '0')}',
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: widget.statusColor),
                      ),
                      child: Text(
                        event.status,
                        style: TextStyle(
                          color: widget.statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
          if (_isExpanded)
            Column(
              children: [
                if (event.location != null && event.location!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(event.location!),
                      ],
                    ),
                  ),
                const Divider(),
                widget.rsvpSectionBuilder(),
                widget.membersRsvpListBuilder(),
                if (widget.isLeaderOrAdmin ) 
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('Booking Status: '),
                        DropdownButton<String>(
                          value: event.status,
                          items: ['Pending', 'Go', 'No-go']
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                ),
                              )
                              .toList(),
                          onChanged: (status) {
                            if (status != null) widget.onStatusChanged(status);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
