// lib/views/events_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/event_model.dart';

class EventsScreen extends StatefulWidget {
  final bool isLeaderOrAdmin;
  final bool isAdmin;
  final String currentMemberId;
  final String? initialEventId;

  const EventsScreen({
    super.key,
    required this.isLeaderOrAdmin,
    required this.isAdmin,
    required this.currentMemberId,
    this.initialEventId,
  });

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _hidePastEvents = true;
  String? _eventToExpandId;

  @override
  void initState() {
    super.initState();
    _eventToExpandId = widget.initialEventId;
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEventId != oldWidget.initialEventId) {
      _eventToExpandId = widget.initialEventId;
    }
  }

  Future<void> _dispatchNotification(
    String notificationType,
    String eventId, {
    String? changeDescription,
    String? memberId,
    String? oldStatus,
    String? newStatus,
  }) async {
    try {
      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'notification_type': notificationType,
          'event_id': eventId,
          if (changeDescription != null)
            'change_description': changeDescription,
          if (memberId != null) 'member_id': memberId,
          if (oldStatus != null) 'old_status': oldStatus,
          if (newStatus != null) 'new_status': newStatus,
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notification dispatch failed: $error')),
        );
      }
    }
  }

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
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _supabase
                  .from('events')
                  .select()
                  .order('event_date', ascending: true),
              builder: (context, fallbackSnapshot) {
                if (fallbackSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load events. Please refresh and try again.',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  );
                }
                if (!fallbackSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final events = fallbackSnapshot.data!
                    .map((data) => EventModel.fromMap(data))
                    .toList();
                return _buildEventsView(events);
              },
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

          return _buildEventsView(events);
        },
      ),
    );
  }

  Widget _buildEventsView(List<EventModel> events) {
    if (events.isEmpty) {
      return const Center(child: Text('No upcoming events or practices.'));
    }

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final visibleEvents = _hidePastEvents
        ? events
              .where(
                (event) => !DateTime(
                  event.eventDate.year,
                  event.eventDate.month,
                  event.eventDate.day,
                ).isBefore(todayOnly),
              )
              .toList()
        : events;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Hide past events'),
              Switch(
                value: _hidePastEvents,
                onChanged: (value) => setState(() => _hidePastEvents = value),
              ),
            ],
          ),
        ),
        Expanded(
          child: visibleEvents.isEmpty
              ? Center(
                  child: Text(
                    _hidePastEvents
                        ? 'No upcoming events or practices.'
                        : 'No events or practices found.',
                  ),
                )
              : ListView.builder(
                  itemCount: visibleEvents.length,
                  itemBuilder: (context, index) => _buildEventCard(
                    visibleEvents[index],
                    autoExpand: visibleEvents[index].id == _eventToExpandId,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEventCard(EventModel event, {bool autoExpand = false}) {
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
      isAdmin: widget.isAdmin,
      onStatusChanged: (status) => _updateEventStatus(event.id, status),
      onDeleteEvent: () => _deleteEvent(event),
      rsvpSectionBuilder: () => _buildRsvpSection(event),
      membersRsvpListBuilder: () => _buildMembersRsvpList(event),
      initialExpanded: autoExpand,
    );
  }

  Widget _buildRsvpSection(EventModel event) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _supabase.from('event_rsvps').select().eq('event_id', event.id),
        _supabase.from('musician_profiles').select('member_id'),
      ]),
      builder: (context, snapshot) {
        String currentRsvp = 'Not Set';
        int attendingCount = 0;
        int attendingDancers = 0;
        int attendingMusicians = 0;

        if (snapshot.hasData) {
          final rsvps = List<Map<String, dynamic>>.from(
            snapshot.data![0] as List,
          );
          final musicianIds = (snapshot.data![1] as List)
              .map((item) => item['member_id'].toString())
              .toSet();
          final attendingIds = <String>{};
          for (var item in rsvps) {
            if (item['rsvp_status'] == 'Attending') attendingCount++;
            if (item['rsvp_status'] == 'Attending') {
              attendingIds.add(item['member_id'].toString());
            }
            if (item['member_id'] == widget.currentMemberId) {
              currentRsvp = item['rsvp_status'];
            }
          }
          attendingMusicians = attendingIds.intersection(musicianIds).length;
          attendingDancers = attendingCount - attendingMusicians;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.isLeaderOrAdmin)
                    Text(
                      'Dancers: $attendingDancers  Musicians: $attendingMusicians',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    )
                  else
                    const SizedBox.shrink(),
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
                  _rsvpButton(event, 'Attending', Colors.green, currentRsvp),
                  _rsvpButton(event, 'Maybe', Colors.orange, currentRsvp),
                  _rsvpButton(event, 'Not Attending', Colors.red, currentRsvp),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rsvpButton(
    EventModel event,
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
      onPressed: _canUpdateOwnRsvp(event)
          ? () => _setOwnRsvp(event, status)
          : null,
      child: Text(status),
    );
  }

  // Append inside _EventsScreenState in lib/views/events_screen.dart

  /// Builds a list of all team members and their current RSVP status for a given event.
  bool _isPastEvent(EventModel event) {
    final today = DateTime.now();
    return _isPastDate(event.eventDate, today);
  }

  bool _isPastDate(DateTime date, DateTime today) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  bool _canUpdateOwnRsvp(EventModel event) {
    if (_isPastEvent(event)) return false;
    if (widget.isLeaderOrAdmin) return true;
    if (event.status == 'Go') return false;
    final deadline = event.responseDeadline;
    return deadline == null || !_isPastDate(deadline, DateTime.now());
  }

  Widget _buildMembersRsvpList(EventModel event) {
    if (!widget.isLeaderOrAdmin) {
      return const SizedBox.shrink();
    }
    return _StableMembersRsvpList(
      event: event,
      isLeaderOrAdmin: widget.isLeaderOrAdmin,
      isAdmin: widget.isAdmin,
      supabase: _supabase,
    );
  }

  Future<void> _setOwnRsvp(EventModel event, String status) async {
    final previous = await _supabase
        .from('event_rsvps')
        .select('rsvp_status')
        .eq('event_id', event.id)
        .eq('member_id', widget.currentMemberId)
        .maybeSingle();
    final oldStatus = previous?['rsvp_status']?.toString() ?? 'No Response';
    String? comment;
    if (status == 'Maybe') {
      comment = await _showMaybeCommentDialog(context);
      if (!mounted || comment == null) return;
    }
    await _supabase.from('event_rsvps').upsert({
      'event_id': event.id,
      'member_id': widget.currentMemberId,
      'rsvp_status': status,
      'comment': comment,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'event_id,member_id');
    await _dispatchNotification(
      'rsvp_changed',
      event.id,
      changeDescription:
          '$status${comment?.isNotEmpty == true ? ': $comment' : ''}',
      memberId: widget.currentMemberId,
      oldStatus: oldStatus,
      newStatus: status,
    );
    setState(() {});
  }

  Future<String?> _showMaybeCommentDialog(BuildContext context) async {
    final controller = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Maybe response'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Comment'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return comment;
  }

  Future<void> _updateEventStatus(String eventId, String status) async {
    await _supabase.from('events').update({'status': status}).eq('id', eventId);
    await _dispatchNotification(
      'event_status_changed',
      eventId,
      changeDescription: 'Status changed to $status',
    );
    setState(() {});
  }

  Future<void> _deleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Delete ${event.title} and all related RSVP responses, dance positions, and booking settings? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _supabase.rpc(
        'delete_event_with_artifacts',
        params: {'p_event_id': event.id},
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to delete event: $error')),
        );
      }
    }
  }

  void _showCreateEventDialog(BuildContext context) {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    String type = 'Practice';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    DateTime? responseDeadline;

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
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Details'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              StatefulBuilder(
                builder: (context, setDialogState) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Date: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedDate = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                        );
                      });
                    }
                  },
                ),
              ),
              StatefulBuilder(
                builder: (context, setDialogState) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    responseDeadline == null
                        ? 'Response deadline: None'
                        : 'Response deadline: ${responseDeadline!.day}/${responseDeadline!.month}/${responseDeadline!.year}',
                  ),
                  trailing: const Icon(Icons.event_available),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: responseDeadline ?? selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null)
                      setDialogState(() => responseDeadline = picked);
                  },
                ),
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
                  description: descriptionController.text,
                  responseDeadline: responseDeadline,
                  status: 'Pending',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                final insertedEvent = await _supabase
                    .from('events')
                    .insert({
                      'title': newEvent.title,
                      'event_type': newEvent.eventType,
                      'event_date': newEvent.eventDate.toIso8601String(),
                      'location': newEvent.location,
                      'description': newEvent.description,
                      'response_deadline': newEvent.responseDeadline
                          ?.toIso8601String(),
                      'status': newEvent.status,
                    })
                    .select('id')
                    .single();
                await _dispatchNotification(
                  'event_created',
                  insertedEvent['id'].toString(),
                  changeDescription: 'A new $type was created',
                );
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
  final bool isAdmin;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDeleteEvent;
  final Widget Function() rsvpSectionBuilder;
  final Widget Function() membersRsvpListBuilder;
  final bool initialExpanded;

  const _EventStatusCard({
    required this.rowColor,
    required this.statusColor,
    required this.event,
    required this.isLeaderOrAdmin,
    required this.isAdmin,
    required this.onStatusChanged,
    required this.onDeleteEvent,
    required this.rsvpSectionBuilder,
    required this.membersRsvpListBuilder,
    this.initialExpanded = false,
  });

  @override
  State<_EventStatusCard> createState() => _EventStatusCardState();
}

