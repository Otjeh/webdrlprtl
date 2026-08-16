import 'package:webdlrprtl01/services/supabase_service.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  Future<int> notifyRegisteredUsers({
    required Map<String, dynamic> journey,
    required String sender,
  }) {
    return SupabaseService.instance.createJourneyNotifications(
      journey: journey,
      sender: sender,
    );
  }
}
