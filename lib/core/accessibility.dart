import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Text size, bold text and high contrast, chosen in "Erişilebilirlik" and kept on the device.
class AccessibilitySettings extends ChangeNotifier {
  static const _keyScale = 'a11y.textScale';
  static const _keyBold = 'a11y.bold';
  static const _keyContrast = 'a11y.highContrast';

  static const scales = [1.0, 1.15, 1.3];
  static const scaleLabels = ['Normal', 'Büyük', 'Çok büyük'];

  double textScale = 1.0;
  bool boldText = false;
  bool highContrast = false;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      textScale = prefs.getDouble(_keyScale) ?? 1.0;
      boldText = prefs.getBool(_keyBold) ?? false;
      highContrast = prefs.getBool(_keyContrast) ?? false;
    } catch (_) {
      // Defaults are fine.
    }
    notifyListeners();
  }

  Future<void> update({
    double? textScale,
    bool? boldText,
    bool? highContrast,
  }) async {
    this.textScale = textScale ?? this.textScale;
    this.boldText = boldText ?? this.boldText;
    this.highContrast = highContrast ?? this.highContrast;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyScale, this.textScale);
      await prefs.setBool(_keyBold, this.boldText);
      await prefs.setBool(_keyContrast, this.highContrast);
    } catch (_) {
      // Only means the choice is not remembered next launch.
    }
  }

  /// Applies the settings to everything below [child].
  Widget apply(BuildContext context, Widget child) {
    final media = MediaQuery.of(context);
    Widget result = MediaQuery(
      data: media.copyWith(
        textScaler: TextScaler.linear(textScale),
        boldText: media.boldText || boldText,
        highContrast: media.highContrast || highContrast,
      ),
      child: child,
    );
    if (highContrast) {
      // Stretch every colour away from mid-grey: muted text gets brighter, surfaces darker.
      const c = 1.45;
      const t = (1 - c) * 128;
      result = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          c, 0, 0, 0, t, //
          0, c, 0, 0, t, //
          0, 0, c, 0, t, //
          0, 0, 0, 1, 0, //
        ]),
        child: result,
      );
    }
    return result;
  }
}

final accessibility = AccessibilitySettings();
