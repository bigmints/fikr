import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/app_controller.dart';
import '../../controllers/subscription_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../services/firebase_service.dart';
import '../../services/sync_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/collapsing_header.dart';
import '../../utils/app_spacing.dart';

import 'provider_detail_screen.dart';
import 'widgets/fikr_cloud_banner.dart';

class MobileSettings extends StatelessWidget {
  const MobileSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final themeController = Get.find<ThemeController>();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Obx(() {
      final user = FirebaseService().currentUser.value;
      final isAnonymous = user?.isAnonymous ?? true;
      final isLoggedIn = user != null && !isAnonymous;

      return CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: CollapsingSliverHeader(
              title: 'Settings',
              topPadding: topPadding,
              isDark: isDark,
              subtitle: 'Customize your experience',
              gradientColors: isDark
                  ? const [
                      Color(0xFF9E3DFF),
                      Color(0xFFC084FC),
                      Color(0xFFF472B6),
                    ]
                  : const [
                      Color(0xFF7C3AED),
                      Color(0xFF9333EA),
                      Color(0xFFDB2777),
                    ],
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.pageHorizontal,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                children: [
                  // ── Fikr Cloud ──
                  _SectionHeader(title: 'Fikr Cloud'),
                  if (!isLoggedIn)
                    const FikrCloudBanner()
                  else
                    _SettingsGroup(
                      children: [
                        Obx(() {
                          final sync = Get.find<SyncService>();
                          final sub = Get.find<SubscriptionController>();
                          final String label;
                          if (sync.isSyncing.value) {
                            label = 'Syncing…';
                          } else if (sync.syncError.value.isNotEmpty) {
                            label = 'Sync error';
                          } else if (sync.lastSyncTime.value != null) {
                            label = 'Synced';
                          } else {
                            label = sub.currentTier.value.name[0].toUpperCase() +
                                sub.currentTier.value.name.substring(1);
                          }
                          return _SettingsRow(
                            icon: FeatherIcons.user,
                            title: user.email ?? 'Signed In',
                            value: label,
                          );
                        }),
                        if (Get.find<SubscriptionController>().canSync)
                          Obx(() {
                            final sync = Get.find<SyncService>();
                            final syncing = sync.isSyncing.value;
                            return ListTile(
                              leading: Icon(
                                FeatherIcons.uploadCloud,
                                size: 20,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                              title: Text(
                                syncing
                                    ? 'Syncing…'
                                    : sync.lastSyncTime.value != null &&
                                            sync.syncError.value.isEmpty
                                        ? 'Everything synced'
                                        : 'Sync Now',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              trailing: syncing
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                    )
                                  : sync.lastSyncTime.value != null &&
                                          sync.syncError.value.isEmpty
                                      ? Icon(
                                          Icons.check_circle_rounded,
                                          size: 18,
                                          color: Colors.green.shade500,
                                        )
                                      : Icon(
                                          FeatherIcons.chevronRight,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.3),
                                        ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              onTap: syncing ||
                                      (sync.lastSyncTime.value != null &&
                                          sync.syncError.value.isEmpty)
                                  ? null
                                  : () async {
                                      await sync.syncToCloud();
                                      if (context.mounted) {
                                        if (sync.syncError.value.isEmpty) {
                                          ToastService.showSuccess(
                                            context,
                                            title: 'Synced',
                                            description:
                                                'Your notes are up to date.',
                                          );
                                        } else {
                                          ToastService.showError(
                                            context,
                                            title: 'Sync Failed',
                                            description:
                                                'Could not reach the server. Try again.',
                                          );
                                        }
                                      }
                                    },
                            );
                          }),
                        _SettingsRow(
                          icon: FeatherIcons.logOut,
                          title: 'Sign Out',
                          isDestructive: true,
                          onTap: () async {
                            await FirebaseService().signOut();
                            if (context.mounted) {
                              ToastService.showSuccess(
                                context,
                                title: 'Signed Out',
                                description: 'Cloud sync disabled.',
                              );
                            }
                          },
                        ),
                      ],
                    ),

                  const SizedBox(height: 28),

                  // ── AI Service (Free & Plus only — Pro users have managed AI) ──
                  if (!isLoggedIn || Get.find<SubscriptionController>().needsOwnKeys) ...[
                    _SectionHeader(title: 'AI Service'),
                    _SettingsGroup(
                      children: [
                        Obx(() {
                          final provider = controller.config.value.activeProvider;
                          return _SettingsRow(
                            icon: FeatherIcons.cpu,
                            title: 'AI Provider',
                            value: provider?.name ?? 'Not set',
                            onTap: () => Get.to(
                              () => ProviderDetailScreen(provider: provider),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ── Preferences ──
                  _SectionHeader(title: 'Preferences'),
                  _SettingsGroup(
                    children: [
                      Obx(() {
                        final mode = themeController.themeMode.value;
                        final label = switch (mode) {
                          ThemeMode.system => 'Auto',
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                        };
                        return _SettingsRow(
                          icon: FeatherIcons.sun,
                          title: 'Theme',
                          value: label,
                          onTap: () => _showThemePicker(
                            context,
                            themeController,
                            controller,
                          ),
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 28),


                  // ── Data ──
                  _SectionHeader(title: 'Data'),
                  _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: FeatherIcons.download,
                        title: 'Export Data',
                        onTap: () async {
                          final dir = await controller.pickExportDirectory();
                          if (dir != null) await controller.exportAll(dir);
                        },
                      ),
                      _SettingsRow(
                        icon: FeatherIcons.trash2,
                        title: 'Clear All Data',
                        isDestructive: true,
                        onTap: () => _showClearDialog(context, controller),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ── About ──
                  _SectionHeader(title: 'About'),
                  _SettingsGroup(
                    children: [
                      _SettingsRow(
                        icon: FeatherIcons.shield,
                        title: 'Privacy Policy',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.fikr.one/privacy'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      _SettingsRow(
                        icon: FeatherIcons.fileText,
                        title: 'Terms of Use',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.fikr.one/terms'),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      if (isLoggedIn)
                        _SettingsRow(
                          icon: FeatherIcons.userMinus,
                          title: 'Delete Account',
                          isDestructive: true,
                          onTap: () => _showDeleteAccountDialog(context),
                        ),
                    ],
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  // ── Theme picker bottom sheet ──
  void _showThemePicker(
    BuildContext context,
    ThemeController themeController,
    AppController controller,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Theme',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                for (final entry in {
                  ThemeMode.system: ('Auto', FeatherIcons.monitor),
                  ThemeMode.light: ('Light', FeatherIcons.sun),
                  ThemeMode.dark: ('Dark', FeatherIcons.moon),
                }.entries)
                  Obx(() {
                    final isSelected =
                        themeController.themeMode.value == entry.key;
                    return ListTile(
                      leading: Icon(entry.value.$2, size: 20),
                      title: Text(entry.value.$1),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(ctx).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        themeController.setThemeMode(entry.key);
                        controller.updateConfig(
                          controller.config.value.copyWith(
                            themeMode: entry.key.name,
                          ),
                        );
                        Navigator.pop(ctx);
                      },
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Delete account dialog ──
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This will permanently delete all your data from the cloud. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                Navigator.pop(context);
                await FirebaseService().deleteAccount();
                if (context.mounted) {
                  ToastService.showSuccess(
                    context,
                    title: 'Account Deleted',
                    description: 'Your account and data have been removed.',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ToastService.showError(
                    context,
                    title: 'Error',
                    description:
                        'Could not delete account. You might need to re-authenticate.',
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Clear data dialog ──
  void _showClearDialog(BuildContext context, AppController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Delete all notes? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

/// Small muted heading above a settings group.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.45),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// A rounded container grouping several [_SettingsRow]s with dividers.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark
        ? AppPalette.outlineDark
        : AppPalette.outlineLight;

    final items = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) {
        items.add(Divider(height: 1, indent: 52, color: dividerColor));
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppPalette.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dividerColor),
      ),
      child: Column(children: items),
    );
  }
}

/// Standard row: icon + title + optional trailing value + chevron.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.isDestructive = false,
  });
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurface;

    return ListTile(
      leading: Icon(icon, size: 20, color: color.withValues(alpha: 0.7)),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(color: color),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                value!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          Icon(
            FeatherIcons.chevronRight,
            size: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: onTap,
    );
  }
}

/// Toggle row: icon + title + Switch.
