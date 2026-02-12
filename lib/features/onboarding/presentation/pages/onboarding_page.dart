import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smart_sense/core/constants/app_text.dart';
import 'package:smart_sense/shared/widgets/premium_icon_container.dart';
import 'package:smart_sense/shared/widgets/custom_button.dart';
import 'package:smart_sense/core/services/storage_service.dart';
import 'package:smart_sense/injection.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingItem> _items = [
    OnboardingItem(
      icon: Icons.explore_rounded,
      title: AppText.onboardingTitle1,
      description: AppText.onboardingDesc1,
    ),
    OnboardingItem(
      icon: Icons.map_rounded,
      title: AppText.onboardingTitle2,
      description: AppText.onboardingDesc2,
    ),
    OnboardingItem(
      icon: Icons.camera_enhance_rounded,
      title: AppText.onboardingTitle3,
      description: AppText.onboardingDesc3,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _goToNextPage() async {
    if (_currentPage < _items.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      await _completeOnboarding();
    }
  }

  void _skipOnboarding() async {
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final storage = getIt<StorageService>();
    await storage.setBool('has_seen_onboarding', true);
    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildSkipButton(context),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageContent(item: _items[index]);
                },
              ),
            ),
            _buildIndicators(context),
            _buildActionButton(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSkipButton(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _currentPage == _items.length - 1 ? 0.0 : 1.0,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: TextButton(
            onPressed: _currentPage == _items.length - 1
                ? null
                : _skipOnboarding,
            child: Text(
              AppText.onboardingSkip,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicators(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _items.length,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 32 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: CustomButton(
        text: _currentPage == _items.length - 1
            ? AppText.onboardingGetStarted
            : AppText.onboardingNext,
        onPressed: _goToNextPage,
        icon: _currentPage == _items.length - 1
            ? null
            : Icons.arrow_forward_rounded,
      ),
    );
  }
}

class _OnboardingPageContent extends StatelessWidget {
  final OnboardingItem item;

  const _OnboardingPageContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Layered Glow Rings
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.02 : 0.04,
                  ),
                ),
              ),
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.04 : 0.06,
                  ),
                ),
              ),
              // Premium Icon in Circle Mode
              PremiumIconContainer(
                icon: item.icon,
                size: 180,
                iconSize: 84,
                isCircle: true,
              ),
            ],
          ),
          const SizedBox(height: 60),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
              letterSpacing: -1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            item.description,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.6,
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingItem {
  final IconData icon;
  final String title;
  final String description;

  OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
