import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../services/storage_service.dart';
import '../utils/assets.dart';
import 'home_shell.dart';
import 'notification_permission_screen.dart';
import 'settings/auth_screen.dart';
import 'settings/widgets/provider_setup_dialog.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  static const _pages = [
    _PageData(
      icon: FeatherIcons.mic,
      gradient: [Color(0xFF3CA6A6), Color(0xFF2DD4BF)],
      title: 'Speak your\nthoughts',
      subtitle:
          'Just talk — Fikr turns what you say into neat, organized notes you can find later.',
    ),
    _PageData(
      icon: FeatherIcons.zap,
      gradient: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
      title: 'Smart\ninsights',
      subtitle:
          'Fikr listens, writes it down, and picks out the important stuff — like a super-smart assistant.',
    ),
    _PageData(
      icon: FeatherIcons.shield,
      gradient: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      title: 'Private &\nsecure',
      subtitle:
          'Your notes stay on your phone. Nobody else can see them unless you choose to share.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Last intro page → show choice screen
      _showChoiceScreen();
    }
  }

  void _skip() async {
    await Get.find<StorageService>().setOnboardingComplete();
    if (mounted) {
      await _showNotificationPermission();
    }
  }

  void _showChoiceScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _OnboardingChoiceScreen(
          onComplete: () async {
            await Get.find<StorageService>().setOnboardingComplete();
            if (mounted) {
              await _showNotificationPermission();
            }
          },
        ),
      ),
    );
  }

  Future<void> _showNotificationPermission() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationPermissionScreen(),
        fullscreenDialog: true,
      ),
    );
    if (mounted) {
      Get.off(() => HomeShell());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 600;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    // Top bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: SvgPicture.asset(
                                  Assets.getLogo(context),
                                  colorFilter: ColorFilter.mode(
                                    isDark ? Colors.white : Colors.black,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('Fikr', style: theme.textTheme.titleSmall),
                            ],
                          ),
                          TextButton(
                            onPressed: _skip,
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Pages
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          return _OnboardingPage(
                            data: _pages[index],
                            isDark: isDark,
                            compact: isWide,
                          );
                        },
                      ),
                    ),

                    // Bottom section
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, isWide ? 24 : 32),
                      child: Column(
                        children: [
                          // Dot indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _pages.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: _currentPage == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _currentPage == index
                                      ? _pages[_currentPage].gradient[0]
                                      : theme.colorScheme.onSurface.withValues(
                                          alpha: 0.15,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // CTA button
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton(
                              onPressed: _nextPage,
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    _pages[_currentPage].gradient[0],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _currentPage == _pages.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                style: const TextStyle(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Choice Screen: Fikr Cloud vs own API key
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingChoiceScreen extends StatelessWidget {
  const _OnboardingChoiceScreen({required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(FeatherIcons.arrowLeft),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Header
                  Text(
                    'How would you\nlike to start?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can always change this later in settings.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // ── Fikr Cloud Card ──
                  _ChoiceCard(
                    icon: FeatherIcons.cloud,
                    iconGradient: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.7),
                    ],
                    title: 'Sign in to Fikr Cloud',
                    subtitle:
                        'Sync notes across devices, automatic backups, and managed AI.',
                    buttonLabel: 'Sign In',
                    buttonIcon: FeatherIcons.logIn,
                    isHighlighted: true,
                    accentColor: colorScheme.primary,
                    onTap: () async {
                      await AuthScreen.show(context);
                      // After auth, complete onboarding
                      await onComplete();
                    },
                  ),

                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: colorScheme.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: colorScheme.onSurface.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Own API Key Card ──
                  _ChoiceCard(
                    icon: FeatherIcons.key,
                    iconGradient: [
                      isDark
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFFD97706),
                      const Color(0xFFFBBF24),
                    ],
                    title: 'Use my own API key',
                    subtitle:
                        'Configure OpenAI or Gemini. Notes stay on your device.',
                    buttonLabel: 'Set Up',
                    buttonIcon: FeatherIcons.settings,
                    isHighlighted: false,
                    accentColor: isDark
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFFD97706),
                    onTap: () async {
                      final success = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => const ProviderSetupDialog(),
                          fullscreenDialog: true,
                        ),
                      );
                      if (success == true) {
                        Get.find<AppController>().refreshCanRecord();
                      }
                      await onComplete();
                    },
                  ),

                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Choice Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.iconGradient,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonIcon,
    required this.isHighlighted,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> iconGradient;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData buttonIcon;
  final bool isHighlighted;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? accentColor.withValues(alpha: 0.4)
              : colorScheme.outline.withValues(alpha: 0.15),
          width: isHighlighted ? 1.5 : 1,
        ),
        color: isHighlighted
            ? accentColor.withValues(alpha: isDark ? 0.08 : 0.03)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: iconGradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  FeatherIcons.chevronRight,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data + Page Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PageData {
  final IconData icon;
  final List<Color> gradient;
  final String title;
  final String subtitle;

  const _PageData({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
  });
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.data,
    required this.isDark,
    this.compact = false,
  });

  final _PageData data;
  final bool isDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconSize = compact ? 100.0 : 120.0;
    final iconFontSize = compact ? 40.0 : 48.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Icon
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  data.gradient[0].withValues(alpha: isDark ? 0.2 : 0.1),
                  data.gradient[1].withValues(alpha: isDark ? 0.15 : 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: data.gradient[0].withValues(alpha: 0.2),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                data.icon,
                size: iconFontSize,
                color: data.gradient[0],
              ),
            ),
          ),

          SizedBox(height: compact ? 32 : 40),

          // Title
          Text(
            data.title,
            textAlign: TextAlign.center,
            style:
                (compact
                        ? theme.textTheme.headlineMedium
                        : theme.textTheme.headlineLarge)
                    ?.copyWith(),
          ),

          SizedBox(height: compact ? 10 : 14),

          // Subtitle
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              data.subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
              ),
            ),
          ),

          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
