import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodvision/core/models/nutrilens_profile.dart';
import 'package:foodvision/core/services/profile_service.dart';

final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<NutriLensProfile>>((ref) {
  final service = ref.watch(profileServiceProvider);
  return ProfileNotifier(service);
});

class ProfileNotifier extends StateNotifier<AsyncValue<NutriLensProfile>> {
  final ProfileService _service;

  ProfileNotifier(this._service) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final profile = await _service.getProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateProfile(NutriLensProfile updated) async {
    state = const AsyncValue.loading();
    try {
      final saved = await _service.updateProfile(updated);
      state = AsyncValue.data(saved);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