class _EventStatusCardState extends State<_EventStatusCard> {
  late bool _isExpanded = widget.initialExpanded;

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
                            '${event.eventDate.day}/${event.eventDate.month}/${event.eventDate.year}',
                          ),
                          if (event.responseDeadline != null)
                            Text(
                              'Response deadline: ${event.responseDeadline!.day}/${event.responseDeadline!.month}/${event.responseDeadline!.year}',
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      if (event.location != null &&
                          event.location!.isNotEmpty) ...[
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(child: Text(event.location!)),
                      ] else
                        const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('Details'),
                        onPressed: () => _showDetails(
                          context,
                          event,
                          widget.isLeaderOrAdmin,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                widget.rsvpSectionBuilder(),
                widget.membersRsvpListBuilder(),
                if (widget.isLeaderOrAdmin)
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
                if (widget.isAdmin)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Event'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                        ),
                        onPressed: widget.onDeleteEvent,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    EventModel event,
    bool canEdit,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _EventDetailsDialog(
        event: event,
        canEdit: canEdit,
        onSaved: () {
          if (mounted) setState(() {});
        },
      ),
    );
  }
}

class _EventDetailsDialog extends StatefulWidget {
  final EventModel event;
  final bool canEdit;
  final VoidCallback onSaved;

  const _EventDetailsDialog({
    required this.event,
    required this.canEdit,
    required this.onSaved,
  });

