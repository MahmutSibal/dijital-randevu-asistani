import 'package:flutter/material.dart';

import '../core/accessibility.dart';
import '../theme/app_theme.dart';

class AccessibilityScreen extends StatelessWidget {
  const AccessibilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: accessibility,
      builder: (context, _) {
        final a = accessibility;
        return Scaffold(
          appBar: AppBar(title: const Text('Erişilebilirlik')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              const SectionHeader('Yazı boyutu'),
              SegmentedButton<double>(
                segments: [
                  for (var i = 0; i < AccessibilitySettings.scales.length; i++)
                    ButtonSegment(
                      value: AccessibilitySettings.scales[i],
                      label: Text(AccessibilitySettings.scaleLabels[i]),
                      icon: Icon(Icons.text_fields_rounded, size: 16 + i * 4.0),
                    ),
                ],
                selected: {a.textScale},
                showSelectedIcon: false,
                onSelectionChanged: (s) => a.update(textScale: s.first),
              ),
              const SizedBox(height: 20),
              const SectionHeader('Görünüm'),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: a.boldText,
                      onChanged: (v) => a.update(boldText: v),
                      secondary: const TintedIcon(
                        Icons.format_bold_rounded,
                        color: AppColors.primary,
                        size: 40,
                      ),
                      title: const Text('Kalın yazı'),
                      subtitle: const Text(
                        'Tüm metinler daha kalın gösterilir.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    SwitchListTile(
                      value: a.highContrast,
                      onChanged: (v) => a.update(highContrast: v),
                      secondary: const TintedIcon(
                        Icons.contrast_rounded,
                        color: AppColors.warning,
                        size: 40,
                      ),
                      title: const Text('Yüksek kontrast'),
                      subtitle: const Text(
                        'Renkler ve gri metinler daha belirgin olur.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader('Önizleme'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          TintedIcon(
                            Icons.event_rounded,
                            color: AppColors.warning,
                            size: 40,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Kardiyoloji randevunuz',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Yarın 10:00 · Uzm. Dr. Ayşe Yılmaz',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 14),
                      GradientButton(
                        label: 'Randevuya Git',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => a.update(
                  textScale: 1.0,
                  boldText: false,
                  highContrast: false,
                ),
                child: const Text('Varsayılana dön'),
              ),
            ],
          ),
        );
      },
    );
  }
}
