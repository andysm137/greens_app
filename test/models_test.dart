// test/models_test.dart
//
// Unit tests for the core model classes.  These are pure-Dart tests that do
// NOT require Supabase, Flutter widgets, or any platform channel — they run
// with `flutter test` and also with `dart test`.

import 'package:flutter_test/flutter_test.dart';

import 'package:greens_app/models/event_model.dart';
import 'package:greens_app/models/team_member.dart';
import 'package:greens_app/services/member_display_settings.dart';
import 'package:greens_app/models/musician_profile.dart';

void main() {
  // ---------------------------------------------------------------------------
  // EventModel
  // ---------------------------------------------------------------------------
  group('EventModel', () {
    final sampleMap = {
      'id': 'event-1',
      'title': 'Thursday Practice',
      'event_type': 'Practice',
      'event_date': '2026-09-18T19:00:00.000Z',
      'location': 'Silkstone Village Hall',
      'description': 'Regular weekly practice',
      'response_deadline': '2026-09-17T12:00:00.000Z',
      'status': 'Go',
      'created_at': '2026-09-01T10:00:00.000Z',
      'updated_at': '2026-09-16T08:00:00.000Z',
    };

    test('fromMap parses all required fields correctly', () {
      final event = EventModel.fromMap(sampleMap);

      expect(event.id, 'event-1');
      expect(event.title, 'Thursday Practice');
      expect(event.eventType, 'Practice');
      expect(event.location, 'Silkstone Village Hall');
      expect(event.status, 'Go');
      expect(event.responseDeadline, isNotNull);
    });

    test('fromMap defaults status to Pending when absent', () {
      final map = Map<String, dynamic>.from(sampleMap)..remove('status');
      final event = EventModel.fromMap(map);
      expect(event.status, 'Pending');
    });

    test('fromMap handles null response_deadline', () {
      final map = Map<String, dynamic>.from(sampleMap)
        ..['response_deadline'] = null;
      final event = EventModel.fromMap(map);
      expect(event.responseDeadline, isNull);
    });

    test('toMap round-trips through fromMap', () {
      final original = EventModel.fromMap(sampleMap);
      final map = original.toMap();

      expect(map['id'], original.id);
      expect(map['title'], original.title);
      expect(map['event_type'], original.eventType);
    });
  });

  // ---------------------------------------------------------------------------
  // EventRsvp
  // ---------------------------------------------------------------------------
  group('EventRsvp', () {
    final rsvpMap = {
      'id': 'rsvp-1',
      'event_id': 'event-1',
      'member_id': 'member-1',
      'rsvp_status': 'Attending',
      'comment': 'Looking forward to it!',
      'updated_at': '2026-09-16T08:30:00.000Z',
    };

    test('fromMap parses all fields correctly', () {
      final rsvp = EventRsvp.fromMap(rsvpMap);
      expect(rsvp.id, 'rsvp-1');
      expect(rsvp.eventId, 'event-1');
      expect(rsvp.memberId, 'member-1');
      expect(rsvp.rsvpStatus, 'Attending');
      expect(rsvp.comment, 'Looking forward to it!');
    });

    test('fromMap handles null comment', () {
      final map = Map<String, dynamic>.from(rsvpMap)..['comment'] = null;
      final rsvp = EventRsvp.fromMap(map);
      expect(rsvp.comment, isNull);
    });

    test('toMap preserves rsvp_status', () {
      final rsvp = EventRsvp.fromMap(rsvpMap);
      expect(rsvp.toMap()['rsvp_status'], 'Attending');
    });
  });

  // ---------------------------------------------------------------------------
  // TeamMember
  // ---------------------------------------------------------------------------
  group('TeamMember', () {
    test('fromMap parses basic fields', () {
      final member = TeamMember.fromMap({
        'id': 'm1',
        'full_name': 'Alice Smith',
        'email': 'alice@example.com',
        'is_leader': true,
        'is_admin': false,
      });

      expect(member.id, 'm1');
      expect(member.fullName, 'Alice Smith');
      expect(member.isLeader, isTrue);
      expect(member.isAdmin, isFalse);
    });

    test('displayName uses nickname then first name when enabled', () {
      addTearDown(() => MemberDisplaySettings.useNicknames.value = false);
      MemberDisplaySettings.useNicknames.value = true;

      expect(
        TeamMember(id: 'm1', fullName: 'Alice Smith', nickname: 'Al').displayName,
        'Al',
      );
      expect(TeamMember(id: 'm2', fullName: 'Bob Jones').displayName, 'Bob');
    });

    test('isMusician returns false when instruments is null', () {
      final member = TeamMember(id: 'm1', fullName: 'Bob');
      expect(member.isMusician, isFalse);
    });

    test('isMusician returns true when instruments is non-empty', () {
      final member = TeamMember(id: 'm2', fullName: 'Carol', instruments: 'Violin');
      expect(member.isMusician, isTrue);
    });

    test('inviteStatus is notInvited by default', () {
      final member = TeamMember(id: 'm3', fullName: 'Dave');
      expect(member.inviteStatus, MemberInviteStatus.notInvited);
    });

    test('inviteStatus is inviteSent when invitedAt is set', () {
      final member = TeamMember(
        id: 'm4',
        fullName: 'Eve',
        invitedAt: DateTime(2026, 9, 10),
      );
      expect(member.inviteStatus, MemberInviteStatus.inviteSent);
    });

    test('inviteStatus is registered when registeredAt is set', () {
      final member = TeamMember(
        id: 'm5',
        fullName: 'Frank',
        invitedAt: DateTime(2026, 9, 10),
        registeredAt: DateTime(2026, 9, 11),
      );
      expect(member.inviteStatus, MemberInviteStatus.registered);
    });

    test('fromMap extracts instruments from nested musician_profiles', () {
      final member = TeamMember.fromMap({
        'id': 'm6',
        'full_name': 'Grace',
        'musician_profiles': [
          {'primary_instrument': 'Lead Melodeon'},
          {'primary_instrument': 'Drum'},
        ],
      });
      expect(member.instruments, contains('Lead Melodeon'));
      expect(member.instruments, contains('Drum'));
    });

    test('fromMap parses last_sign_in_at correctly', () {
      final member = TeamMember.fromMap({
        'id': 'm7',
        'full_name': 'Harry',
        'last_sign_in_at': '2026-09-16T13:13:22.000Z',
      });
      expect(member.lastSignInAt, isNotNull);
      expect(member.lastSignInAt!.year, 2026);
      expect(member.lastSignInAt!.month, 9);
      expect(member.lastSignInAt!.day, 16);
    });

    test('fromMap handles null last_sign_in_at', () {
      final member = TeamMember.fromMap({
        'id': 'm8',
        'full_name': 'Ivy',
      });
      expect(member.lastSignInAt, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // MusicianProfile
  // ---------------------------------------------------------------------------
  group('MusicianProfile', () {
    final profileMap = {
      'id': 'prof-1',
      'member_id': 'm1',
      'primary_instrument': 'Lead Melodeon',
      'is_qualified': true,
    };

    test('fromMap parses all fields', () {
      final profile = MusicianProfile.fromMap(profileMap);
      expect(profile.id, 'prof-1');
      expect(profile.memberId, 'm1');
      expect(profile.primaryInstrument, 'Lead Melodeon');
      expect(profile.isQualified, isTrue);
    });

    test('fromMap defaults isQualified to true when absent', () {
      final map = Map<String, dynamic>.from(profileMap)
        ..['is_qualified'] = null;
      final profile = MusicianProfile.fromMap(map);
      expect(profile.isQualified, isTrue);
    });

    test('toMap round-trips primary_instrument', () {
      final profile = MusicianProfile.fromMap(profileMap);
      expect(profile.toMap()['primary_instrument'], 'Lead Melodeon');
    });
  });
}