  @override
  State<_EventDetailsDialog> createState() => _EventDetailsDialogState();
}

class _EventDetailsDialogState extends State<_EventDetailsDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _descriptionController;
  late DateTime _selectedDate;
  DateTime? _responseDeadline;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event.title);
    _locationController = TextEditingController(
      text: widget.event.location ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.event.description ?? '',
    );
    _selectedDate = widget.event.eventDate;
    _responseDeadline = widget.event.responseDeadline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickResponseDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _responseDeadline ?? _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _responseDeadline = picked);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final changes = <String>[];
      if (_titleController.text.trim() != widget.event.title) {
        changes.add('title changed');
      }
      if (_selectedDate != widget.event.eventDate) changes.add('date changed');
      if (_locationController.text.trim() != (widget.event.location ?? '')) {
        changes.add('location changed');
      }
      if (_descriptionController.text.trim() !=
          (widget.event.description ?? '')) {
        changes.add('details changed');
      }
      if (_responseDeadline != widget.event.responseDeadline) {
        changes.add('response deadline changed');
      }
      await Supabase.instance.client
          .from('events')
          .update({
            'title': _titleController.text.trim(),
            'event_date': DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
            ).toIso8601String(),
            'location': _locationController.text.trim().isEmpty
                ? null
                : _locationController.text.trim(),
            'description': _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            'response_deadline': _responseDeadline?.toIso8601String(),
          })
          .eq('id', widget.event.id);
      try {
        await Supabase.instance.client.functions.invoke(
          'send-push-notification',
          body: {
            'notification_type': 'event_details_changed',
            'event_id': widget.event.id,
            'change_description': changes.isEmpty
                ? 'Event details updated'
                : changes.join(', '),
          },
        );
      } catch (_) {
        // Notification delivery must not block saving event details.
      }
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save event details: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Event Details' : widget.event.title),
      content: SingleChildScrollView(
        child: _isEditing
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _pickDate,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _responseDeadline == null
                          ? 'Response deadline: None'
                          : 'Response deadline: ${_responseDeadline!.day}/${_responseDeadline!.month}/${_responseDeadline!.year}',
                    ),
                    trailing: const Icon(Icons.event_available),
                    onTap: _pickResponseDeadline,
                  ),
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Location'),
                  ),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Details'),
                    maxLines: 4,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Date: ${widget.event.eventDate.day}/${widget.event.eventDate.month}/${widget.event.eventDate.year}',
                  ),
                  if (widget.event.responseDeadline != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Response deadline: ${widget.event.responseDeadline!.day}/${widget.event.responseDeadline!.month}/${widget.event.responseDeadline!.year}',
                    ),
                  ],
                  if (widget.event.location?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text('Location: ${widget.event.location}'),
                  ],
                  if (widget.event.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Details',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.event.description!),
                  ],
                ],
              ),
      ),
      actions: [
        if (widget.canEdit && !_isEditing)
          TextButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
            onPressed: () => setState(() => _isEditing = true),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(_isEditing ? 'Cancel' : 'OK'),
        ),
        if (_isEditing)
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
      ],
    );
  }
}

