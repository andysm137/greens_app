import '../services/member_display_settings.dart';

class TeamMember {
  final String id;
  final String fullName;
  final String? nickname;
  final String? email;
  final String? phone;
  final bool isLeader;
  final bool isAdmin;
  final String? instruments;
  final String? authUserId;
  final DateTime? invitedAt;
  final DateTime? registeredAt;
  final DateTime? lastSignInAt;

  TeamMember({
    required this.id,
    required this.fullName,
    this.nickname,
    this.email,
    this.phone,
    this.isLeader = false,
    this.isAdmin = false,
    this.instruments,
    this.authUserId,
    this.invitedAt,
    this.registeredAt,
    this.lastSignInAt,
  });

  /// Helper getter: returns true if the member has any recorded instruments
  bool get isMusician => instruments != null && instruments!.trim().isNotEmpty;

  String get displayName =>
      MemberDisplaySettings.nameFor(fullName: fullName, nickname: nickname);

  MemberInviteStatus get inviteStatus {
    if (registeredAt != null) return MemberInviteStatus.registered;
    if (authUserId != null || invitedAt != null) {
      return MemberInviteStatus.inviteSent;
    }
    return MemberInviteStatus.notInvited;
  }

  factory TeamMember.fromMap(Map<String, dynamic> map) {
      final musicianProfiles = map['musician_profiles'];
      final profileInstruments = musicianProfiles is List
      ? musicianProfiles
        .whereType<Map>()
        .map((profile) => profile['primary_instrument']?.toString())
        .whereType<String>()
        .where((instrument) => instrument.trim().isNotEmpty)
        .join(', ')
      : null;

    return TeamMember(
      id: map['id'] ?? '',
      fullName: map['full_name'] ?? '',
      nickname: map['nickname']?.toString(),
      email: map['email'],
      phone: map['phone'],
      isLeader: map['is_leader'] ?? false,
      isAdmin: map['is_admin'] ?? false,
      instruments: profileInstruments ?? map['instruments']?.toString(),
      authUserId: map['auth_user_id']?.toString(),
      invitedAt: _parseDate(map['invited_at']),
      registeredAt: _parseDate(map['registered_at']),
      lastSignInAt: _parseDate(map['last_sign_in_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) => value == null
      ? null
      : DateTime.tryParse(value.toString());

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'nickname': nickname,
      'email': email,
      'phone': phone,
      'is_leader': isLeader,
      'is_admin': isAdmin,
    };
  }
}

enum MemberInviteStatus { notInvited, inviteSent, registered }
