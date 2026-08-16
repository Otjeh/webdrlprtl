import 'package:webdlrprtl01/models/user_profile.dart';
import 'package:webdlrprtl01/services/supabase_service.dart';

class AuthService {
  static const List<UserProfile> defaultUsers = [
    UserProfile(
      email: 'dealer.admin@gmail.com',
      nik: '3201012001010001',
      role: 'Dealer Distribution Admin',
      code: 'dlr.DDD-dist-adm.BBB',
      loa: 'LoA1',
      name: 'Dealer Admin',
    ),
    UserProfile(
      email: 'dealer.manager@gmail.com',
      nik: '3201012001010002',
      role: 'Dealer Distribution Manager',
      code: 'dlr.DDD-dist-mgr.CCC',
      loa: 'LoA3',
      name: 'Dealer Manager',
    ),
    UserProfile(
      email: 'warehouse.admin@gmail.com',
      nik: '3201012001010003',
      role: 'Modena Warehouse Distribution Admin',
      code: 'whs-dist-adm.MMM',
      loa: 'LoA2',
      name: 'Warehouse Admin',
    ),
    UserProfile(
      email: 'logistics.driver@gmail.com',
      nik: '3201012001010005',
      role: 'Third Party Logistics Driver',
      code: 'log.LLL-drvr.KKK',
      loa: 'LoA2',
      name: 'Logistics Driver',
    ),
  ];

  Future<UserProfile?> signIn({
    required String email,
    required String password,
    String? nik,
    void Function(String status)? onStatus,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedPassword = password.trim();

    if (SupabaseService.isConfigured) {
      try {
        onStatus?.call('Authenticating with Supabase...');
        final response = await SupabaseService.instance.signInWithPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );

        final authUser = response.user;
        if (authUser == null) {
          return null;
        }

        onStatus?.call('Loading your profile...');
        final profileMap = await SupabaseService.instance.fetchProfileByEmail(
          normalizedEmail,
        );
        if (profileMap != null) {
          return UserProfile.fromJson(profileMap);
        }

        final fallbackNik = nik?.trim().isNotEmpty == true
            ? nik!.trim()
            : 'SUPABASE-USER';
        return UserProfile(
          email: normalizedEmail,
          nik: fallbackNik,
          role: 'Supabase User',
          code: 'sb-user',
          loa: 'LoA2',
          name:
              authUser.userMetadata?['full_name']?.toString() ??
              'Supabase User',
        );
      } catch (_) {
        return validateLogin(email: email, nik: nik ?? '');
      }
    }

    onStatus?.call('Checking local account...');
    return validateLogin(email: email, nik: nik ?? '', password: password);
  }

  Future<UserProfile?> validateLogin({
    required String email,
    required String nik,
    String? password,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedNik = nik.trim();

    if (!SupabaseService.isDemoMode) {
      final remoteProfiles = await SupabaseService.instance.fetchProfiles();
      for (final row in remoteProfiles) {
        final user = UserProfile.fromJson(row);
        if (user.email.toLowerCase() == normalizedEmail.toLowerCase() &&
            user.nik == normalizedNik) {
          return user;
        }
      }
    }

    for (final user in defaultUsers) {
      final matchesIdentity =
          user.email.toLowerCase() == normalizedEmail.toLowerCase() &&
          (normalizedNik.isEmpty || user.nik == normalizedNik);
      final matchesPassword =
          password == null ||
          (SupabaseService.isDemoMode
              ? SupabaseService.demoPasswordMatches(
                  email: normalizedEmail,
                  password: password,
                )
              : password.trim() == 'password123');
      if (matchesIdentity && matchesPassword) {
        return user;
      }
    }

    return null;
  }
}
