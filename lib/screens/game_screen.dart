import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import '../engine/roadhopper_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/roadhopper_themes.dart';
import '../theme/street_backdrop.dart';

/// The live game view. The engine owns all state; this screen only renders
/// it and forwards input. Audio is driven through engine events.
class GameScreen extends StatefulWidget {
  final RoadHopperEngine engine;
  final HopperAudio audio;
  final HopperSettings settings;

  const GameScreen({
    super.key,
    required this.engine,
    required this.audio,
    required this.settings,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  RoadHopperEngine get _e => widget.engine;
  HopperSettings get _s => widget.settings;
  HopperThemeDef get _t =>
      HopperThemes.byId(_s.themeId, custom: _s.customTheme);
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _e.onEvent = _onEngineEvent;
    _e.addListener(_onEngineChanged);
    widget.audio.startGameMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _e.removeListener(_onEngineChanged);
    _e.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounding mid-run auto-pauses the engine (RULES §12).
    if (state == AppLifecycleState.paused) {
      _e.setPaused(true);
    }
  }

  void _onEngineChanged() {
    if (_e.over && !_recorded) {
      _recorded = true;
      _finishRun();
    }
  }

  void _onEngineEvent(HopperEvent ev) {
    final a = widget.audio;
    switch (ev) {
      case HopperEvent.hop:
        a.hop();
        break;
      case HopperEvent.invalid:
        a.invalid();
        break;
      case HopperEvent.splashDeath:
        a.splash();
        break;
      case HopperEvent.squishDeath:
        a.squish();
        break;
      case HopperEvent.diveDeath:
        a.splash();
        break;
      case HopperEvent.home:
        a.home();
        break;
      case HopperEvent.levelUp:
        a.levelUp();
        break;
      case HopperEvent.tick:
        a.tick();
        break;
      case HopperEvent.win:
        a.win();
        break;
      case HopperEvent.lose:
        a.lose();
        break;
    }
  }

  Future<void> _finishRun() async {
    final wasBest = _e.score > _s.bestForMode(_e.mode) && _e.score > 0;
    await _s.recordGame(
      score: _e.score,
      mode: _e.mode,
      hops: _e.hops,
      homes: _e.homesClaimed,
      levels: _e.levelsCleared,
    );
    if (!mounted) return;
    if (wasBest) widget.audio.win();
    // Sensible review moment: every 3rd finished run, new best or not.
    if (_s.gamesPlayed % 3 == 0) {
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (_) {}
    }
  }

  void _shareScore() {
    widget.audio.click();
    SharePlus.instance.share(ShareParams(
      text:
          'I scored ${_e.score} in Road Hopper! Can you hop further? https://play.google.com/store/apps/details?id=com.gameswajiha.roadhopper',
    ));
  }

  void _restart() {
    widget.audio.gameStart();
    _recorded = false;
    _e.restart();
  }

  HopperStyleDef get _style {
    if (_s.hopperStyle == 10) {
      final body = Color(_s.customHopperBody);
      final hsl = HSLColor.fromColor(body);
      return HopperStyleDef(
        id: 10,
        name: 'My Hopper',
        body: body,
        belly: Color(_s.customHopperBelly),
        spots: hsl.withLightness((hsl.lightness - 0.2).clamp(0.0, 1.0).toDouble()).toColor(),
      );
    }
    return HopperStyles.byId(_s.hopperStyle);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_e.over && !_e.paused) {
          _e.setPaused(true);
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _t.uiDeep,
        body: StreetBackdrop(
          theme: _t,
          child: SafeArea(
            child: ListenableBuilder(
              listenable: _e,
              builder: (_, _) => Stack(
                children: [
                  Column(
                    children: [
                      _hud(),
                      _statusBar(),
                      Expanded(child: _board()),
                      _bannerLine(),
                      _controls(),
                    ],
                  ),
                  if (_e.phase == HopperPhase.ready) _readyOverlay(),
                  if (_e.paused && !_e.over) _pauseOverlay(),
                  if (_e.over) _gameOverOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ HUD
  Widget _hud() {
    Widget stat(String label, String value, {Color? color}) => Column(
          children: [
            Text(label, style: Hopper.label(10, theme: _t)),
            Text(value,
                style: Hopper.display(19, theme: _t, color: color)),
          ],
        );
    final livesStr =
        _e.scoreAttack ? '∞' : '🐸' * max(_e.lives, 0).toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          stat('SCORE', '${_e.score}'),
          stat('BEST', '${_s.bestForMode(_e.mode)}'),
          stat('LIVES', livesStr.isEmpty ? '—' : livesStr),
          stat(_e.scoreAttack ? 'TIME' : 'LEVEL',
              _e.scoreAttack ? '${_e.attackClock.ceil()}s' : '${_e.level}'),
        ],
      ),
    );
  }

  Widget _statusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          // Home slots.
          Row(
            children: [
              for (final c in homeCols)
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _e.homes.contains(c) ? _t.homeFull : _t.homeEmpty,
                    border: Border.all(
                        color: _t.accent.withValues(alpha: 0.6), width: 1.5),
                    boxShadow: _e.homes.contains(c)
                        ? [
                            BoxShadow(
                                color: _t.homeFull.withValues(alpha: 0.7),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: _e.homes.contains(c)
                      ? const Center(
                          child: Text('🐸', style: TextStyle(fontSize: 11)))
                      : null,
                ),
            ],
          ),
          const SizedBox(width: 10),
          // Clock bar.
          Expanded(
            child: _e.endless
                ? Text('∞ ENDLESS',
                    style: Hopper.label(12, theme: _t),
                    textAlign: TextAlign.right)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _e.scoreAttack
                          ? (_e.attackClock / 90).clamp(0.0, 1.0).toDouble()
                          : (_e.timeLeft / _e.timeMax).clamp(0.0, 1.0).toDouble(),
                      minHeight: 10,
                      backgroundColor: Colors.black.withValues(alpha: 0.45),
                      color: (_e.scoreAttack
                                  ? _e.attackClock
                                  : _e.timeLeft) <
                              11
                          ? const Color(0xFFE05252)
                          : _t.accent,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- board
  Widget _board() {
    return LayoutBuilder(builder: (ctx, c) {
      return GestureDetector(
        onPanEnd: (d) {
          final v = d.velocity.pixelsPerSecond;
          if (v.distance < 200) return;
          if (v.dx.abs() > v.dy.abs()) {
            _e.hop(v.dx.sign.toInt(), 0);
          } else {
            _e.hop(0, v.dy.sign.toInt());
          }
        },
        onTapUp: (d) {
          final box = ctx.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(d.globalPosition);
          final cw = box.size.width / hopperCols;
          final ch = box.size.height / hopperRows;
          final fx = _e.fx * cw + cw / 2;
          final fy = _e.row * ch + ch / 2;
          final dx = local.dx - fx, dy = local.dy - fy;
          if (dx.abs() < cw / 2 && dy.abs() < ch / 2) return;
          if (dx.abs() > dy.abs()) {
            _e.hop(dx.sign.toInt(), 0);
          } else {
            _e.hop(0, dy.sign.toInt());
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _t.accent.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  offset: const Offset(0, 8),
                  blurRadius: 18),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _HopperPainter(
              engine: _e,
              theme: _t,
              style: _style,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    });
  }

  Widget _bannerLine() {
    final show = _e.bannerT > 0 && _e.banner.isNotEmpty;
    return SizedBox(
      height: 30,
      child: Center(
        child: AnimatedOpacity(
          opacity: show ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _t.accent.withValues(alpha: 0.5), width: 1),
            ),
            child: Text(
              _e.banner,
              style: Hopper.body(14, theme: _t, color: _t.accentLight),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- controls
  Widget _controls() {
    Widget dirBtn(IconData icon, int dx, int dy) => PebbleButton(
          icon: icon,
          size: 54,
          theme: _t,
          onTap: () => _e.hop(dx, dy),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // D-pad.
          SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              children: [
                Positioned(
                    top: 0,
                    left: 58,
                    child: dirBtn(Icons.keyboard_arrow_up, 0, -1)),
                Positioned(
                    top: 58,
                    left: 0,
                    child: dirBtn(Icons.keyboard_arrow_left, -1, 0)),
                Positioned(
                    top: 58,
                    left: 116,
                    child: dirBtn(Icons.keyboard_arrow_right, 1, 0)),
                Positioned(
                    top: 116,
                    left: 58,
                    child: dirBtn(Icons.keyboard_arrow_down, 0, 1)),
              ],
            ),
          ),
          // Pause / restart.
          Column(
            children: [
              PebbleButton(
                icon: _e.paused ? Icons.play_arrow : Icons.pause,
                theme: _t,
                onTap: () {
                  widget.audio.click();
                  _e.setPaused(!_e.paused);
                },
              ),
              const SizedBox(height: 12),
              PebbleButton(
                icon: Icons.refresh,
                theme: _t,
                onTap: _restart,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- overlays
  Widget _overlayShell({required String title, required List<Widget> children}) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.62),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 36),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
            decoration: BoxDecoration(
              color: _t.panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _t.accent, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    offset: const Offset(0, 10),
                    blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: Hopper.display(30, theme: _t),
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _readyOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Text('GET READY…',
              style: Hopper.display(34, theme: _t, color: _t.ivory)),
        ),
      ),
    );
  }

  Widget _pauseOverlay() {
    return _overlayShell(
      title: 'PAUSED',
      children: [
        StreetButton(
            label: 'Resume',
            icon: Icons.play_arrow,
            theme: _t,
            width: 210,
            onTap: () {
              widget.audio.click();
              _e.setPaused(false);
            }),
        const SizedBox(height: 12),
        StreetButton(
            label: 'Restart',
            icon: Icons.refresh,
            theme: _t,
            width: 210,
            onTap: _restart),
        const SizedBox(height: 12),
        StreetButton(
            label: 'Quit to Menu',
            icon: Icons.home,
            theme: _t,
            width: 210,
            onTap: () {
              widget.audio.click();
              Navigator.of(context).pop();
            }),
      ],
    );
  }

  Widget _gameOverOverlay() {
    final wasBest =
        _e.score > 0 && _e.score >= _s.bestForMode(_e.mode);
    final title = _e.scoreAttack ? "TIME'S UP!" : 'GAME OVER';
    return _overlayShell(
      title: title,
      children: [
        if (wasBest)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _t.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('★ NEW BEST! ★',
                style: Hopper.label(14, theme: _t, color: _t.uiDeep)),
          ),
        const SizedBox(height: 8),
        Text('${_e.score}',
            style: Hopper.display(52, theme: _t, color: _t.accentLight)),
        Text('Best: ${_s.bestForMode(_e.mode)}',
            style: Hopper.body(15, theme: _t, color: _t.muted)),
        const SizedBox(height: 6),
        Text(
            '${_e.hops} hops · ${_e.homesClaimed} homes${_e.mode == 0 ? ' · level ${_e.level}' : ''}',
            style: Hopper.body(13, theme: _t, color: _t.muted)),
        const SizedBox(height: 18),
        StreetButton(
            label: 'Hop Again',
            icon: Icons.refresh,
            theme: _t,
            width: 220,
            onTap: _restart),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PebbleButton(
                icon: Icons.share,
                theme: _t,
                size: 52,
                onTap: _shareScore),
            const SizedBox(width: 16),
            PebbleButton(
                icon: Icons.home,
                theme: _t,
                size: 52,
                onTap: () {
                  widget.audio.click();
                  Navigator.of(context).pop();
                }),
          ],
        ),
      ],
    );
  }
}

// ===========================================================================
// Board painter — pseudo-3D roadside diorama: layered materials, soft drop
// shadows, beveled cars/logs/turtles, squash-and-stretch frog, particles.
// ===========================================================================
class _HopperPainter extends CustomPainter {
  final RoadHopperEngine engine;
  final HopperThemeDef theme;
  final HopperStyleDef style;

  _HopperPainter({
    required this.engine,
    required this.theme,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    final cw = size.width / hopperCols;
    final ch = size.height / hopperRows;
    Offset cell(double x, double y) =>
        Offset(x * cw + cw / 2, y * ch + ch / 2);

    // Screen shake (decaying sine — deterministic, no Random in paint).
    final sh = engine.shakeT;
    canvas.save();
    if (sh > 0) {
      canvas.translate(
        sin(engine.time * 90) * sh * 22,
        cos(engine.time * 77) * sh * 16,
      );
    }

    // --- Row backgrounds.
    for (var r = 0; r < hopperRows; r++) {
      final rect = Rect.fromLTWH(0, r * ch, size.width, ch);
      if (r == 0 || r == 6 || r == 12) {
        // Bank: grass with a darker base edge for depth.
        canvas.drawRect(rect, Paint()..color = t.bank);
        canvas.drawRect(
            Rect.fromLTWH(0, (r + 1) * ch - 4, size.width, 4),
            Paint()..color = t.bankDark);
        _grassTufts(canvas, r, cw, ch, size.width, t);
      } else if (r >= 1 && r <= 5) {
        // River: vertical material gradient + drifting wave lines.
        final grad = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.river, t.riverDeep],
        );
        canvas.drawRect(
            rect, Paint()..shader = grad.createShader(rect));
        _waves(canvas, r, cw, ch, size.width, t);
      } else {
        // Road: asphalt with speckle + edge curbs.
        canvas.drawRect(rect, Paint()..color = t.road);
        canvas.drawRect(Rect.fromLTWH(0, r * ch, size.width, 3),
            Paint()..color = t.roadDark);
        _speckle(canvas, r, cw, ch, size.width, t);
        // Lane dashes.
        final dash = Paint()
          ..color = t.laneLine.withValues(alpha: 0.75)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        final y = r * ch + ch / 2;
        for (var x = 0.0; x < hopperCols; x += 1.7) {
          canvas.drawLine(Offset(x * cw, y), Offset((x + 0.85) * cw, y), dash);
        }
      }
    }

    // --- Home slots: recessed alcoves with lily pads.
    for (final hc in homeCols) {
      final p = cell(hc.toDouble(), 0);
      final filled = engine.homes.contains(hc);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: p, width: cw * 0.92, height: ch * 0.92),
              const Radius.circular(10)),
          Paint()..color = t.homeEmpty);
      // Inner shadow = recessed.
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: p + const Offset(0, 2),
                  width: cw * 0.78,
                  height: ch * 0.78),
              const Radius.circular(8)),
          Paint()..color = Colors.black.withValues(alpha: 0.35));
      // Lily pad.
      canvas.drawCircle(
          p, cw * 0.3, Paint()..color = t.lily.withValues(alpha: 0.85));
      if (filled) {
        // Golden glow + resting frog.
        canvas.drawCircle(
            p,
            cw * 0.42,
            Paint()
              ..color = t.homeFull.withValues(alpha: 0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        _miniFrog(canvas, p, cw * 0.24, t);
      }
    }

    // --- Lane items.
    for (final l in engine.lanes) {
      final y = l.row * ch + ch / 2;
      for (int idx = 0; idx < l.items.length; idx++) {
        final it = l.items[idx];
        final cx = (it.x + it.len / 2) * cw;
        final wdt = it.len * cw;
        if (l.river) {
          // Dive window matches the engine's kill window exactly
          // (engine.divePeriod - diveSubmergeSecs).
          final diving =
              l.dive && l.diveT > engine.divePeriod - diveSubmergeSecs;
          if (l.dive) {
            _turtle(canvas, Offset(cx, y + (diving ? 7 : 0)), wdt, ch,
                t.turtle, diving, engine.time + idx);
          } else {
            _log(canvas, Offset(cx, y), wdt, ch, t);
          }
        } else {
          final carColor = t.carColors[idx % t.carColors.length];
          _car(canvas, Offset(cx, y), wdt, ch, carColor, l.dir);
        }
      }
    }

    // --- Frog (interpolated hop + squash & stretch).
    final ix = engine.fromX + (engine.fx - engine.fromX) * engine.hopT;
    final iy = engine.fromRow + (engine.row - engine.fromRow) * engine.hopT;
    final squash = sin(engine.hopT * pi);
    final fp = cell(ix, iy) + Offset(0, -squash * ch * 0.4);
    final fr = cw * 0.36;
    final dying = engine.phase == HopperPhase.dying;
    // Soft drop shadow = ambient occlusion.
    canvas.drawOval(
        Rect.fromCenter(
            center: fp + Offset(2, fr * 0.75),
            width: fr * 1.7,
            height: fr * 0.5),
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    final fade = dying ? 0.45 : 1.0;
    _frog(canvas, fp, fr * (1 + squash * 0.12), t, fade);

    // --- Particles.
    for (final p in engine.particles) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0).toDouble();
      canvas.drawCircle(
          Offset(p.x * cw, p.y * ch),
          p.size * (0.5 + a * 0.5),
          Paint()..color = Color(p.color).withValues(alpha: a));
    }

    // --- Floaters (+10 / +200 texts).
    for (final f in engine.floaters) {
      final a = (f.life / 1.2).clamp(0.0, 1.0).toDouble();
      final tp = TextPainter(
          text: TextSpan(
              text: f.text,
              style: TextStyle(
                  color: Color(f.color).withValues(alpha: a),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 3)
                  ])),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas,
          Offset(f.x * cw - tp.width / 2, f.y * ch - tp.height / 2));
    }

