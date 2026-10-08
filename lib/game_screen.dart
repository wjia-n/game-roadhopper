import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

const int _cols = 13;
const int _rows = 13;
const List<int> _homeCols = [1, 4, 7, 10];

class _Item {
  double x; // left edge in cell units
  final double len;
  _Item(this.x, this.len);
}

class _Lane {
  final int row;
  final double dir; // +1 right, -1 left
  final double speed; // cells per second
  final bool river;
  final bool dive; // turtles that dive
  final List<_Item> items = [];
  double diveT = 0;
  _Lane(this.row, this.dir, this.speed, this.river, this.dive);
}

class RoadHopperScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const RoadHopperScreen(
      {super.key, required this.players, required this.callbacks});

  @override
  State<RoadHopperScreen> createState() => _RoadHopperScreenState();
}

class _RoadHopperScreenState extends State<RoadHopperScreen>
    with SingleTickerProviderStateMixin {
  final _rng = Random();
  late Ticker _ticker;
  Duration _last = Duration.zero;
  double _tGlobal = 0;

  final List<_Lane> _lanes = [];
  double _fx = 6; // frog x in cell units (float while riding)
  int _frogRow = 12;
  double _hopT = 1; // hop animation 0..1
  int _fromRow = 12;
  double _fromX = 6;

  int _score = 0, _best = 0, _lives = 3, _level = 1;
  double _timeLeft = 60;
  final Set<int> _homes = {};
  bool _over = false;
  bool _dying = false;
  double _dieT = 0;
  String _dieMsg = '';

  @override
  void initState() {
    super.initState();
    _buildLanes();
    _ticker = createTicker(_onTick)..start();
    _loadBest();
  }

  Future<void> _loadBest() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() => _best = p.getInt('roadhopper_best') ?? 0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _buildLanes() {
    _lanes.clear();
    final m = 1 + (_level - 1) * 0.15; // speed multiplier
    void road(int row, double dir, double sp, List<double> lens) {
      final l = _Lane(row, dir, sp * m, false, false);
      final gap = _cols / lens.length;
      for (var i = 0; i < lens.length; i++) {
        l.items.add(_Item(i * gap + _rng.nextDouble() * 2, lens[i]));
      }
      _lanes.add(l);
    }

    void river(int row, double dir, double sp, List<double> lens, bool dive) {
      final l = _Lane(row, dir, sp * m, true, dive);
      final gap = _cols / lens.length;
      for (var i = 0; i < lens.length; i++) {
        l.items.add(_Item(i * gap, lens[i]));
      }
      _lanes.add(l);
    }

    road(7, 1, 2.2, [1, 1, 1]);
    road(8, -1, 3.0, [1, 1, 2]);
    road(9, 1, 3.8, [1, 1, 1]);
    road(10, -1, 2.6, [2, 2]);
    road(11, 1, 4.4, [1, 1]);
    river(1, -1, 1.6, [4, 4], false);
    river(2, 1, 2.2, [2, 2, 2], true);
    river(3, -1, 2.8, [3, 3], false);
    river(4, 1, 2.0, [4, 4], false);
    river(5, -1, 3.4, [2, 2], true);
  }

  void _onTick(Duration elapsed) {
    if (!mounted || _over) return;
    if (ModalRoute.of(context)?.isCurrent != true) {
      _last = elapsed;
      return;
    }
    final dt = min((elapsed - _last).inMicroseconds / 1e6, 0.05);
    _last = elapsed;
    _tGlobal += dt;
    _update(dt);
    setState(() {});
  }

  bool get _onRiver => _frogRow >= 1 && _frogRow <= 5;
  bool get _onRoad => _frogRow >= 7 && _frogRow <= 11;

  _Lane _laneOf(int row) => _lanes.firstWhere((l) => l.row == row);

  void _update(double dt) {
    if (_dying) {
      _dieT -= dt;
      if (_dieT <= 0) {
        _dying = false;
        _respawn();
      }
      return;
    }
    _hopT = min(1, _hopT + dt * 6);
    // move items
    for (final l in _lanes) {
      for (final it in l.items) {
        it.x += l.dir * l.speed * dt;
        if (l.dir > 0 && it.x > _cols) it.x -= _cols + it.len;
        if (l.dir < 0 && it.x + it.len < 0) it.x += _cols + it.len;
      }
      if (l.dive) l.diveT = (l.diveT + dt) % 7;
    }
    // ride platforms
    if (_onRiver) {
      final l = _laneOf(_frogRow);
      final plat = _platformUnder(l);
      final diving = l.dive && l.diveT > 5;
      if (plat == null || diving) {
        _die(diving ? 'The turtle dove! 🐢💦' : 'Splash! 💦');
        return;
      }
      _fx += l.dir * l.speed * dt;
      if (_fx < -0.6 || _fx > _cols - 0.4) {
        _die('Swept away! 🌊');
        return;
      }
    }
    // car collisions
    if (_onRoad) {
      final l = _laneOf(_frogRow);
      for (final it in l.items) {
        if (_fx > it.x - 0.35 && _fx < it.x + it.len + 0.35) {
          _die('Squashed! 🚗💥');
          return;
        }
      }
    }
    // timer
    _timeLeft -= dt;
    if (_timeLeft <= 0) {
      _die('Out of time! ⏰');
    }
  }

  _Item? _platformUnder(_Lane l) {
    for (final it in l.items) {
      if (_fx >= it.x - 0.1 && _fx <= it.x + it.len + 0.1) return it;
    }
    return null;
  }

  void _hop(int dx, int dy) {
    if (_over || _dying || _hopT < 0.6) return;
    final nx = (_fx.round() + dx).clamp(0, _cols - 1);
    final ny = (_frogRow + dy).clamp(0, _rows - 1);
    _fromX = _fx;
    _fromRow = _frogRow;
    _fx = nx.toDouble();
    _frogRow = ny;
    _hopT = 0;
    if (dy < 0) {
      _score += 10;
      Sfx.tap();
    } else {
      Sfx.move();
    }
    if (_frogRow == 0) _reachHome();
    setState(() {});
  }

  void _reachHome() {
    final c = _fx.round();
    if (_homeCols.contains(c) && !_homes.contains(c)) {
      _homes.add(c);
      _score += 200;
      _timeLeft = min(60, _timeLeft + 15);
      Sfx.win();
      if (_homes.length == _homeCols.length) {
        _score += 1000;
        _level++;
        _homes.clear();
        _buildLanes();
        Sfx.win();
      }
      _frogRow = 12;
      _fx = 6;
      _fromRow = 12;
      _fromX = 6;
      _hopT = 1;
    } else {
      _die('No home there! 🏠');
    }
  }

  void _die(String msg) {
    if (_dying || _over) return;
    _dying = true;
    _dieT = 0.9;
    _dieMsg = msg;
    _lives--;
    Sfx.lose();
  }

  void _respawn() {
    if (_lives <= 0) {
      _gameOver();
      return;
    }
    _fx = 6;
    _frogRow = 12;
    _fromRow = 12;
    _fromX = 6;
    _hopT = 1;
    _timeLeft = 60;
  }

  Future<void> _gameOver() async {
    _over = true;
    _ticker.stop();
    final isBest = _score > _best;
    if (isBest) {
      _best = _score;
      final p = await SharedPreferences.getInstance();
      await p.setInt('roadhopper_best', _best);
    }
    widget.players.first.score = _score;
    widget.callbacks.refreshHud();
    widget.callbacks.finish(
      headline: 'You scored $_score!',
      subline: isBest
          ? '🐸 Legendary hopper! New best!'
          : 'Best: $_best • Level $_level',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    return Column(
      children: [
        _hud(t),
        _timeBar(t),
        Expanded(
          child: LayoutBuilder(builder: (ctx, c) {
            return GestureDetector(
              onPanEnd: (d) {
                final v = d.velocity.pixelsPerSecond;
                if (v.distance < 200) return;
                if (v.dx.abs() > v.dy.abs()) {
                  _hop(v.dx.sign.toInt(), 0);
                } else {
                  _hop(0, v.dy.sign.toInt());
                }
              },
              onTapUp: (d) {
                final box = ctx.findRenderObject() as RenderBox?;
                if (box == null) return;
                final local = box.globalToLocal(d.globalPosition);
                final cw = box.size.width / _cols;
                final ch = box.size.height / _rows;
                final fx = _fx * cw + cw / 2;
                final fy = _frogRow * ch + ch / 2;
                final dx = local.dx - fx, dy = local.dy - fy;
                if (dx.abs() < cw / 2 && dy.abs() < ch / 2) return;
                if (dx.abs() > dy.abs()) {
                  _hop(dx.sign.toInt(), 0);
                } else {
                  _hop(0, dy.sign.toInt());
                }
              },
              child: Container(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16)),
                child: CustomPaint(
                  painter: _HopperPainter(
                    lanes: _lanes,
                    fx: _fx,
                    frogRow: _frogRow,
                    fromX: _fromX,
                    fromRow: _fromRow,
                    hopT: _hopT,
                    homes: _homes,
                    dying: _dying,
                    dieMsg: _dieMsg,
                    time: _tGlobal,
                    theme: t,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text('swipe or tap to hop 🐸',
            style: TextStyle(color: t.muted, fontSize: 12)),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _hud(GameTheme t) {
    Widget stat(String l, String v) => Column(
          children: [
            Text(l,
                style: TextStyle(
                    color: t.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            Text(v,
                style: TextStyle(
                    color: t.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          stat('SCORE', '$_score'),
          stat('BEST', '$_best'),
          stat('LIVES', '🐸' * max(_lives, 0)),
          stat('LEVEL', '$_level'),
        ],
      ),
    );
  }

  Widget _timeBar(GameTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: (_timeLeft / 60).clamp(0.0, 1.0),
          minHeight: 8,
          backgroundColor: t.surface,
          color: _timeLeft < 15 ? Colors.redAccent : t.accent,
        ),
      ),
    );
  }
}

class _HopperPainter extends CustomPainter {
  final List<_Lane> lanes;
  final double fx, fromX, hopT, time;
  final int frogRow, fromRow;
  final Set<int> homes;
  final bool dying;
  final String dieMsg;
  final GameTheme theme;

  _HopperPainter({
    required this.lanes,
    required this.fx,
    required this.frogRow,
    required this.fromX,
    required this.fromRow,
    required this.hopT,
    required this.homes,
    required this.dying,
    required this.dieMsg,
    required this.time,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / _cols;
    final ch = size.height / _rows;
    Offset cell(double x, double y) =>
        Offset(x * cw + cw / 2, y * ch + ch / 2);

    // background rows
    for (var r = 0; r < _rows; r++) {
      Color c;
      if (r == 0 || r == 6 || r == 12) {
        c = const Color(0xFF2F9E44); // banks
      } else if (r >= 1 && r <= 5) {
        c = const Color(0xFF1971C2); // river
      } else {
        c = const Color(0xFF343A40); // road
      }
      canvas.drawRect(
          Rect.fromLTWH(0, r * ch, size.width, ch), Paint()..color = c);
    }
    // road dashes
    final dashPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 3;
    for (var r = 7; r <= 11; r++) {
      final y = r * ch + ch / 2;
      for (var x = 0.0; x < _cols; x += 1.6) {
        canvas.drawLine(Offset(x * cw, y), Offset((x + 0.8) * cw, y),
            dashPaint);
      }
    }
    // river waves
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 2;
    for (var r = 1; r <= 5; r++) {
      for (var x = 0; x < _cols; x++) {
        final y = r * ch + ch / 2 + sin(time * 3 + x * 1.7 + r) * 3;
        canvas.drawLine(Offset(x * cw + 4, y),
            Offset(x * cw + cw - 4, y), wavePaint);
      }
    }
    // home slots
    for (final hc in _homeCols) {
      final p = cell(hc.toDouble(), 0);
      final filled = homes.contains(hc);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: p, width: cw * 0.9, height: ch * 0.9),
              const Radius.circular(8)),
          Paint()
            ..color = filled
                ? const Color(0xFFFFD43B)
                : const Color(0xFF1E5A2E));
      if (filled) {
        final tp = TextPainter(
            text: const TextSpan(
                text: '🐸', style: TextStyle(fontSize: 22)),
            textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }
    // lane items
    for (final l in lanes) {
      final y = l.row * ch + ch / 2;
      for (final it in l.items) {
        final left = it.x * cw;
        final wdt = it.len * cw;
        if (l.river) {
          final diving =
              l.dive && l.diveT > 5 && l.diveT < 6.4;
          final p = Offset(left + wdt / 2, y + (diving ? 6 : 0));
          if (l.dive) {
            // turtle
            canvas.drawOval(
                Rect.fromCenter(
                    center: p,
                    width: wdt * 0.92,
                    height: ch * (diving ? 0.35 : 0.55)),
                Paint()
                  ..color = diving
                      ? const Color(0xFF2B8A3E)
                          .withValues(alpha: 0.45)
                      : const Color(0xFF40C057));
          } else {
            // log
            canvas.drawRRect(
                RRect.fromRectAndRadius(
                    Rect.fromCenter(
                        center: p, width: wdt * 0.96, height: ch * 0.6),
                    const Radius.circular(10)),
                Paint()..color = const Color(0xFF8B5E34));
            canvas.drawRRect(
                RRect.fromRectAndRadius(
                    Rect.fromCenter(
                        center: p + const Offset(0, -4),
                        width: wdt * 0.96,
                        height: ch * 0.22),
                    const Radius.circular(6)),
                Paint()..color = const Color(0xFFA9743F));
          }
        } else {
          // car
          final p = Offset(left + wdt / 2, y);
          final carC = it.len > 1.5
              ? const Color(0xFF9775FA)
              : const Color(0xFFFF6B6B);
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: p, width: wdt * 0.92, height: ch * 0.66),
                  const Radius.circular(8)),
              Paint()..color = carC);
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromCenter(
                      center: p + Offset(l.dir * -wdt * 0.08, 0),
                      width: wdt * 0.4,
                      height: ch * 0.4),
                  const Radius.circular(5)),
              Paint()
                ..color = Colors.white.withValues(alpha: 0.75));
        }
      }
    }
    // frog (interpolated hop)
    final ix = fromX + (fx - fromX) * hopT;
    final iy = fromRow + (frogRow - fromRow) * hopT;
    final squash = sin(hopT * pi);
    final fp = cell(ix, iy) + Offset(0, -squash * ch * 0.35);
    final fr = cw * 0.36 * (1 + squash * 0.15);
    if (dying) {
      final tp = TextPainter(
          text: TextSpan(
              text: dieMsg,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(
          canvas,
          Offset((size.width - tp.width) / 2,
              size.height * 0.45));
    } else {
      canvas.drawCircle(
          fp, fr, Paint()..color = const Color(0xFF51CF66));
      // eyes
      for (final s in [-1, 1]) {
        canvas.drawCircle(
            fp + Offset(s * fr * 0.42, -fr * 0.5),
            fr * 0.28,
            Paint()..color = Colors.white);
        canvas.drawCircle(
            fp + Offset(s * fr * 0.42, -fr * 0.52),
            fr * 0.13,
            Paint()..color = Colors.black);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HopperPainter old) => true;
}
