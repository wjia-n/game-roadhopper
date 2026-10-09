import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/roadhopper_themes.dart';

/// Persisted settings + stats for Road Hopper. Survives app restarts.
///
/// EVERYTHING lives in a single JSON string under [_kState]. Never use
/// setStringList for ordered data — Android backs StringList with an unordered
/// StringSet and scrambles the order on restart.
///
/// Player profile names live in ONE order-preserving JSON string under
/// [_kNames] (`roadhopper_player_names_json`) via setString — a JSON array of
/// name strings, saved on EVERY keystroke and committed on focus loss.
/// Legacy migration: the v1 build stored `roadhopper_best` as a plain int;
/// any older name keys (`roadhopper_name`, `roadhopper_names`,
/// `roadhopper_player_name`, or `playerName` inside the state blob) are folded
/// into [_kNames] on first load and the old keys removed.
class HopperSettings extends ChangeNotifier {
  static const _kState = 'roadhopper_state_json';
  static const _kNames = 'roadhopper_player_names_json';
  static const _kLegacyBest = 'roadhopper_best';
  static const _kLegacyNameKeys = [
    'roadhopper_name',
    'roadhopper_player_name',
  ];
  static const _kLegacyListKey = 'roadhopper_names';

  static const defaultPlayerName = 'Hopper';

  static const difficultyNames = ['Stroll', 'Street', 'Rush Hour'];
  static const difficultyBlurb = [
    'Relaxed pace, generous clock',
    'The classic crossing',
    'PRO · Fast lanes, tight clock',
  ];
  static const modeNames = ['Classic', 'Endless', 'Score Attack'];
  static const modeBlurb = [
    'Fill all 5 homes to level up · 3 lives',
    'No clock, endless homes · 3 lives',
    '90 seconds · deaths cost 25 pts',
  ];

  static const Map<String, int> _defaultCustomColors = {
    'bank': 0xFF3E9E4F,
    'road': 0xFF3A3F45,
    'river': 0xFF2E8BC9,
    'accent': 0xFFFFB020,
  };

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String playerName = defaultPlayerName;
  String themeId = 'meadow';
  int hopperStyle = 0;
  int customHopperBody = 0xFF51CF66;
  int customHopperBelly = 0xFFD3F9D8;
  int difficulty = 1; // 0 stroll, 1 street, 2 rush hour (pro)
  int mode = 0; // 0 classic, 1 endless, 2 score attack
  bool isPro = false;

  int bestClassic = 0;
  int bestEndless = 0;
  int bestScoreAttack = 0;
  int gamesPlayed = 0;
  int totalHops = 0;
  int homesFilled = 0;
  int levelsCleared = 0;

  Map<String, int> customColors = Map.of(_defaultCustomColors);

  HopperThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return HopperThemeDef(
      id: 'custom',
      name: 'My Crossing',
      bank: c('bank'),
      bankDark: _darken(c('bank')),
      road: c('road'),
      roadDark: _darken(c('road')),
      laneLine: const Color(0xFFF5D76E),
      river: c('river'),
      riverDeep: _darken(c('river')),
      log: const Color(0xFF8B5E34),
      logLight: const Color(0xFFB07B45),
      turtle: const Color(0xFF4CAF50),
      carColors: const [
        Color(0xFFE05252),
        Color(0xFF4A90D9),
        Color(0xFFF5A623),
        Color(0xFF9B59B6),
      ],
      homeEmpty: _darken(c('bank')),
      homeFull: const Color(0xFFFFD43B),
      lily: c('bank'),
      uiDeep: const Color(0xFF14231A),
      uiMid: const Color(0xFF1E3325),
      panel: const Color(0xFF274431),
      accent: c('accent'),
      accentLight: const Color(0xFFFFD47A),
      accentDark: _darken(c('accent')),
      ivory: const Color(0xFFF7F3E6),
      muted: const Color(0xFF9DB3A4),
    );
  }

  static Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - 0.18).clamp(0.0, 1.0).toDouble()).toColor();
  }

  SharedPreferences? _prefs;

  Map<String, dynamic> _toJson() => {
        'musicOn': musicOn,
        'sfxOn': sfxOn,
        'volume': volume,
        'playerName': playerName,
        'themeId': themeId,
        'hopperStyle': hopperStyle,
        'customHopperBody': customHopperBody,
        'customHopperBelly': customHopperBelly,
        'difficulty': difficulty,
        'mode': mode,
        'isPro': isPro,
        'bestClassic': bestClassic,
        'bestEndless': bestEndless,
        'bestScoreAttack': bestScoreAttack,
        'gamesPlayed': gamesPlayed,
        'totalHops': totalHops,
        'homesFilled': homesFilled,
        'levelsCleared': levelsCleared,
        'customColors': customColors,
      };

  void _fromJson(Map<String, dynamic> j) {
    bool b(String k, bool d) => j[k] is bool ? j[k] as bool : d;
    int i(String k, int d) => j[k] is int ? j[k] as int : d;
    double dv(String k, double d) =>
        j[k] is num ? (j[k] as num).toDouble() : d;
    String s(String k, String d) =>
        j[k] is String && (j[k] as String).trim().isNotEmpty
            ? (j[k] as String)
            : d;

    musicOn = b('musicOn', true);
    sfxOn = b('sfxOn', true);
    volume = dv('volume', 0.8).clamp(0.0, 1.0).toDouble();
    playerName = s('playerName', defaultPlayerName);
    themeId = s('themeId', 'meadow');
    hopperStyle = i('hopperStyle', 0).clamp(0, 10).toInt(); // 10 = custom creator
    customHopperBody = i('customHopperBody', 0xFF51CF66);
    customHopperBelly = i('customHopperBelly', 0xFFD3F9D8);
    difficulty = i('difficulty', 1).clamp(0, 2).toInt();
    mode = i('mode', 0).clamp(0, 2).toInt();
    isPro = b('isPro', false);
    bestClassic = i('bestClassic', 0);
    bestEndless = i('bestEndless', 0);
    bestScoreAttack = i('bestScoreAttack', 0);
    gamesPlayed = i('gamesPlayed', 0);
    totalHops = i('totalHops', 0);
    homesFilled = i('homesFilled', 0);
    levelsCleared = i('levelsCleared', 0);
    final cc = j['customColors'];
    if (cc is Map) {
      for (final k in _defaultCustomColors.keys) {
        final v = cc[k];
        if (v is int) customColors[k] = v;
      }
    }
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    final raw = p.getString(_kState);
    if (raw != null) {
      try {
        final d = jsonDecode(raw);
        if (d is Map<String, dynamic>) _fromJson(d);
      } catch (_) {}
    }
    _migrateNames(p);
    // One-time legacy migration: v1 stored best score as a plain int.
    final legacyBest = p.getInt(_kLegacyBest);
    if (legacyBest != null) {
      if (legacyBest > bestClassic) bestClassic = legacyBest;
      await p.remove(_kLegacyBest);
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  /// Name loading + migration. [_kNames] (JSON array) is authoritative when
  /// present. Otherwise we fold every legacy name key into it — once — and
  /// remove the old keys.
  void _migrateNames(SharedPreferences p) {
    String? fromNamesKey;
    final namesRaw = p.getString(_kNames);
    if (namesRaw != null) {
      try {
        final d = jsonDecode(namesRaw);
        if (d is List && d.isNotEmpty && d.first is String) {
          final n = (d.first as String).trim();
          if (n.isNotEmpty) fromNamesKey = n;
        }
      } catch (_) {}
    }
    if (fromNamesKey != null) {
      playerName = fromNamesKey;
      for (final k in [..._kLegacyNameKeys, _kLegacyListKey]) {
        p.remove(k);
      }
      return;
    }
    // Legacy fallbacks, in order of trustworthiness.
    String? legacy;
    final stateName = playerName; // possibly from the state blob
    final legacyList = p.getStringList(_kLegacyListKey);
    if (legacyList != null) {
      for (final n in legacyList) {
        if (n.trim().isNotEmpty) {
          legacy = n.trim();
          break;
        }
      }
    }
    legacy ??= () {
      for (final k in _kLegacyNameKeys) {
        final v = p.getString(k);
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }();
    legacy ??= stateName != defaultPlayerName ? stateName : null;
    if (legacy != null && legacy.isNotEmpty) {
      playerName = legacy;
    }
    // Persist into the canonical key and drop the legacy keys.
    _saveNames();
    for (final k in [..._kLegacyNameKeys, _kLegacyListKey]) {
      p.remove(k);
    }
  }

  /// Write the canonical names JSON immediately — called on every keystroke.
  Future<void> _saveNames() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kNames, jsonEncode([playerName]));
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kState, jsonEncode(_toJson()));
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || HopperThemes.isProTheme(themeId)) {
      themeId = 'meadow';
      changed = true;
    }
    if (hopperStyle == 10 || HopperStyles.isPro(hopperStyle)) {
      hopperStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  int bestForMode(int m) =>
      m == 1 ? bestEndless : (m == 2 ? bestScoreAttack : bestClassic);

  Future<void> recordGame(
      {required int score,
      required int mode,
      required int hops,
      required int homes,
      required int levels}) async {
    gamesPlayed++;
    totalHops += hops;
    homesFilled += homes;
    levelsCleared += levels;
    if (mode == 1) {
      if (score > bestEndless) bestEndless = score;
    } else if (mode == 2) {
      if (score > bestScoreAttack) bestScoreAttack = score;
    } else {
      if (score > bestClassic) bestClassic = score;
    }
    notifyListeners();
    await _save();
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0).toDouble();
    notifyListeners();
    await _save();
  }

  /// Save on every keystroke (the UI calls this from onChanged). Also writes
  /// the canonical `roadhopper_player_names_json` JSON string immediately.
  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? defaultPlayerName : clean;
    notifyListeners();
    await _saveNames();
    await _save();
  }

  Future<void> setTheme(String id) async {
    if (!isPro && (id == 'custom' || HopperThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setHopperStyle(int id) async {
    id = id.clamp(0, 10).toInt(); // 10 = custom hopper creator (Pro)
    if (!isPro && (id == 10 || HopperStyles.isPro(id))) return;
    hopperStyle = id;
    notifyListeners();
    await _save();
  }

  Future<void> setCustomHopper(int body, int belly) async {
    if (!isPro) return;
    customHopperBody = body;
    customHopperBelly = belly;
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int d) async {
    d = d.clamp(0, 2).toInt();
    if (!isPro && d > 1) return; // Rush Hour is a Pro tier
    difficulty = d;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int m) async {
    mode = m.clamp(0, 2).toInt();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }
}
