class TeamMember {
  final String id;
  final String fullName;
  final String? email;
  final String? phone;
  final bool isLeader;
  final bool isAdmin;
  final String? instruments;

  TeamMember({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    this.isLeader = false,
    this.isAdmin = false,
    this.instruments,
  });

  /// Helper getter: returns true if the member has any recorded instruments
  bool get isMusician => instruments != null && instruments!.trim().isNotEmpty;

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? '',
      email: map['email'],
      phone: map['phone'],
      isLeader: map['is_leader'] ?? false,
      isAdmin: map['is_admin'] ?? false,
      instruments: map['instruments'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'is_leader': isLeader,
      'is_admin': isAdmin,
      'instruments': instruments,
    };
  }
}
