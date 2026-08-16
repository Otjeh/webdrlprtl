import 'package:flutter_test/flutter_test.dart';
import 'package:webdlrprtl01/models/product_journey_row.dart';
import 'package:webdlrprtl01/models/approval_decision.dart';
import 'package:webdlrprtl01/services/supabase_service.dart';

void main() {
  test('ProductJourneyRow parses Supabase timestamps and status', () {
    final row = ProductJourneyRow.fromJson({
      'id': 'P-1001',
      'product_id': 'P-1001',
      'state': 'Allocated',
      'actor': 'dlr.DDD-dist-adm.BBB',
      'initiator': 'dealer distribution admin',
      'loa': 'LoA1',
      'status': 'pending',
      'approved_by': null,
      'created_at': '2026-08-14T12:00:00.000Z',
      'updated_at': '2026-08-14T12:05:00.000Z',
    });

    expect(row.id, 'P-1001');
    expect(row.state, 'Allocated');
    expect(row.status, 'pending');
    expect(row.createdAt, isNotNull);
  });

  test('ApprovalDecision parses a decision record from Supabase', () {
    final decision = ApprovalDecision.fromJson({
      'id': 'AD-001',
      'journey_id': 'P-1001',
      'decision': 'approved',
      'approver_name': 'Dealer Manager',
      'approver_role': 'Dealer Distribution Manager',
      'comment': 'Approved after validation',
      'created_at': '2026-08-14T12:10:00.000Z',
      'updated_at': '2026-08-14T12:10:00.000Z',
    });

    expect(decision.id, 'AD-001');
    expect(decision.decision, 'approved');
    expect(decision.approverName, 'Dealer Manager');
    expect(decision.createdAt, isNotNull);
  });

  test(
    'demo administrator credentials are accepted only in demo mode',
    () async {
      final service = SupabaseService.instance;

      expect(SupabaseService.isDemoMode, isTrue);
      expect(
        await service.signInAsAdministrator(
          email: SupabaseService.demoAdministratorEmail,
          password: SupabaseService.demoAdministratorPassword,
        ),
        isTrue,
      );
      expect(
        await service.signInAsAdministrator(
          email: SupabaseService.demoAdministratorEmail,
          password: 'wrong-password',
        ),
        isFalse,
      );
    },
  );

  test(
    'created catalog journeys are active and routed to a dealer manager',
    () async {
      final journey = await SupabaseService.instance.createProductJourney(
        productId: 'CO-TEST',
        productName: 'Cooking Essential',
        category: 'Cooking',
        initiator: 'Dealer Distribution Manager',
        actor: 'Dealer Distribution Manager',
        action: 'order',
      );

      expect(journey['state'], 'Ordered');
      expect(journey['status'], 'pending');
      expect(journey['initiator'], 'Dealer Distribution Manager');
      expect(journey['actor'], 'Dealer Distribution Manager');
    },
  );

  test('predefined roles are loaded from the portal role catalog', () async {
    final roles = await SupabaseService.instance.fetchPortalRoles();
    final names = roles.map((role) => role['role']).toList();

    expect(names, contains('Warehouse Manager'));
    expect(names, contains('Logistics Manager'));
    expect(
      roles.firstWhere(
        (role) => role['role'] == 'Dealer Distribution Admin',
      )['access'],
      'Allocate / Accept delivery',
    );
  });

  test('journey notifications are created for the assigned role', () async {
    final count = await SupabaseService.instance.createJourneyNotifications(
      journey: {
        'id': 'P-NOTIFY-001',
        'product_id': 'CO-001',
        'product_name': 'Cooking Essential',
        'actor': 'dlr.DDD-dist-mgr.CCC',
      },
      sender: 'dealer.admin@gmail.com',
    );

    expect(count, 1);
  });
}
