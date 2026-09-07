// lib/models/booking_layout.dart

class BookingLayout {
  final String id;
  final String bookingId;
  final String danceName;
  final Map<String, dynamic> layoutData;
  final String status;
  final DateTime updatedAt;

  BookingLayout({
    required this.id,
    required this.bookingId,
    required this.danceName,
    required this.layoutData,
    required this.status,
    required this.updatedAt,
  });

  factory BookingLayout.fromMap(Map<String, dynamic> map) {
    return BookingLayout(
      id: map['id'] as String,
      bookingId: map['booking_id'] as String,
      danceName: map['dance_name'] as String,
      layoutData: map['layout_data'] as Map<String, dynamic>? ?? {},
      status: map['status'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'booking_id': bookingId,
      'dance_name': danceName,
      'layout_data': layoutData,
      'status': status,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class MusicianProfile {
  final String id;
  final String memberId;
  final String primaryInstrument; // e.g. 'Lead Melodeon', 'Drum'
  final bool isQualified;

  MusicianProfile({
    required this.id,
    required this.memberId,
    required this.primaryInstrument,
    required this.isQualified,
  });

  factory MusicianProfile.fromMap(Map<String, dynamic> map) {
    return MusicianProfile(
      id: map['id'] as String,
      memberId: map['member_id'] as String,
      primaryInstrument: map['primary_instrument'] as String,
      isQualified: map['is_qualified'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'member_id': memberId,
      'primary_instrument': primaryInstrument,
      'is_qualified': isQualified,
    };
  }
}
