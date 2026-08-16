import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  static const String _demoUrl = 'https://mjcscqrwlvjzptxnyhsl.supabase.co';
  static const String _demoAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1qY3NjcXJ3bHZqenB0eG55aHNsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYzMzc2NDYsImV4cCI6MjEwMTkxMzY0Nn0.FCF00gJhHIgPnT3VBvTHeuM-o1QzrDzjKHbUBwpodWc';
  static const String demoAdministratorEmail = 'otjeh@fivea.eu';
  static const String demoAdministratorPassword = 'T@t5?0Tj3h!';
  static final Map<String, String> _demoPasswords = {
    demoAdministratorEmail: demoAdministratorPassword,
    'dealer.admin@gmail.com': 'T@t5?0Tj3h!',
    'dealer.manager@gmail.com': 'T@t5?0Tj3h!',
    'warehouse.admin@gmail.com': 'T@t5?0Tj3h!',
    'logistics.driver@gmail.com': 'T@t5?0Tj3h!',
  };
  Map<String, dynamic>? _demoPairing;
  List<Map<String, dynamic>>? _demoJourneyRowsStore;
  final List<Map<String, dynamic>> _demoNotifications = [];

  static String get denaUrl => const String.fromEnvironment(
    'DENA_SUPABASE_URL',
    defaultValue: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: _demoUrl,
    ),
  );

  static String get denaAnonKey => const String.fromEnvironment(
    'DENA_SUPABASE_ANON_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: _demoAnonKey,
    ),
  );

  static bool get isDemoMode =>
      denaUrl == _demoUrl || denaAnonKey == _demoAnonKey;

  static bool get isConfigured => !isDemoMode;

  Future<Map<String, String>> createWebMobilePairing() async {
    final random = Random.secure();
    final code = (10000 + random.nextInt(90000)).toString();
    final id = _uuidLike(random);
    final hash = sha256.convert(utf8.encode(code)).toString();

    final pairing = {
      'id': id,
      'code_hash': hash,
      'status': 'pending',
      'expires_at': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String(),
    };
    if (isDemoMode) {
      _demoPairing = pairing;
    } else {
      await Supabase.instance.client
          .from('web_mobile_pairings')
          .insert(pairing);
    }
    return {'id': id, 'code': code};
  }

  Future<Map<String, dynamic>?> fetchWebMobilePairing(String id) async {
    if (isDemoMode) return _demoPairing;
    final response = await Supabase.instance.client.rpc(
      'get_web_mobile_pairing',
      params: {'pairing_id': id},
    );
    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    return null;
  }

  String _uuidLike(Random random) {
    final parts = List.generate(
      32,
      (_) => random.nextInt(16).toRadixString(16),
    );
    return '${parts.sublist(0, 8).join()}-${parts.sublist(8, 12).join()}-${parts.sublist(12, 16).join()}-${parts.sublist(16, 20).join()}-${parts.sublist(20).join()}';
  }

  static bool demoPasswordMatches({
    required String email,
    required String password,
  }) {
    return _demoPasswords[email.trim().toLowerCase()] == password.trim();
  }

  static Future<void> initialize() async {
    await Supabase.initialize(url: denaUrl, anonKey: denaAnonKey);
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<bool> signInAsAdministrator({
    required String email,
    required String password,
  }) async {
    if (isDemoMode) {
      return email.trim().toLowerCase() == demoAdministratorEmail &&
          password == demoAdministratorPassword;
    }

    try {
      await signInWithPassword(email: email.trim(), password: password);
      final profile = await fetchProfileByEmail(email);
      final isAdmin = profile?['role']?.toString() == 'Portal Administrator';
      if (!isAdmin) {
        await signOut();
      }
      return isAdmin;
    } catch (_) {
      return false;
    }
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    await Supabase.instance.client.auth.signOut();
  }

  Future<Map<String, dynamic>?> fetchProfileByEmail(String email) async {
    if (isDemoMode) {
      final normalizedEmail = email.trim().toLowerCase();
      for (final profile in await fetchProfiles()) {
        if (profile['email'].toString().toLowerCase() == normalizedEmail) {
          return profile;
        }
      }
      return null;
    }

    try {
      final response = await Supabase.instance.client
          .from('dealer_profiles')
          .select()
          .eq('email', email.trim())
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return Map<String, dynamic>.from(response as Map);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchProfiles() async {
    if (isDemoMode) {
      return [
        {
          'email': demoAdministratorEmail,
          'nik': 'PORTAL-ADMIN',
          'role': 'Portal Administrator',
          'code': 'portal-admin',
          'loa': 'LoA4',
          'name': 'Portal Administrator',
        },
        {
          'email': 'dealer.admin@gmail.com',
          'nik': '3201012001010001',
          'role': 'Dealer Distribution Admin',
          'code': 'dlr.DDD-dist-adm.BBB',
          'loa': 'LoA1',
          'name': 'Dealer Admin',
        },
        {
          'email': 'dealer.manager@gmail.com',
          'nik': '3201012001010002',
          'role': 'Dealer Distribution Manager',
          'code': 'dlr.DDD-dist-mgr.CCC',
          'loa': 'LoA3',
          'name': 'Dealer Manager',
        },
        {
          'email': 'warehouse.admin@gmail.com',
          'nik': '3201012001010003',
          'role': 'Modena Warehouse Distribution Admin',
          'code': 'whs-dist-adm.MMM',
          'loa': 'LoA2',
          'name': 'Warehouse Admin',
        },
        {
          'email': 'logistics.driver@gmail.com',
          'nik': '3201012001010005',
          'role': 'Third Party Logistics Driver',
          'code': 'log.LLL-drvr.KKK',
          'loa': 'LoA2',
          'name': 'Logistics Driver',
        },
      ];
    }

    try {
      final response = await Supabase.instance.client
          .from('dealer_profiles')
          .select();

      return response
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchPortalRoles() async {
    if (isDemoMode) {
      return const [
        {
          'role': 'Dealer Distribution Admin',
          'access': 'Allocate / Accept delivery',
        },
        {
          'role': 'Dealer Distribution Manager',
          'access': 'Order / Sign delivery / Accept stock',
        },
        {
          'role': 'Modena Warehouse Distribution Admin',
          'access': 'Confirm / Prepare / Restock',
        },
        {
          'role': 'Modena Warehouse Distribution Manager',
          'access': 'Approve stock / Sign delivery / Manage warehouse flow',
        },
        {
          'role': 'Warehouse Manager',
          'access': 'Approve stock / Sign delivery / Manage warehouse flow',
        },
        {
          'role': 'Third Party Logistics Driver',
          'access': 'Pickup / Transit / Deliver',
        },
        {
          'role': 'Logistics Manager',
          'access': 'Manage pickup / transit / delivery operations',
        },
      ];
    }

    try {
      final response = await Supabase.instance.client
          .from('portal_roles')
          .select('role, access')
          .eq('active', true)
          .order('sort_order');
      return response
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveDealerProfile(Map<String, dynamic> profile) async {
    if (isDemoMode) return;

    await Supabase.instance.client
        .from('dealer_profiles')
        .upsert(profile, onConflict: 'email');
  }

  Future<void> updateUserPassword({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (password.length < 6) {
      throw ArgumentError('Password must contain at least 6 characters.');
    }

    if (isDemoMode) {
      if (!_demoPasswords.containsKey(normalizedEmail)) {
        throw StateError('Registered user not found.');
      }
      _demoPasswords[normalizedEmail] = password;
      return;
    }

    final response = await Supabase.instance.client.functions.invoke(
      'admin-update-user-password',
      body: {'email': normalizedEmail, 'password': password},
    );
    if (response.data is Map && response.data['updated'] != true) {
      throw StateError(
        (response.data as Map)['error']?.toString() ??
            'Password update was not confirmed.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductJourney() async {
    if (isDemoMode) {
      _demoJourneyRowsStore ??= _demoJourneyRows();
      return List<Map<String, dynamic>>.from(_demoJourneyRowsStore!);
    }

    try {
      final response = await Supabase.instance.client
          .from('product_journey')
          .select()
          .order('created_at', ascending: true);

      return response
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchActiveProductJourney() async {
    if (isDemoMode) {
      final rows = await fetchProductJourney();
      return rows
          .where((row) => row['status']?.toString() == 'pending')
          .toList();
    }

    try {
      final response = await Supabase.instance.client
          .from('product_journey')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: true);

      return response
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveJourneyRow(Map<String, dynamic> row) async {
    if (isDemoMode) {
      _demoJourneyRowsStore ??= _demoJourneyRows();
      _demoJourneyRowsStore!.removeWhere(
        (existing) => existing['id'] == row['id'],
      );
      _demoJourneyRowsStore!.add(Map<String, dynamic>.from(row));
      return;
    }

    final payload = Map<String, dynamic>.from(row);
    payload['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await Supabase.instance.client
        .from('product_journey')
        .upsert(payload, onConflict: 'id');
  }

  Future<int> createJourneyNotifications({
    required Map<String, dynamic> journey,
    required String sender,
  }) async {
    final journeyId = journey['id']?.toString() ?? '';
    if (journeyId.isEmpty) {
      throw ArgumentError('A product journey ID is required.');
    }

    if (isDemoMode) {
      final actor = journey['actor']?.toString() ?? '';
      final profiles = await fetchProfiles();
      final recipients = profiles
          .where((profile) => _profileMatchesActor(profile, actor))
          .toList();
      final productName =
          journey['product_name']?.toString() ??
          journey['product_id']?.toString() ??
          'product';
      _demoNotifications.addAll(
        recipients.map(
          (profile) => {
            'recipient_email': profile['email'],
            'journey_id': journeyId,
            'sender_email': sender,
            'title': 'Product journey requires attention',
            'message': '$productName is ready for $actor confirmation.',
          },
        ),
      );
      return recipients.length;
    }

    final response = await Supabase.instance.client.functions.invoke(
      'send-journey-notification',
      body: {'journey_id': journeyId},
    );
    if (response.data is! Map || response.data['notified'] is! int) {
      throw StateError('Notification delivery was not confirmed.');
    }
    return response.data['notified'] as int;
  }

  bool _profileMatchesActor(Map<String, dynamic> profile, String actor) {
    final normalizedActor = actor.trim().toLowerCase();
    final role = profile['role']?.toString().trim().toLowerCase();
    final code = profile['code']?.toString().trim().toLowerCase();
    const actorAliases = {
      'dlr.ddd-dist-adm.bbb': 'dealer distribution admin',
      'dlr.ddd-dist-mgr.ccc': 'dealer distribution manager',
      'whs-dist-adm.mmm': 'modena warehouse distribution admin',
      'log.lll-drvr.kkk': 'third party logistics driver',
    };

    return normalizedActor == role ||
        normalizedActor == code ||
        actorAliases[normalizedActor] == role;
  }

  Future<Map<String, dynamic>> createProductJourney({
    required String productId,
    required String productName,
    required String category,
    required String initiator,
    required String actor,
    required String action,
  }) async {
    final journeyState = action == 'allocate' ? 'Allocated' : 'Ordered';
    final row = {
      'id': 'P-${DateTime.now().millisecondsSinceEpoch}',
      'product_id': productId,
      'product_name': productName,
      'category': category,
      'state': journeyState,
      'current_state': 'Available',
      'new_state': journeyState,
      'actor': actor,
      'initiator': initiator,
      'loa': 'LoA1',
      'status': 'pending',
      'approved_by': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    await saveJourneyRow(row);
    return row;
  }

  Future<void> updateApprovalStatus({
    required String id,
    required String status,
    required String approver,
  }) async {
    if (isDemoMode) {
      return;
    }

    await Supabase.instance.client
        .from('product_journey')
        .update({
          'status': status,
          'approved_by': approver,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> createApprovalDecision({
    required String journeyId,
    required String decision,
    required String approverName,
    required String approverRole,
    String? comment,
  }) async {
    if (isDemoMode) {
      return;
    }

    final decisionId = 'AD-${DateTime.now().millisecondsSinceEpoch}';
    await Supabase.instance.client.from('approval_decisions').insert({
      'id': decisionId,
      'journey_id': journeyId,
      'decision': decision,
      'approver_name': approverName,
      'approver_role': approverRole,
      'comment': comment,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> _demoJourneyRows() {
    return [];
  }
}
