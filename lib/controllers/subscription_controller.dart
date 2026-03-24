import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../models/subscription_tier.dart';
import '../services/firebase_service.dart';

/// Controller that reflects the user's subscription tier from Firestore.
class SubscriptionController extends GetxController {
  final FirebaseService _firebase = FirebaseService();

  StreamSubscription? _tierSub;
  String? _listeningToUid;

  final Rx<SubscriptionTier> currentTier = SubscriptionTier.free.obs;

  // Entitlements
  bool get isFree => currentTier.value == SubscriptionTier.free;

  bool get canSync =>
      currentTier.value == SubscriptionTier.plus ||
      currentTier.value == SubscriptionTier.pro ||
      currentTier.value == SubscriptionTier.proPlus;

  bool get needsOwnKeys =>
      currentTier.value == SubscriptionTier.free ||
      currentTier.value == SubscriptionTier.plus;

  bool get isPro =>
      currentTier.value == SubscriptionTier.pro ||
      currentTier.value == SubscriptionTier.proPlus;

  bool get isPlus => currentTier.value == SubscriptionTier.plus;

  // Vertex AI Access
  bool get hasManagedVertexAI =>
      currentTier.value == SubscriptionTier.pro ||
      currentTier.value == SubscriptionTier.proPlus;

  @override
  void onInit() {
    super.onInit();
    ever(_firebase.currentUser, (_) => _refreshTier());
    _refreshTier();
  }

  @override
  void onClose() {
    _tierSub?.cancel();
    super.onClose();
  }

  Future<void> _refreshTier() async {
    final user = _firebase.currentUser.value;
    if (user == null) {
      currentTier.value = SubscriptionTier.free;
      _tierSub?.cancel();
      _listeningToUid = null;
      return;
    }
    currentTier.value = await _firebase.getUserSubscriptionTier(user.uid);
    _listenToTierChanges(user.uid);
  }

  void _listenToTierChanges(String uid) {
    if (_listeningToUid == uid) return; // already listening to this user
    _tierSub?.cancel();
    _listeningToUid = uid;
    _tierSub = _firebase
        .userTierStream(uid)
        .listen(
          (tier) => currentTier.value = tier,
          onError: (e) => debugPrint('Tier stream error: $e'),
        );
  }

  /// Called by [PurchaseService] after a successful purchase.
  void setTier(SubscriptionTier tier) {
    currentTier.value = tier;
  }
}
