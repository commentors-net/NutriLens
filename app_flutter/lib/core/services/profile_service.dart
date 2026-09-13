import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodvision/core/auth/auth_service.dart';
import 'package:foodvision/core/config/environment.dart';
import 'package:foodvision/core/models/nutrilens_profile.dart';

class ProfileService {
  final String apiBaseUrl;
  final AuthService _authService;
  final Dio _dio = Dio();

  ProfileService({
    required this.apiBaseUrl,
    required AuthService authService,
  }) : _authService = authService {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getIdToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  /// Get user's NutriLens nutritional profile & goals
  Future<NutriLensProfile> getProfile() async {
    try {
      final response = await _dio.get('$apiBaseUrl/nutrilens/auth/nutrilens-profile');
      if (response.statusCode == 200 && response.data != null) {
        return NutriLensProfile.fromJson(Map<String, dynamic>.from(response.data));
      }
      return const NutriLensProfile();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 401) {
        return const NutriLensProfile();
      }
      rethrow;
    } catch (_) {
      return const NutriLensProfile();
    }
  }

  /// Update user's NutriLens nutritional profile & goals
  Future<NutriLensProfile> updateProfile(NutriLensProfile profile) async {
    final response = await _dio.patch(
      '$apiBaseUrl/nutrilens/auth/nutrilens-profile',
      data: profile.toJson(),
    );
    if (response.statusCode == 200 && response.data != null) {
      return NutriLensProfile.fromJson(Map<String, dynamic>.from(response.data));
    }
    throw Exception('Failed to update profile: ${response.statusCode}');
  }
}

final profileServiceProvider = Provider<ProfileService>((ref) {
  final authService = ref.watch(authServiceProvider);
  final apiBaseUrl = ref.watch(apiBaseUrlProvider);
  return ProfileService(apiBaseUrl: apiBaseUrl, authService: authService);
});
