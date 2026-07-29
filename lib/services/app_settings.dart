import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences (theme, labels, capture). Persisted locally.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _kTheme = 'theme_mode';
  static const _kLabels = 'option_labels';
  static const _kImageQuality = 'image_quality';
  static const _kDefaultOptions = 'default_options_count';

  ThemeMode themeMode = ThemeMode.system;
  /// 'bn' or 'en'
  String optionLabelLang = 'bn';
  int imageQuality = 95;
  int defaultOptionsCount = 4;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final theme = p.getString(_kTheme) ?? 'system';
    themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    optionLabelLang = p.getString(_kLabels) ?? 'bn';
    imageQuality = p.getInt(_kImageQuality) ?? 95;
    defaultOptionsCount = p.getInt(_kDefaultOptions) ?? 4;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _kTheme,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
    notifyListeners();
  }

  Future<void> setOptionLabelLang(String lang) async {
    optionLabelLang = lang;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLabels, lang);
    notifyListeners();
  }

  Future<void> setImageQuality(int q) async {
    imageQuality = q.clamp(50, 100);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kImageQuality, imageQuality);
    notifyListeners();
  }

  Future<void> setDefaultOptionsCount(int n) async {
    defaultOptionsCount = n;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kDefaultOptions, n);
    notifyListeners();
  }

  List<String> get optionLabels {
    const bn = ['ক', 'খ', 'গ', 'ঘ', 'ঙ'];
    const en = ['A', 'B', 'C', 'D', 'E'];
    return optionLabelLang == 'en' ? en : bn;
  }
}
