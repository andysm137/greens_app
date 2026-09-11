import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/team_member.dart';

class AdminAuthService {
  final SupabaseClient _supabase;

  AdminAuthService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  Future<void> inviteMember({
    required String fullName,
    required String email,
    String? phone,
    required bool isLeader,
    required bool isAdmin,
    String? instruments,
  }) async {
    await _supabase.functions.invoke(
      'invite-member',
      body: {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'is_leader': isLeader,
        'is_admin': isAdmin,
        'instruments': instruments,
      },
    );
  }

  Future<void> deleteMember(String memberId) async {
    await _supabase.functions.invoke(
      'delete-member',
      body: {'member_id': memberId},
    );
  }

  Future<void> inviteExistingMember(String memberId) async {
    await _supabase.functions.invoke(
      'invite-existing-member',
      body: {'member_id': memberId},
    );
  }

  Future<Map<String, MemberInviteStatus>> fetchMemberInviteStatuses() async {
    final response = await _supabase.functions.invoke('member-auth-statuses');
    final rawStatuses = Map<String, dynamic>.from(
      (response.data as Map<String, dynamic>)['statuses'] as Map,
    );

    return rawStatuses.map(
      (memberId, status) => MapEntry(
        memberId,
        MemberInviteStatus.values.firstWhere(
          (value) => value.name == status,
          orElse: () => MemberInviteStatus.notInvited,
        ),
      ),
    );
  }
}
