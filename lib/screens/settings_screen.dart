
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:personal_finance_app_00/services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          // Top-right theme toggle (sun / half-moon) — accessible, keyboard-friendly
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _ThemeToggleButton(),
          ),
        ],
      ),
      body: const Center(
        child: Text('Theme settings are in the app bar.'),
      ),
    );
  }
}

// Small, private widget that shows a sun icon in Light mode and a half-moon in Dark mode.
// - AnimatedSwitcher for smooth icon transitions
// - FocusableActionDetector so Enter/Space toggle the theme
// - Tooltip and Semantics for accessibility
// - Visible focus outline for keyboard users
class _ThemeToggleButton extends StatefulWidget {
  @override
  State<_ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<_ThemeToggleButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // Listen to ThemeService to rebuild when theme changes
    final themeService = Provider.of<ThemeService>(context);
    final isDark = themeService.isDarkMode;

    final semanticLabel = isDark ? 'Switch to Light mode' : 'Switch to Dark mode';

    // Choose icon and color (keeps good contrast on AppBar)
    final icon = isDark ? Icons.nightlight_round : Icons.wb_sunny;
    // Use the AppBar's foregroundColor for the icon. This ensures the icon is always
    // visible against the AppBar's background, regardless of the theme.
    final iconColor = Theme.of(context).appBarTheme.foregroundColor;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: FocusableActionDetector(
        // Allow Enter and Space to activate (non-const to allow LogicalKeySet runtime constructor)
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
          LogicalKeySet(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<Intent>(onInvoke: (intent) {
            themeService.toggleTheme();
            return null;
          }),
        },
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        child: Tooltip(
          message: semanticLabel,
          child: Padding(
            padding: const EdgeInsets.all(6.0), // spacing to avoid accidental clicks
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // show an outline when focused for keyboard users
                border: _focused
                    ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2.0)
                    : null,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween<double>(begin: 0.8, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: IconButton(
                  key: ValueKey<bool>(isDark),
                  icon: Icon(icon, size: 22.0),
                  color: iconColor,
                  onPressed: () => themeService.toggleTheme(),
                  tooltip: semanticLabel,
                  splashRadius: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
