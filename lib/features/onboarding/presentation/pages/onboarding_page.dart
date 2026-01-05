import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../theme/app_colors.dart';

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
      icon: Icons.center_focus_strong_rounded,
      title: 'Scan & Localize',
      description:
          'Scan your surroundings with your camera to instantly pinpoint your precise indoor location.',
    ),
    OnboardingItem(
      icon: Icons.map_outlined,
      title: 'Select Destination',
      description:
          'Browse our detailed indoor maps and select exactly where you want to go.',
    ),
    OnboardingItem(
      icon: Icons.turn_right_rounded,
      title: 'Precision Navigation',
      description:
          'Follow the intuitive path to your destination with real-time, step-by-step guidance.',
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

  void _goToNextPage() {
    if (_currentPage < _items.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/login');
    }
  }

  void _skipOnboarding() {
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            buildSkipButton(context),
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
            buildIndicators(context),
            buildActionButton(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget buildSkipButton(BuildContext context) {
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
              'Skip',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildIndicators(BuildContext context) {
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
                ? theme.primaryColor
                : theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget buildActionButton(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _goToNextPage,
          style: theme.elevatedButtonTheme.style?.copyWith(
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _currentPage == _items.length - 1 ? 'Get Started' : 'Next',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_currentPage != _items.length - 1) ...[
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 20),
              ],
            ],
          ),
        ),
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
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? AppColors.secondary
                  : theme.primaryColor.withValues(alpha: 0.05),
              border: Border.all(
                color: theme.primaryColor.withValues(
                  alpha: isDark ? 0.05 : 0.1,
                ),
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: theme.primaryColor.withValues(alpha: 0.1),
                        blurRadius: 40,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: Icon(item.icon, size: 80, color: theme.primaryColor),
          ),
          const SizedBox(height: 60),
          Text(
            item.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            item.description,
            style: TextStyle(
              fontSize: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
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
