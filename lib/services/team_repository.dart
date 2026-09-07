// lib/services/team_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/team_member.dart';
import '../models/competency.dart';
import '../models/event_model.dart';
import '../models/booking_layout.dart';

class TeamRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================================
  // TEAM MEMBERS MANAGEMENT
  // ==========================================

  /// Fetch all registered team members
  Future<List<TeamMember>> fetchTeamMembers() async {
    final response = await _supabase
        .from('team_members')
        .select()
        .order('full_name', ascending: true);

    return (response as List).map((map) => TeamMember.fromMap(map)).toList();
  }

  /// Creates a new team member using a Map payload from the Admin view
  Future<void> createTeamMember(Map<String, dynamic> data) async {
    await _supabase.from('team_members').insert(data);
  }

  /// Legacy helper to add a basic team member directly
  Future<void> addTeamMember({
    required String fullName,
    String? email,
    String? phone,
  }) async {
    await _supabase.from('team_members').insert({
      'full_name': fullName,
      'email': email,
      'phone': phone,
    });
  }

  /// Updates an existing team member in Supabase using a Map payload
  Future<void> updateTeamMember(
    String memberId,
    Map<String, dynamic> data,
  ) async {
    await _supabase.from('team_members').update(data).eq('id', memberId);
  }

  /// Updates admin access role for a member
  Future<void> updateTeamMemberRole({
    required String memberId,
    required bool isAdmin,
  }) async {
    await _supabase
        .from('team_members')
        .update({'is_admin': isAdmin})
        .eq('id', memberId);
  }

  // ==========================================
  // COMPETENCIES / SKILLS MATRIX
  // ==========================================

  /// Upserts a competency record (L, Q, M) for a specific member, dance, and position
  Future<void> upsertCompetency({
    required String memberId,
    required String danceName,
    required int positionNumber,
    required String proficiencyLevel,
  }) async {
    await _supabase.from('competencies').upsert({
      'member_id': memberId,
      'dance_name': danceName,
      'position_number': positionNumber,
      'proficiency_level': proficiencyLevel,
    }, onConflict: 'member_id,dance_name,position_number');
  }

  /// Fetch competencies for a specific team member
  Future<List<Competency>> fetchCompetenciesForMember(String memberId) async {
    final response = await _supabase
        .from('competencies')
        .select()
        .eq('member_id', memberId);

    return (response as List).map((map) => Competency.fromMap(map)).toList();
  }

  /// Fetch competencies for a specific dance name
  Future<List<Competency>> fetchCompetenciesForDance(String danceName) async {
    final response = await _supabase
        .from('competencies')
        .select()
        .eq('dance_name', danceName);

    return (response as List).map((map) => Competency.fromMap(map)).toList();
  }

  // ==========================================
  // DANCE CATALOG MANAGEMENT
  // ==========================================

  /// Fetches simple list of dance names
  Future<List<String>> fetchDanceNames() async {
    final response = await _supabase.from('dance_catalog').select('dance_name');
    return (response as List)
        .map((map) => map['dance_name'].toString())
        .toList();
  }

  /// Creates a new dance entry in the catalog by name
  Future<void> createDance(String danceName) async {
    await addDance(danceName);
  }

  /// Adds a new dance entry with optional notes
  Future<void> addDance(
    String danceName, {
    String? notes,
    int standardPositions = 8,
    bool hasMaf = false,
    bool hasMab = false,
  }) async {
    final payload = <String, dynamic>{
      'dance_name': danceName.trim(),
      'standard_positions': standardPositions,
      'has_maf': hasMaf,
      'has_mab': hasMab,
      'notes': notes?.trim(),
    };

    await _supabase.from('dance_catalog').insert(payload);
  }

  /// Fetches full details for all catalog dances
  Future<List<Map<String, dynamic>>> fetchDanceCatalogDetails() async {
    final response = await _supabase.from('dance_catalog').select();
    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches all dances from dance_catalog including notes
  Future<List<Map<String, dynamic>>> fetchDanceCatalog() async {
    final response = await _supabase
        .from('dance_catalog')
        .select('id, dance_name, standard_positions, has_maf, has_mab, notes')
        .order('dance_name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Inserts or updates a dance entry
  Future<void> upsertDanceCatalog({
    required String danceName,
    String? notes,
    int standardPositions = 8,
    bool hasMaf = false,
    bool hasMab = false,
  }) async {
    final Map<String, dynamic> payload = {
      'dance_name': danceName.trim(),
      'standard_positions': standardPositions,
      'has_maf': hasMaf,
      'has_mab': hasMab,
      'notes': notes?.trim(),
    };

    await _supabase
        .from('dance_catalog')
        .upsert(payload, onConflict: 'dance_name');
  }

  /// Deletes a dance record from dance_catalog by dance name or ID
  Future<void> deleteDance(String danceIdentifier) async {
    await _supabase
        .from('dance_catalog')
        .delete()
        .eq('dance_name', danceIdentifier);
  }

  /// Updates the name of an existing dance in the catalog
  Future<void> updateDanceName(String oldDanceName, String newDanceName) async {
    await _supabase
        .from('dance_catalog')
        .update({'dance_name': newDanceName.trim()})
        .eq('dance_name', oldDanceName);
  }

  // ==========================================
  // DANCE ASSIGNMENTS (SET LISTS)
  // ==========================================

  Future<List<Map<String, dynamic>>> fetchDanceAssignments(
    String danceName,
  ) async {
    final response = await _supabase
        .from('dance_assignments')
        .select('*, team_members(full_name)')
        .eq('dance_name', danceName);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> assignMemberToPosition({
    required String danceName,
    required int positionNumber,
    required String memberId,
  }) async {
    await _supabase.from('dance_assignments').upsert({
      'dance_name': danceName,
      'position_number': positionNumber,
      'member_id': memberId,
    }, onConflict: 'dance_name,position_number');
  }

  Future<void> removeMemberFromPosition({
    required String danceName,
    required int positionNumber,
  }) async {
    await _supabase
        .from('dance_assignments')
        .delete()
        .eq('dance_name', danceName)
        .eq('position_number', positionNumber);
  }
}

// Append these sections to lib/services/team_repository.dart

extension EventAndBookingRepository on TeamRepository {
  // ==========================================
  // EVENTS & RSVP MANAGEMENT
  // ==========================================

  /// Fetch all upcoming and past events ordered by event date
  Future<List<EventModel>> fetchEvents() async {
    final response = await _supabase
        .from('events')
        .select()
        .order('event_date', ascending: true);

    return (response as List).map((map) => EventModel.fromMap(map)).toList();
  }

  /// Create a new event (Practice or Booking)
  Future<void> createEvent(EventModel event) async {
    await _supabase.from('events').insert(event.toMap());
  }

  /// Fetch RSVPs for a specific event
  Future<List<EventRsvp>> fetchRsvpsForEvent(String eventId) async {
    final response = await _supabase
        .from('event_rsvps')
        .select()
        .eq('event_id', eventId);

    return (response as List).map((map) => EventRsvp.fromMap(map)).toList();
  }

  /// Upsert an RSVP for a member for a given event
  Future<void> updateRsvp({
    required String id,
    required String eventId,
    required String memberId,
    required String rsvpStatus,
  }) async {
    final payload = EventRsvp(
      id: id,
      eventId: eventId,
      memberId: memberId,
      rsvpStatus: rsvpStatus,
      updatedAt: DateTime.now(),
    ).toMap();

    await _supabase
        .from('event_rsvps')
        .upsert(payload, onConflict: 'event_id,member_id');
  }

  /// Get a list of member IDs who are marked as 'Not Attending' for an event
  Future<List<String>> fetchAbsentMemberIds(String eventId) async {
    final response = await _supabase
        .from('event_rsvps')
        .select('member_id')
        .eq('event_id', eventId)
        .eq('rsvp_status', 'Not Attending');

    return (response as List)
        .map((map) => map['member_id'].toString())
        .toList();
  }

  // ==========================================
  // BOOKING LAYOUTS
  // ==========================================

  /// Fetch all stored layouts for a given booking event
  Future<List<BookingLayout>> fetchBookingLayouts(String bookingId) async {
    final response = await _supabase
        .from('booking_layouts')
        .select()
        .eq('booking_id', bookingId);

    return (response as List).map((map) => BookingLayout.fromMap(map)).toList();
  }

  /// Save or update a dance layout for a specific booking
  Future<void> saveBookingLayout(BookingLayout layout) async {
    await _supabase
        .from('booking_layouts')
        .upsert(layout.toMap(), onConflict: 'booking_id,dance_name');
  }

  // ==========================================
  // MUSICIAN PROFILES
  // ==========================================

  /// Fetch musician profiles for all team members
  Future<List<MusicianProfile>> fetchMusicianProfiles() async {
    final response = await _supabase.from('musician_profiles').select();
    return (response as List)
        .map((map) => MusicianProfile.fromMap(map))
        .toList();
  }

  /// Upsert a musician profile
  Future<void> upsertMusicianProfile(MusicianProfile profile) async {
    await _supabase
        .from('musician_profiles')
        .upsert(profile.toMap(), onConflict: 'member_id');
  }
}
