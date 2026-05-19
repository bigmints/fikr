import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import '../services/fikr_api_service.dart';

/// UsageController — manages real-time word quota state for Plus/Pro users.
///
/// Registered in main.dart after AppController.
/// Refreshed:
///   - on init (app launch)
///   - after every AI operation (via patchFromResponse)
///   - on plan change (ever() listener)
class UsageController extends GetxController {
  final _api = FikrApiService();

  final Rx<FikrUsageStats?> stats   = Rx<FikrUsageStats?>(null);
  final RxBool              loading = false.obs;
  final RxBool              hasError = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUsage();
  }

  /// Fetch full usage stats from GET /api/user/usage.
  Future<void> fetchUsage() async {
    loading.value  = true;
    hasError.value = false;
    try {
      final s = await _api.getUsageStats();
      stats.value = s;
    } catch (e) {
      hasError.value = true;
      debugPrint('UsageController.fetchUsage: $e');
    } finally {
      loading.value = false;
    }
  }

  /// Patch usage state from the inline `usage` field returned by every AI route.
  /// No network call — keeps state fresh without a round-trip.
  void patchFromResponse(Map<String, dynamic>? usagePayload) {
    if (usagePayload == null || stats.value == null) return;
    final current = stats.value!;
    stats.value = current.copyWith(
      wordsUsed:      (usagePayload['wordsUsed']      as int?)      ?? current.wordsUsed,
      wordsRemaining: (usagePayload['wordsRemaining'] as int?)      ?? current.wordsRemaining,
      percentUsed:    (usagePayload['percentUsed']    as double?)   ?? current.percentUsed,
    );
  }

  bool get isUnlimited  => stats.value?.isUnlimited  ?? true;
  bool get isNearLimit  => stats.value?.isNearLimit   ?? false;
  bool get isAtLimit    => stats.value?.isAtLimit     ?? false;
  double get pct        => stats.value?.percentUsed   ?? 0.0;
}
