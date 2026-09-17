import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MemberDisplaySettings {
  MemberDisplaySettings._();

  static final ValueNotifier<bool> useNicknames = ValueNotifier(false);

  static String nameFor({required String fullName, String? nickname}) {
    if (!useNicknames.value) return fullName;
    final trimmedNickname = nickname?.trim();
    if (trimmedNickname?.isNotEmpty == true) return trimmedNickname!;
    return fullName.trim().split(RegExp(r'\s+')).firstOrNull ?? fullName;
  }
}

class MemberDisplaySettingsRepository {
  MemberDisplaySettingsRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<void> load() async {
    try {
      final settings = await _supabase
          .from('app_display_settings')
          .select('use_nicknames')
          .eq('id', true)
          .maybeSingle();
      MemberDisplaySettings.useNicknames.value =
          settings?['use_nicknames'] == true;
    } catch (_) {
      MemberDisplaySettings.useNicknames.value = false;
    }
  }

  Future<void> setUseNicknames(bool useNicknames) async {
    await _supabase
        .from('app_display_settings')
        .update({'use_nicknames': useNicknames})
        .eq('id', true);
    MemberDisplaySettings.useNicknames.value = useNicknames;
  }
}