// lib/models/musician_profile.dart

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

