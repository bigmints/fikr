import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:toastification/toastification.dart';

class ToastService {
  static void showSuccess(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      description: description != null ? Text(description) : null,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 4),
      icon: const Icon(FeatherIcons.checkCircle),
      borderRadius: BorderRadius.circular(12),
      showProgressBar: false,
    );
  }

  static void showError(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flat,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      description: description != null ? Text(description) : null,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 4),
      icon: const Icon(FeatherIcons.alertCircle),
      borderRadius: BorderRadius.circular(12),
      showProgressBar: false,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.flat,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      description: description != null ? Text(description) : null,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 4),
      icon: const Icon(FeatherIcons.info),
      borderRadius: BorderRadius.circular(12),
      showProgressBar: false,
    );
  }
}
