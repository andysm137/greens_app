// lib/models/competency.dart

class Competency {
  final String id;
  final String memberId;
  final String danceName;
  final int?
  positionNumber; // 1-8 or 1-12, null for general musician tune competency
  final String proficiencyLevel; // 'L', 'Q', or 'M'
  final DateTime? updatedAt;

  Competency({
    required this.id,
    required this.memberId,
    required this.danceName,
    this.positionNumber,
    required this.proficiencyLevel,
    this.updatedAt,
  });

  factory Competency.fromMap(Map<String, dynamic> map) {
    return Competency(
      id: map['id']?.toString() ?? '',
      memberId: map['member_id']?.toString() ?? '',
      danceName: map['dance_name'] ?? '',
      positionNumber: map['position_number'] as int?,
      proficiencyLevel: map['proficiency_level'] ?? '-',
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'member_id': memberId,
      'dance_name': danceName,
      'position_number': positionNumber,
      'proficiency_level': proficiencyLevel,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}
