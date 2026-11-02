import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Deep navy background, layered slate surfaces and a blue→indigo accent.
abstract final class AppColors {
  static const background = Color(0xFF0E1117);
  static const surface = Color(0xFF181D27);
  static const surfaceHigh = Color(0xFF222938);
  static const navBar = Color(0xFF151A23);
  static const divider = Color(0xFF2A3241);
  static const outline = Color(0x1AFFFFFF);
  static const primary = Color(0xFF3B82F6);
  static const primaryDark = Color(0xFF2563EB);
  static const indigo = Color(0xFF6366F1);
  static const cyan = Color(0xFF22D3EE);
  static const textMuted = Color(0xFF94A0B4);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF5B82E);
  static const danger = Color(0xFFEF4444);
}

abstract final class AppGradients {
  static const primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.indigo],
  );

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1D4ED8), Color(0xFF4F46E5), Color(0xFF7C3AED)],
  );
}

abstract final class AppRadius {
  static const card = 20.0;
  static const field = 14.0;
}

/// Set to false in widget tests, where fonts can't be downloaded.
bool useGoogleFonts = true;

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.indigo,
    surface: AppColors.background,
    onSurface: Colors.white,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerHighest: AppColors.surface,
    primaryContainer: AppColors.primaryDark,
    onPrimaryContainer: Colors.white,
    outline: AppColors.divider,
    error: AppColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: Brightness.dark,
  );
  final TextTheme textTheme = useGoogleFonts
      ? GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
      : base.textTheme;

  OutlineInputBorder field(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        borderSide: BorderSide(color: color, width: width),
      );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.field),
  );

  return base.copyWith(
    textTheme: textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.divider,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      labelStyle: const TextStyle(color: AppColors.textMuted),
      prefixIconColor: AppColors.textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: field(AppColors.outline),
      enabledBorder: field(AppColors.outline),
      focusedBorder: field(AppColors.primary, 1.6),
      errorBorder: field(AppColors.danger),
      focusedErrorBorder: field(AppColors.danger, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: rounded,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 6,
      extendedTextStyle: TextStyle(fontWeight: FontWeight.w700),
      shape: StadiumBorder(),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.outline),
      ),
      titleTextStyle: textTheme.titleLarge?.copyWith(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: AppColors.outline),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.navBar,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withValues(alpha: 0.18),
      indicatorShape: const StadiumBorder(),
      height: 72,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.textMuted,
        ),
      ),
    ),
  );
}

/// Full-width pill button with the accent gradient and a soft glow, for a screen's main action.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: AppGradients.primary,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: SizedBox(
              height: 58,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon on a soft tinted rounded square — the app's standard icon badge.
class TintedIcon extends StatelessWidget {
  const TintedIcon(this.icon, {super.key, required this.color, this.size = 48});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// Tile with a tinted icon badge and a caption underneath ("Hızlı Erişim").
class QuickAction extends StatelessWidget {
  const QuickAction({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TintedIcon(icon, color: color, size: 64),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card with a tinted icon badge, a bold title and a short description.
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TintedIcon(icon, color: color, size: 52),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Left-aligned section title with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action!),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The app's own mark: a gradient rounded badge with a calendar icon and the app name.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.large = false});

  final bool large;

  @override
  Widget build(BuildContext context) {
    final badge = large ? 60.0 : 40.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: badge,
          height: badge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(badge * 0.3),
            gradient: AppGradients.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.indigo.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.event_available_rounded,
            color: Colors.white,
            size: badge * 0.55,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dijital Randevu',
              style: TextStyle(
                fontSize: large ? 24 : 17,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Asistanı',
              style: TextStyle(
                fontSize: large ? 14 : 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Soft coloured glows behind a screen, for depth on otherwise flat dark pages.
class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget glow(Color color, double size) => IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Positioned(top: -120, left: -80, child: glow(AppColors.primary, 360)),
        Positioned(top: 80, right: -140, child: glow(AppColors.indigo, 320)),
        Positioned.fill(child: child),
      ],
    );
  }
}

void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$feature yakında eklenecek.')));
}