    canvas.restore();
  }

  void _grassTufts(
      Canvas canvas, int r, double cw, double ch, double w, HopperThemeDef t) {
    final paint = Paint()
      ..color = t.bankDark
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var x = 0; x < hopperCols; x += 2) {
      // Deterministic tuft placement from row/col hash.
      final h = ((r * 31 + x * 17) % 10) / 10.0;
      final bx = (x + 0.4 + h * 0.8) * cw;
      final by = r * ch + ch * 0.72;
      canvas.drawLine(Offset(bx, by), Offset(bx - 3, by - 8), paint);
      canvas.drawLine(Offset(bx + 3, by), Offset(bx + 4, by - 9), paint);
      canvas.drawLine(Offset(bx + 6, by), Offset(bx + 10, by - 7), paint);
    }
  }

  void _waves(
      Canvas canvas, int r, double cw, double ch, double w, HopperThemeDef t) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = 0; x < hopperCols; x++) {
      final y =
          r * ch + ch / 2 + sin(engine.time * 3 + x * 1.7 + r * 2.1) * 3.5;
      canvas.drawLine(
          Offset(x * cw + 5, y), Offset(x * cw + cw - 5, y), paint);
    }
  }

  void _speckle(
      Canvas canvas, int r, double cw, double ch, double w, HopperThemeDef t) {
    final paint = Paint()..color = t.roadDark.withValues(alpha: 0.5);
    for (var i = 0; i < 12; i++) {
      final h1 = ((r * 57 + i * 23) % 100) / 100.0;
      final h2 = ((r * 91 + i * 37) % 100) / 100.0;
      canvas.drawCircle(
          Offset(h1 * w, r * ch + h2 * ch), 1.6, paint);
    }
  }

  void _car(Canvas canvas, Offset c, double w, double h, Color color,
      double dir) {
    final bodyH = h * 0.62;
    final bodyW = w * 0.94;
    // Shadow.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c + const Offset(2, 5),
                width: bodyW,
                height: bodyH),
            const Radius.circular(8)),
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    // Body with top bevel.
    final bodyRect =
        Rect.fromCenter(center: c, width: bodyW, height: bodyH);
    canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, const Radius.circular(8)),
        Paint()..color = color);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c + Offset(0, -bodyH * 0.22),
                width: bodyW * 0.96,
                height: bodyH * 0.34),
            const Radius.circular(6)),
        Paint()..color = Colors.white.withValues(alpha: 0.28));
    // Cabin / windshield toward the front.
    final front = dir > 0 ? 1.0 : -1.0;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c + Offset(front * bodyW * 0.1, -bodyH * 0.08),
                width: bodyW * 0.42,
                height: bodyH * 0.44),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFDCEBF5).withValues(alpha: 0.9));
    // Headlights on the front edge.
    canvas.drawCircle(
        c + Offset(front * bodyW * 0.5, -bodyH * 0.18),
        3.2,
        Paint()..color = const Color(0xFFFFF3B0));
    canvas.drawCircle(
        c + Offset(front * bodyW * 0.5, bodyH * 0.18),
        3.2,
        Paint()..color = const Color(0xFFFFF3B0));
    // Wheels.
    final wheel = Paint()..color = const Color(0xFF1A1D22);
    for (final sx in [-0.32, 0.32]) {
      for (final sy in [-0.5, 0.5]) {
        canvas.drawCircle(
            c + Offset(sx * bodyW, sy * bodyH), bodyH * 0.16, wheel);
      }
    }
  }

  void _log(Canvas canvas, Offset c, double w, double h, HopperThemeDef t) {
    final logH = h * 0.58;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c + const Offset(2, 5),
                width: w * 0.96,
                height: logH),
            const Radius.circular(10)),
        Paint()..color = Colors.black.withValues(alpha: 0.3));
    final rect = Rect.fromCenter(center: c, width: w * 0.96, height: logH);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()..color = t.log);
    // Top highlight = rounded physicality.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c + const Offset(0, -4),
                width: w * 0.94,
                height: logH * 0.36),
            const Radius.circular(7)),
        Paint()..color = t.logLight);
    // End rings.
    for (final s in [-1, 1]) {
      canvas.drawCircle(
          c + Offset(s * w * 0.44, 0), logH * 0.3,
          Paint()..color = t.logLight.withValues(alpha: 0.85));
      canvas.drawCircle(c + Offset(s * w * 0.44, 0), logH * 0.16,
          Paint()..color = t.log.withValues(alpha: 0.9));
    }
  }

  void _turtle(Canvas canvas, Offset c, double w, double h, Color color,
      bool diving, double seed) {
    final a = diving ? 0.4 : 1.0;
    final shellH = h * (diving ? 0.32 : 0.52);
    canvas.drawOval(
        Rect.fromCenter(center: c, width: w * 0.92, height: shellH),
        Paint()..color = color.withValues(alpha: a));
    // Shell plates.
    final plate = Paint()
      ..color = Colors.white.withValues(alpha: 0.25 * a);
    final n = (w / 26).round().clamp(2, 8).toInt();
    for (var i = 0; i < n; i++) {
      final px = c.dx - w * 0.36 + i * (w * 0.72 / (n - 1));
      canvas.drawCircle(Offset(px, c.dy - shellH * 0.1), 4, plate);
    }
    // Head bobbing.
    if (!diving) {
      final bob = sin(seed * 2.2) * 2;
      canvas.drawCircle(
          c + Offset(w * 0.52, -shellH * 0.2 + bob),
          h * 0.14,
          Paint()..color = color);
    }
  }

  void _miniFrog(Canvas canvas, Offset c, double r, HopperThemeDef t) {
    canvas.drawCircle(c, r, Paint()..color = style.body);
    canvas.drawCircle(c + Offset(0, r * 0.25), r * 0.62,
        Paint()..color = style.belly);
  }

  void _frog(Canvas canvas, Offset c, double r, HopperThemeDef t, double fade) {
    // Body.
    canvas.drawCircle(
        c, r, Paint()..color = style.body.withValues(alpha: fade));
    // Belly.
    canvas.drawCircle(
        c + Offset(0, r * 0.3),
        r * 0.68,
        Paint()..color = style.belly.withValues(alpha: fade));
    // Pattern.
    final spotPaint = Paint()
      ..color = (style.spots ?? style.body).withValues(alpha: fade);
    switch (style.pattern) {
      case 'spots':
        for (final o in [
          Offset(-0.45, -0.1),
          Offset(0.42, -0.15),
          Offset(0.0, 0.45),
          Offset(-0.2, -0.5),
        ]) {
          canvas.drawCircle(c + Offset(o.dx * r, o.dy * r), r * 0.16, spotPaint);
        }
        break;
      case 'stripes':
        for (final s in [-1, 1]) {
          canvas.drawLine(
              c + Offset(s * r * 0.55, -r * 0.6),
              c + Offset(s * r * 0.35, r * 0.55),
              spotPaint..strokeWidth = r * 0.18);
        }
        break;
      case 'metal':
        for (final o in [
          Offset(-0.5, -0.3),
          Offset(0.5, -0.3),
          Offset(-0.5, 0.4),
          Offset(0.5, 0.4),
        ]) {
          canvas.drawCircle(
              c + Offset(o.dx * r, o.dy * r),
              r * 0.09,
              Paint()..color = Colors.white.withValues(alpha: 0.7 * fade));
        }
        break;
      case 'mask':
        // Ninja headband.
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: c + Offset(0, -r * 0.45),
                    width: r * 1.7,
                    height: r * 0.34),
                const Radius.circular(6)),
            Paint()..color = const Color(0xFFD64545).withValues(alpha: fade));
        canvas.drawLine(
            c + Offset(r * 0.85, -r * 0.45),
            c + Offset(r * 1.35, -r * 0.15),
            Paint()
              ..color = const Color(0xFFD64545).withValues(alpha: fade)
              ..strokeWidth = r * 0.12
              ..strokeCap = StrokeCap.round);
        break;
      case 'plain':
        break;
    }
    // Eyes on top.
    for (final s in [-1, 1]) {
      final e = c + Offset(s * r * 0.42, -r * 0.62);
      canvas.drawCircle(e, r * 0.3,
          Paint()..color = Colors.white.withValues(alpha: fade));
      canvas.drawCircle(
          e + Offset(0, r * 0.04),
          r * 0.15,
          Paint()..color = Colors.black.withValues(alpha: fade));
      canvas.drawCircle(
          e + Offset(-r * 0.05, -r * 0.05),
          r * 0.05,
          Paint()..color = Colors.white.withValues(alpha: 0.9 * fade));
    }
  }

  @override
  bool shouldRepaint(covariant _HopperPainter old) => true;
}
