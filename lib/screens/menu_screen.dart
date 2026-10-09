import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/roadhopper_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/roadhopper_themes.dart';
import '../theme/street_backdrop.dart';
import 'custom_theme_screen.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu — logo, PLAY, mode/difficulty setup, profile rename, hopper
/// picker, theme picker, stats, settings, share, review, PRO.
class MenuScreen extends StatefulWidget {
  final HopperAudio audio;
  final HopperSettings settings;

  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final HopperStore _store = HopperStore();
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();

  HopperSettings get _s => widget.settings;
  HopperThemeDef get _t =>
      HopperThemes.byId(_s.themeId, custom: _s.customTheme);

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
    _nameCtrl.text = _s.playerName;
    _nameFocus.addListener(_onNameFocus);
  }

  /// Commit the profile name when the field loses focus: normalize and
  /// re-sync the field with the persisted value.
  void _onNameFocus() {
    if (!_nameFocus.hasFocus) _commitName(silent: true);
  }

  /// Every keystroke persists immediately (never only on keyboard-done).
  void _onNameChanged(String v) {
    _s.setPlayerName(v);
  }

  /// Normalize + persist; re-sync the field with the stored name.
  void _commitName({bool silent = false}) {
    if (!silent) widget.audio.click();
    _s.setPlayerName(_nameCtrl.text);
    _nameCtrl.text = _s.playerName;
    FocusScope.of(context).unfocus();
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Hopper.body(15, theme: _t)),
        backgroundColor: _t.uiDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      _s.setPro(true);
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    _nameFocus.removeListener(_onNameFocus);
    _nameFocus.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  /// Real in-app review flow: the Play in-app review sheet when available,
  /// otherwise fall back to opening the store listing. No fake dialogs.
  Future<void> _requestReview() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Review UI unavailable on this device/build: stay silent, no fake UI.
    }
  }

  void _play() {
    widget.audio.gameStart();
    final engine = RoadHopperEngine(
      difficulty: _s.difficulty,
      mode: _s.mode,
    );
    // App-scoped music: keep playing across screens. GameScreen switches
    // to the game track on entry; we switch back to menu music on return.
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => GameScreen(
        engine: engine,
        audio: widget.audio,
        settings: _s,
      ),
    ))
        .then((_) {
      if (mounted) {
        widget.audio.startMenuMusic();
        setState(() {}); // refresh best scores
      }
    });
  }

  void _share() {
    widget.audio.click();
    SharePlus.instance.share(ShareParams(
      text:
          'Play Road Hopper with me! https://play.google.com/store/apps/details?id=com.gameswajiha.roadhopper',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _s,
      builder: (_, _) => Scaffold(
        backgroundColor: _t.uiDeep,
        body: StreetBackdrop(
          theme: _t,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                children: [
                  _header(),
                  const SizedBox(height: 10),
                  _nameRow(),
                  const SizedBox(height: 14),
                  StreetButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow,
                    theme: _t,
                    width: 260,
                    fontSize: 24,
                    onTap: _play,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${HopperSettings.modeNames[_s.mode]} · ${HopperSettings.difficultyNames[_s.difficulty]}',
                    style: Hopper.body(13, theme: _t, color: _t.muted),
                  ),
                  const SectionPlaque(title: 'GAME MODE'),
                  _modePicker(),
                  const SectionPlaque(title: 'DIFFICULTY'),
                  _difficultyPicker(),
                  const SectionPlaque(title: 'YOUR HOPPER'),
                  _hopperPicker(),
                  const SectionPlaque(title: 'CROSSING THEME'),
                  _themePicker(),
                  const SectionPlaque(title: 'BEST SCORES'),
                  _stats(),
                  const SizedBox(height: 18),
                  _iconRow(),
                  const SizedBox(height: 10),
                  Text('Made with 💚 by WAJIHA',
                      style: Hopper.body(12, theme: _t, color: _t.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header
  Widget _header() {
    return Row(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _t.accent, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  offset: const Offset(0, 5),
                  blurRadius: 10),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/roadhopper_logo.png', fit: BoxFit.cover),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Road Hopper', style: Hopper.display(32, theme: _t)),
              Text('Dodge · Ride · Hop home',
                  style: Hopper.body(13, theme: _t, color: _t.muted)),
            ],
          ),
        ),
        if (_s.isPro)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _t.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('PRO',
                style: Hopper.label(12, theme: _t, color: _t.uiDeep)),
          ),
      ],
    );
  }

  // -------------------------------------------------------------- profile
  Widget _nameRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _t.uiDeep.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _t.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: _t.accentLight),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              style: Hopper.body(17, theme: _t),
              decoration: InputDecoration(
                hintText: 'Your hopper name',
                hintStyle: Hopper.body(15, theme: _t, color: _t.muted),
                border: InputBorder.none,
                isDense: true,
              ),
              maxLength: 16,
              textInputAction: TextInputAction.done,
              onChanged: _onNameChanged,
              onSubmitted: (_) => _commitName(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.check, color: _t.accentLight),
            onPressed: () => _commitName(),
            tooltip: 'Save name',
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- mode
  Widget _modePicker() {
    return Column(
      children: [
        for (int i = 0; i < 3; i++)
          _pickTile(
            selected: _s.mode == i,
            title: HopperSettings.modeNames[i],
            subtitle: HopperSettings.modeBlurb[i],
            icon: [Icons.home, Icons.all_inclusive, Icons.timer][i],
            onTap: () {
              widget.audio.click();
              _s.setMode(i);
            },
          ),
      ],
    );
  }

  Widget _difficultyPicker() {
    return Column(
      children: [
        for (int i = 0; i < 3; i++)
          _pickTile(
            selected: _s.difficulty == i,
            title: HopperSettings.difficultyNames[i],
            subtitle: HopperSettings.difficultyBlurb[i],
            icon: [Icons.directions_walk, Icons.directions_run, Icons.bolt][i],
            locked: i == 2 && !_s.isPro,
            onTap: () {
              if (i == 2 && !_s.isPro) {
                _openPro();
                return;
              }
              widget.audio.click();
              _s.setDifficulty(i);
            },
          ),
      ],
    );
  }

  Widget _pickTile({
    required bool selected,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool locked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? _t.accent.withValues(alpha: 0.22)
              : _t.uiDeep.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _t.accent : _t.accent.withValues(alpha: 0.3),
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: _t.accent.withValues(alpha: 0.25),
                      blurRadius: 10)
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _t.accent : _t.panel,
                border: Border.all(
                    color: _t.accent.withValues(alpha: 0.6), width: 1.5),
              ),
              child: Icon(icon,
                  color: selected ? _t.uiDeep : _t.accentLight, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Hopper.body(16, theme: _t)),
                  Text(subtitle,
                      style: Hopper.body(12, theme: _t, color: _t.muted)),
                ],
              ),
            ),
            if (locked)
              Icon(Icons.lock, color: _t.accentLight, size: 20)
            else if (selected)
              Icon(Icons.check_circle, color: _t.accentLight, size: 22),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- hopper
  Widget _hopperPicker() {
    final items = [
      ...HopperStyles.all,
      const HopperStyleDef(
          id: 10, name: 'My Hopper', body: Color(0xFF51CF66), belly: Color(0xFFD3F9D8), pro: true),
    ];
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final st = items[i];
          final selected = _s.hopperStyle == st.id;
          final locked = st.pro && !_s.isPro;
          final body = st.id == 10 ? Color(_s.customHopperBody) : st.body;
          final belly = st.id == 10 ? Color(_s.customHopperBelly) : st.belly;
          return GestureDetector(
            onTap: () {
              if (locked) {
                _openPro();
                return;
              }
              if (st.id == 10) {
                _openCustomHopper();
                return;
              }
              widget.audio.click();
              _s.setHopperStyle(st.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 84,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? _t.accent.withValues(alpha: 0.22)
                    : _t.uiDeep.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? _t.accent : _t.accent.withValues(alpha: 0.3),
                  width: selected ? 2.5 : 1.5,
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      _miniHopper(body, belly),
                      if (locked)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                                shape: BoxShape.circle, color: Colors.black54),
                            child: Icon(Icons.lock,
                                size: 12, color: _t.accentLight),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    st.name,
                    style: Hopper.body(10, theme: _t,
                        color: selected ? _t.ivory : _t.muted),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _miniHopper(Color body, Color belly) {
    return CustomPaint(
      size: const Size(44, 44),
      painter: _MiniHopperPainter(body: body, belly: belly),
    );
  }

  void _openCustomHopper() {
    widget.audio.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => CustomThemeScreen(
        audio: widget.audio,
        settings: _s,
        hopperMode: true,
      ),
    ))
        .then((_) {
      if (mounted) {
        _s.setHopperStyle(10);
        setState(() {});
      }
    });
  }

  // ----------------------------------------------------------------- theme
  Widget _themePicker() {
    final themes = [
      ...HopperThemes.all,
      HopperThemeDef(
        id: 'custom',
        name: 'My Creation',
        bank: _s.customTheme.bank,
        bankDark: _s.customTheme.bankDark,
        road: _s.customTheme.road,
        roadDark: _s.customTheme.roadDark,
        laneLine: _s.customTheme.laneLine,
        river: _s.customTheme.river,
        riverDeep: _s.customTheme.riverDeep,
        log: _s.customTheme.log,
        logLight: _s.customTheme.logLight,
        turtle: _s.customTheme.turtle,
        carColors: _s.customTheme.carColors,
        homeEmpty: _s.customTheme.homeEmpty,
        homeFull: _s.customTheme.homeFull,
        lily: _s.customTheme.lily,
        uiDeep: _s.customTheme.uiDeep,
        uiMid: _s.customTheme.uiMid,
        panel: _s.customTheme.panel,
        accent: _s.customTheme.accent,
        accentLight: _s.customTheme.accentLight,
        accentDark: _s.customTheme.accentDark,
        ivory: _s.customTheme.ivory,
        muted: _s.customTheme.muted,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.05,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: themes.length,
      itemBuilder: (_, i) {
        final th = themes[i];
        final selected = _s.themeId == th.id;
        final locked =
            (th.id == 'custom' || HopperThemes.isProTheme(th.id)) && !_s.isPro;
        return GestureDetector(
          onTap: () {
            if (locked) {
              _openPro();
              return;
            }
            if (th.id == 'custom') {
              widget.audio.click();
              Navigator.of(context)
                  .push(MaterialPageRoute(
                builder: (_) => CustomThemeScreen(
                  audio: widget.audio,
                  settings: _s,
                ),
              ))
                  .then((_) {
                if (mounted) {
                  _s.setTheme('custom');
                  setState(() {});
                }
              });
              return;
            }
            widget.audio.click();
            _s.setTheme(th.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _t.accent : _t.accent.withValues(alpha: 0.25),
                width: selected ? 3 : 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                          color: _t.accent.withValues(alpha: 0.3), blurRadius: 8)
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Container(color: th.bank)),
                    Expanded(
                        flex: 2,
                        child: Container(color: th.road)),
                    Expanded(
                        flex: 3,
                        child: Container(color: th.river)),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      th.name,
                      style: Hopper.body(10, theme: _t, color: Colors.white),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (locked)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.45),
                      child: Icon(Icons.lock,
                          color: _t.accentLight, size: 26),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------------------------------------------------- stats
  Widget _stats() {
    Widget card(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: _t.uiDeep.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _t.accent.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Column(
              children: [
                Text(label, style: Hopper.label(10, theme: _t)),
                const SizedBox(height: 2),
                Text(value, style: Hopper.display(18, theme: _t)),
              ],
            ),
          ),
        );
    return Column(
      children: [
        Row(
          children: [
            card('CLASSIC', '${_s.bestClassic}'),
            const SizedBox(width: 8),
            card('ENDLESS', '${_s.bestEndless}'),
            const SizedBox(width: 8),
            card('ATTACK', '${_s.bestScoreAttack}'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            card('GAMES', '${_s.gamesPlayed}'),
            const SizedBox(width: 8),
            card('HOPS', '${_s.totalHops}'),
            const SizedBox(width: 8),
            card('HOMES', '${_s.homesFilled}'),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------- icon row
  Widget _iconRow() {
    Widget btn(IconData icon, String tip, VoidCallback onTap) => PebbleButton(
          icon: icon,
          size: 54,
          theme: _t,
          onTap: () {
            widget.audio.click();
            onTap();
          },
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        btn(Icons.settings, 'Settings', () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SettingsScreen(
                audio: widget.audio, settings: _s),
          ));
        }),
        const SizedBox(width: 14),
        btn(Icons.share, 'Share', _share),
        const SizedBox(width: 14),
        btn(Icons.star, 'Rate', _requestReview),
        const SizedBox(width: 14),
        btn(Icons.workspace_premium, 'PRO', _openPro),
      ],
    );
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: widget.audio,
        settings: _s,
        store: _store,
      ),
    ))
        .then((_) {
      if (mounted) setState(() {});
    });
  }
}

/// Tiny frog preview for the hopper picker.
class _MiniHopperPainter extends CustomPainter {
  final Color body;
  final Color belly;
  _MiniHopperPainter({required this.body, required this.belly});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + 3);
    final r = size.width * 0.32;
    canvas.drawOval(
        Rect.fromCenter(
            center: c + const Offset(1, 5), width: r * 1.7, height: r * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.3));
    canvas.drawCircle(c, r, Paint()..color = body);
    canvas.drawCircle(c + Offset(0, r * 0.3), r * 0.62,
        Paint()..color = belly);
    for (final s in [-1, 1]) {
      final e = c + Offset(s * r * 0.42, -r * 0.62);
      canvas.drawCircle(e, r * 0.3, Paint()..color = Colors.white);
      canvas.drawCircle(e, r * 0.14, Paint()..color = Colors.black);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
