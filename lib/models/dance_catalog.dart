// lib/models/dance_catalog.dart

class DanceCatalog {
  final String id;
  final String danceName;
  final int standardPositions;
  final bool hasMaf;
  final bool hasMab;
  final DateTime createdAt;

  DanceCatalog({
    required this.id,
    required this.danceName,
    required this.standardPositions,
    required this.hasMaf,
    required this.hasMab,
    required this.createdAt,
  });

  factory DanceCatalog.fromMap(Map<String, dynamic> map) {
    return DanceCatalog(
      id: map['id'] as String,
      danceName: map['dance_name'] as String,
      standardPositions: map['standard_positions'] as int,
      hasMaf: map['has_maf'] as bool? ?? false,
      hasMab: map['has_mab'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dance_name': danceName,
      'standard_positions': standardPositions,
      'has_maf': hasMaf,
      'has_mab': hasMab,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