class _StableMembersRsvpList extends StatefulWidget {
  final EventModel event;
  final bool isLeaderOrAdmin;
  final bool isAdmin;
  final SupabaseClient supabase;

  const _StableMembersRsvpList({
    required this.event,
    required this.isLeaderOrAdmin,
    required this.isAdmin,
    required this.supabase,
  });

  @override
  State<_StableMembersRsvpList> createState() => _StableMembersRsvpListState();
}

class _StableMembersRsvpListState extends State<_StableMembersRsvpList> {
  late final Stream<List<Map<String, dynamic>>> _membersStream;
  late final Stream<List<Map<String, dynamic>>> _musicianProfilesStream;
  late final Stream<List<Map<String, dynamic>>> _rsvpStream;
  final Map<String, String> _optimisticStatuses = {};

  @override
  void initState() {
    super.initState();
    _membersStream = widget.supabase
        .from('team_members')
        .stream(primaryKey: ['id'])
        .order('full_name');
    _musicianProfilesStream = widget.supabase
        .from('musician_profiles')
        .stream(primaryKey: ['member_id']);
    _rsvpStream = widget.supabase
        .from('event_rsvps')
        .stream(primaryKey: ['id'])
        .eq('event_id', widget.event.id);
  }

  Future<void> _updateRsvp(String memberId, String status) async {
    final previousStatus = _optimisticStatuses[memberId];
    setState(() => _optimisticStatuses[memberId] = status);

    try {
      await widget.supabase.from('event_rsvps').upsert({
        'event_id': widget.event.id,
        'member_id': memberId,
        'rsvp_status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'event_id,member_id');
      await widget.supabase.functions.invoke(
        'send-push-notification',
        body: {
          'notification_type': 'rsvp_changed',
          'event_id': widget.event.id,
          'member_id': memberId,
          'old_status': previousStatus ?? 'No Response',
          'new_status': status,
          'change_description': 'RSVP changed',
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (previousStatus == null) {
          _optimisticStatuses.remove(memberId);
        } else {
          _optimisticStatuses[memberId] = previousStatus;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update attendance: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _membersStream,
      builder: (context, membersSnapshot) {
        if (!membersSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _musicianProfilesStream,
          builder: (context, musicianProfilesSnapshot) {
            if (!musicianProfilesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _rsvpStream,
              builder: (context, rsvpSnapshot) {
                final rsvpMap = <String, Map<String, dynamic>>{};
                for (final rsvp in rsvpSnapshot.data ?? const []) {
                  rsvpMap[rsvp['member_id'].toString()] = rsvp;
                }

                final members = membersSnapshot.data!;
                final musicianIds = musicianProfilesSnapshot.data!
                    .map((profile) => profile['member_id'].toString())
                    .toSet();
                final musicians =
                    members
                        .where(
                          (member) =>
                              musicianIds.contains(member['id'].toString()),
                        )
                        .toList()
                      ..sort(_compareByFirstName);
                final dancers =
                    members
                        .where(
                          (member) =>
                              !musicianIds.contains(member['id'].toString()),
                        )
                        .toList()
                      ..sort(_compareByFirstName);
                final groupedMembers =
                    <({String? heading, Map<String, dynamic>? member})>[
                      (heading: 'Musicians', member: null),
                      ...musicians.map(
                        (member) => (heading: null, member: member),
                      ),
                      (heading: 'Dancers', member: null),
                      ...dancers.map(
                        (member) => (heading: null, member: member),
                      ),
                    ];
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groupedMembers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = groupedMembers[index];
                      if (item.heading != null) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                          child: Text(
                            item.heading!,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        );
                      }

                      final member = item.member!;
                      final memberId = member['id'].toString();
                      final status =
                          _optimisticStatuses[memberId] ??
                          rsvpMap[memberId]?['rsvp_status']?.toString() ??
                          'No Response';
                      final comment = rsvpMap[memberId]?['comment']?.toString();
                      return ListTile(
                        dense: true,
                        title: Text(
                          member['full_name'] ?? 'Unknown Member',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: comment?.isNotEmpty == true
                            ? Text(comment!)
                            : widget.isLeaderOrAdmin
                            ? const Text(
                                'Tap a status to override response',
                                style: TextStyle(fontSize: 10),
                              )
                            : null,
                        trailing: widget.isLeaderOrAdmin
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  _statusChoice(
                                    memberId,
                                    status,
                                    'Attending',
                                    'Yes',
                                    Colors.green,
                                  ),
                                  _statusChoice(
                                    memberId,
                                    status,
                                    'Maybe',
                                    'Maybe',
                                    Colors.orange,
                                  ),
                                  _statusChoice(
                                    memberId,
                                    status,
                                    'Not Attending',
                                    'No',
                                    Colors.red,
                                  ),
                                ],
                              )
                            : _statusBadge(status),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  int _compareByFirstName(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final leftName = left['full_name']?.toString().trim() ?? '';
    final rightName = right['full_name']?.toString().trim() ?? '';
    final leftFirstName = leftName.split(RegExp(r'\s+')).firstOrNull ?? '';
    final rightFirstName = rightName.split(RegExp(r'\s+')).firstOrNull ?? '';
    final firstNameOrder = leftFirstName.toLowerCase().compareTo(
      rightFirstName.toLowerCase(),
    );
    return firstNameOrder != 0
        ? firstNameOrder
        : leftName.toLowerCase().compareTo(rightName.toLowerCase());
  }

  Widget _statusChoice(
    String memberId,
    String currentStatus,
    String status,
    String label,
    Color color,
  ) {
    final selected = currentStatus == status;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      selectedColor: color,
      visualDensity: VisualDensity.compact,
      onSelected: _canUpdateRsvp ? (_) => _updateRsvp(memberId, status) : null,
    );
  }

  bool get _canUpdateRsvp {
    if (widget.isAdmin) return true;
    final today = DateTime.now();
    return !DateTime(
      widget.event.eventDate.year,
      widget.event.eventDate.month,
      widget.event.eventDate.day,
    ).isBefore(DateTime(today.year, today.month, today.day));
  }

  Widget _statusBadge(String status) {
    final color = switch (status) {
      'Attending' => Colors.green,
      'Maybe' => Colors.orange,
      'Not Attending' => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}
