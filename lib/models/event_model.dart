// lib/models/event_model.dart

class EventModel {
  final String id;
  final String title;
  final String eventType; // 'Practice' or 'Booking'
  final DateTime eventDate;
  final String? location;
  final String status; // 'Pending', 'Go', or 'No-go'
  final DateTime createdAt;
  final DateTime updatedAt;

  EventModel({
    required this.id,
    required this.title,
    required this.eventType,
    required this.eventDate,
    this.location,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventModel.fromMap(Map<String, dynamic> map) {
    return EventModel(
      id: map['id'] as String,
      title: map['title'] as String,
      eventType: map['event_type'] as String,
      eventDate: DateTime.parse(map['event_date'] as String),
      location: map['location'] as String?,
      status: map['status'] as String? ?? 'Pending',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'event_type': eventType,
      'event_date': eventDate.toIso8601String(),
      'location': location,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}

class EventRsvp {
  final String id;
  final String eventId;
  final String memberId;
  final String rsvpStatus; // 'Attending', 'Not Attending', 'Maybe'
  final DateTime updatedAt;

  EventRsvp({
    required this.id,
    required this.eventId,
    required this.memberId,
    required this.rsvpStatus,
    required this.updatedAt,
  });

  factory EventRsvp.fromMap(Map<String, dynamic> map) {
    return EventRsvp(
      id: map['id'] as String,
      eventId: map['event_id'] as String,
      memberId: map['member_id'] as String,
      rsvpStatus: map['rsvp_status'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'event_id': eventId,
      'member_id': memberId,
      'rsvp_status': rsvpStatus,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
