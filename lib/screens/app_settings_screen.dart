import 'package:flutter/material.dart';
import '../services/app_settings.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('App settings')),
          body: ListView(
            children: [
              const _SectionHeader('Appearance'),
              ListTile(
                title: const Text('Theme'),
                subtitle: Text(switch (settings.themeMode) {
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                  ThemeMode.system => 'System',
                }),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => settings.setThemeMode(s.first),
                ),
              ),
              const SizedBox(height: 8),
              const _SectionHeader('Option labels'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'bn', label: Text('ক খ গ ঘ')),
                    ButtonSegment(value: 'en', label: Text('A B C D')),
                  ],
                  selected: {settings.optionLabelLang},
                  onSelectionChanged: (s) => settings.setOptionLabelLang(s.first),
                ),
              ),
              const SizedBox(height: 8),
              const _SectionHeader('Capture'),
              ListTile(
                title: const Text('Photo quality'),
                subtitle: Text('${settings.imageQuality}% — higher is sharper, larger files'),
              ),
              Slider(
                min: 60,
                max: 100,
                divisions: 8,
                label: '${settings.imageQuality}%',
                value: settings.imageQuality.toDouble(),
                onChanged: (v) => settings.setImageQuality(v.round()),
              ),
              const _SectionHeader('Defaults for new exams'),
              ListTile(
                title: const Text('Options per question'),
                subtitle: Text('${settings.defaultOptionsCount} options'),
                trailing: DropdownButton<int>(
                  value: settings.defaultOptionsCount,
                  items: const [2, 3, 4, 5]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) settings.setDefaultOptionsCount(v);
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
