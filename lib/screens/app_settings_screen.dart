import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import '../services/entitlement_service.dart';
import '../services/premium_config.dart';
import 'paywall_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    final ent = EntitlementService.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([settings, ent]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('App settings')),
          body: ListView(
            children: [
              const _SectionHeader('Premium'),
              ListTile(
                leading: Icon(
                  ent.isPremium ? Icons.workspace_premium : Icons.lock_outline,
                  color: ent.isPremium ? Colors.amber[800] : null,
                ),
                title: Text(ent.isPremium ? 'Premium active' : 'Free plan'),
                subtitle: Text(
                  ent.isPremium
                      ? 'Unlimited exams, scans, settings & exports'
                      : '${PremiumConfig.freeExamLimit} exam · '
                          '${ent.scansUsedThisMonth}/${PremiumConfig.freeScansPerMonth} scans this month · CSV only',
                ),
                trailing: ent.isPremium
                    ? null
                    : TextButton(
                        onPressed: () => PaywallScreen.open(context),
                        child: const Text('Upgrade'),
                      ),
              ),
              if (!ent.isPremium)
                ListTile(
                  title: const Text('Restore purchases'),
                  subtitle: const Text('Already bought Premium on this store account?'),
                  onTap: () async {
                    await ent.restorePurchases();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ent.isPremium
                              ? 'Premium restored'
                              : (ent.lastError ?? 'No previous purchase found')),
                        ),
                      );
                    }
                  },
                ),
              if (kDebugMode) ...[
                ListTile(
                  title: Text(ent.isPremium
                      ? '[Debug] Lock Premium'
                      : '[Debug] Unlock Premium'),
                  onTap: () async {
                    if (ent.isPremium) {
                      await ent.debugLockPremium();
                    } else {
                      await ent.debugUnlockPremium();
                    }
                  },
                ),
              ],
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
                    ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto)),
                    ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode)),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode)),
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
                subtitle: Text(
                    '${settings.imageQuality}% — higher is sharper, larger files'),
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
