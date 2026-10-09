import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Road Hopper engine — owns ALL game state, phases, and timers.
//
// Phases: ready → playing ⇄ dying → playing … → celebrating → playing …
//         → gameOver. Pause freezes the phase timers (never cancels them into
//         oblivion); a 2s watchdog recovers any phase found without a live
//         timer, so stuck states are impossible by construction.
//
// The UI never mutates game state directly: it calls hop()/setPaused()/
// restart() and renders what the engine exposes. Audio is driven through
// [onEvent] — the screen maps events to sounds.
// ---------------------------------------------------------------------------

const int hopperCols = 13;
const int hopperRows = 13;
/// The 5 home slots on the far bank (RULES §2 — 5 slots, classic layout).
const List<int> homeCols = [1, 3, 6, 9, 11];

/// Diving turtles submerge for this long at the end of each dive period
/// (RULES §7: ~1.4s).
const double diveSubmergeSecs = 1.4;

enum HopperPhase { ready, playing, dying, celebrating, gameOver }

enum DeathCause { squashed, drowned, sweptAway, dove, timeUp, noHome }

/// Events the screen turns into sounds / narration.
enum HopperEvent {
  hop,
  invalid,
  splashDeath,
  squishDeath,
  diveDeath,
  home,
  levelUp,
  tick,
  win,
  lose,
}

class LaneItem {
  double x; // left edge, in cell units
  final double len;
  LaneItem(this.x, this.len);
}

class HopperLane {
  final int row;
  final double dir; // +1 moves right, -1 moves left
  final double speed; // cells per second
  final bool river;
  final bool dive; // turtles that submerge
  final List<LaneItem> items = [];
  double diveT = 0;
  HopperLane(this.row, this.dir, this.speed, this.river, this.dive);
}

class Particle {
  double x, y, vx, vy, life, maxLife, size;
  int color; // ARGB
  Particle(this.x, this.y, this.vx, this.vy, this.life, this.color, this.size)
      : maxLife = life;
}

class Floater {
  double x, y, life;
  String text;
  int color;
  Floater(this.x, this.y, this.text, this.color) : life = 1.2;
}

class RoadHopperEngine extends ChangeNotifier {
  final int difficulty; // 0 stroll, 1 street, 2 rush hour
  final int mode; // 0 classic, 1 endless, 2 score attack

  final _rand = Random();

  // Board state.
  final List<HopperLane> lanes = [];
  double fx = 6; // frog x in cell units (float while riding)
  int row = 12;
  double hopT = 1; // hop animation 0..1
  int fromRow = 12;
  double fromX = 6;
  DateTime _lastHop = DateTime.fromMillisecondsSinceEpoch(0);

  // Run state.
  HopperPhase phase = HopperPhase.ready;
  int score = 0;
  int lives = 3;
  int level = 1;
  double timeLeft = 60; // classic per-attempt clock
  double timeMax = 60;
  double attackClock = 90; // score-attack total clock
  final Set<int> homes = {};

  // Death / celebration.
  DeathCause? deathCause;
  String deathMsg = '';

  // Juice.
  final List<Particle> particles = [];
  final List<Floater> floaters = [];
  String banner = '';
  double bannerT = 0;
  double shakeT = 0;
  double time = 0; // global animation clock, seconds

  // Run stats for persistence.
  int hops = 0;
  int homesClaimed = 0;
  int levelsCleared = 0;

  /// The screen sets this to turn engine events into sounds.
  void Function(HopperEvent)? onEvent;

  Timer? _updateTimer; // 60fps simulation loop — engine owned
  Timer? _phaseTimer; // single phase-transition timer (death/celebrate/ready)
  DateTime? _phaseDeadline; // freeze point for pause/resume (RULES §12)
  void Function()? _phaseFn; // frozen phase callback
  double _phaseRemaining = 0; // seconds left when frozen
  Timer? _watchdog; // stuck-state recovery — engine owned
  bool _disposed = false;
  bool paused = false;
  int _lastTickSecond = -1;

  double get _speedMul =>
      [0.75, 1.0, 1.35][difficulty.clamp(0, 2).toInt()] * (1 + (level - 1) * 0.12);

  bool get over => phase == HopperPhase.gameOver;
  bool get scoreAttack => mode == 2;
  bool get endless => mode == 1;

  /// Current dive cycle length for turtle lanes (RULES §7). The painter uses
  /// this so the visible submerge always matches the engine's kill window.
  double get divePeriod => difficulty == 2 ? 5.0 : 7.0;

  RoadHopperEngine({required this.difficulty, required this.mode}) {
    timeMax = [75.0, 60.0, 45.0][difficulty.clamp(0, 2).toInt()];
    timeLeft = timeMax;
    _buildLanes();
    banner = scoreAttack
        ? 'Score as much as you can!'
        : endless
            ? 'No clock — hop forever!'
            : 'Fill all 5 homes!';
    bannerT = 2.5;
    // "Get ready" beat, then play. The watchdog covers a lost timer.
    _armPhase(const Duration(milliseconds: 1200), () {
      if (phase == HopperPhase.ready) {
        phase = HopperPhase.playing;
        notifyListeners();
      }
    });
    _updateTimer =
        Timer.periodic(const Duration(milliseconds: 16), (_) => _update(0.016));
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _recover());
  }

  @override
  void dispose() {
    _disposed = true;
    _updateTimer?.cancel();
    _phaseTimer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ lane setup
  void _buildLanes() {
    lanes.clear();
    final m = _speedMul;
    final rush = difficulty == 2;

    void road(int row, double dir, double sp, List<double> lens) {
      final l = HopperLane(row, dir, sp * m, false, false);
      final gap = hopperCols / lens.length;
      for (var i = 0; i < lens.length; i++) {
        l.items.add(LaneItem(i * gap + _rand.nextDouble() * 1.5, lens[i]));
      }
      lanes.add(l);
    }

    void river(int row, double dir, double sp, List<double> lens, bool dive) {
      final l = HopperLane(row, dir, sp * m, true, dive);
      final gap = hopperCols / lens.length;
      for (var i = 0; i < lens.length; i++) {
        l.items.add(LaneItem(i * gap, lens[i]));
      }
      lanes.add(l);
    }

    road(11, 1, 2.2, rush ? [1, 1, 1, 1] : [1, 1, 1]);
    road(10, -1, 3.0, [1, 1, 2]);
    road(9, 1, 3.8, rush ? [1, 1, 1, 1] : [1, 1, 1]);
    road(8, -1, 2.6, [2, 2]);
    road(7, 1, 4.4, [1, 1]);
    river(5, -1, 1.6, [4, 4], false);
    river(4, 1, 2.2, [2, 2, 2], true);
    river(3, -1, 2.8, [3, 3], rush); // Rush Hour adds diving turtles here
    river(2, 1, 2.0, [4, 4], false);
    river(1, -1, 3.4, [2, 2], true);
  }

  // ------------------------------------------------------------- phase api
  void _armPhase(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _phaseFn = fn;
    _phaseRemaining = d.inMicroseconds / 1e6;
    _runPhase(d, fn);
  }

  void _runPhase(Duration d, void Function() fn) {
    _phaseTimer?.cancel();
    _phaseDeadline = DateTime.now().add(d);
    _phaseTimer = Timer(d, () {
      _phaseTimer = null;
      _phaseDeadline = null;
      _phaseFn = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze the phase timer (not cancel into oblivion) AND the
  /// simulation loop. Resume re-arms the frozen phase from exactly where it
  /// left off (RULES §12) — never a stuck state, never a skipped beat.
  void setPaused(bool v) {
    if (paused == v || _disposed || over) return;
    paused = v;
    if (v) {
      final dl = _phaseDeadline;
      if (_phaseTimer != null && dl != null) {
        _phaseRemaining = max(
                0.0, dl.difference(DateTime.now()).inMicroseconds / 1e6)
            .toDouble();
        _phaseTimer!.cancel();
        _phaseTimer = null;
        _phaseDeadline = null;
      }
    } else {
      final fn = _phaseFn;
      if (fn != null && _phaseTimer == null) {
        final wait = Duration(
            microseconds: max(1, (_phaseRemaining * 1e6).round()).toInt());
        _runPhase(wait, fn);
      }
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: if any phase is ever found without its timer, recover it.
  /// Makes stuck states impossible by construction. Respects [paused].
  void _recover() {
    if (_disposed || paused || over) return;
    if (phase == HopperPhase.ready && _phaseTimer == null) {
      phase = HopperPhase.playing;
    } else if (phase == HopperPhase.dying && _phaseTimer == null) {
      _afterDeath();
    } else if (phase == HopperPhase.celebrating && _phaseTimer == null) {
      _afterCelebrate();
    }
    if (_updateTimer == null) {
      _updateTimer =
          Timer.periodic(const Duration(milliseconds: 16), (_) => _update(0.016));
    }
    // Invariant repairs.
    if (lives <= 0 && !scoreAttack && phase != HopperPhase.gameOver) {
      _gameOver();
    }
    if (row < 0 || row > hopperRows - 1 || fx.isNaN) {
      fx = 6;
      row = 12;
      hopT = 1;
    }
    notifyListeners();
  }

  /// Full restart of the run (same difficulty/mode).
  /// Full restart of the run (same difficulty/mode). Also clears pause so a
  /// restart from the pause overlay always lands on a live run.
  void restart() {
    paused = false;
    _phaseTimer?.cancel();
    _phaseTimer = null;
    _phaseDeadline = null;
    _phaseFn = null;
    _phaseRemaining = 0;
    score = 0;
    lives = 3;
    level = 1;
    timeLeft = timeMax;
    attackClock = 90;
    homes.clear();
    particles.clear();
    floaters.clear();
    hops = 0;
    homesClaimed = 0;
    levelsCleared = 0;
    deathCause = null;
    shakeT = 0;
    _respawn(fresh: true);
    _buildLanes();
    phase = HopperPhase.ready;
    banner = 'Hop to it!';
    bannerT = 2.0;
    _armPhase(const Duration(milliseconds: 900), () {
      if (phase == HopperPhase.ready) {
        phase = HopperPhase.playing;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  // ---------------------------------------------------------------- input
  /// Attempt a hop. Illegal hops (edge bump, wrong phase, cooldown) are
  /// rejected with feedback — never silent, never a stuck state.
  void hop(int dx, int dy) {
    if (paused || phase != HopperPhase.playing || _disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastHop).inMilliseconds < 120) return;
    _lastHop = now;
    final nx = (fx.round() + dx).clamp(0, hopperCols - 1).toInt();
    final ny = (row + dy).clamp(0, hopperRows - 1).toInt();
    if (nx == fx.round() && ny == row) {
      _emit(HopperEvent.invalid); // bumped the board edge
      return;
    }
    fromX = fx;
    fromRow = row;
    fx = nx.toDouble();
    row = ny;
    hopT = 0;
    hops++;
    _dust(nx.toDouble(), ny.toDouble());
    if (dy < 0) {
      score += 10;
      _floater(nx.toDouble(), ny.toDouble(), '+10', 0xFFFFD43B);
    }
    _emit(HopperEvent.hop);
    if (row == 0) _reachHome();
    notifyListeners();
  }

  void _reachHome() {
    final c = fx.round();
    if (homeCols.contains(c) && !homes.contains(c)) {
      homes.add(c);
      homesClaimed++;
      var gained = 200;
      if (!scoreAttack && !endless) {
        gained += (timeLeft * 10).round(); // RULES §7 time bonus
      }
      score += gained;
      _floater(fx, 0, '+$gained', 0xFFFFD43B);
      _sparkle(fx, 0);
      _emit(HopperEvent.home);
      phase = HopperPhase.celebrating;
      banner = 'Home sweet home!';
      bannerT = 1.6;
      _armPhase(const Duration(milliseconds: 950), _afterCelebrate);
    } else {
      _die(DeathCause.noHome, 'No home there!');
    }
    notifyListeners();
  }

  void _afterCelebrate() {
    if (_disposed || paused) return;
    if (endless) {
      // RULES §7: every claimed home refills the slots and speeds the lanes.
      homes.clear();
      level++;
      _buildLanes();
      _emit(HopperEvent.levelUp);
      banner = 'Faster now — keep hopping!';
      bannerT = 2.0;
    } else if (homes.length == homeCols.length) {
      if (!scoreAttack) {
        // Classic level clear: +1000, homes reset, lanes speed up.
        homes.clear();
        level++;
        levelsCleared++;
        score += 1000;
        _emit(HopperEvent.levelUp);
        banner = 'LEVEL $level — 1000 bonus!';
        bannerT = 2.5;
        _buildLanes();
      }
      // Score Attack: homes stay claimed; filled slots stay risky
      // (RULES §7 "Blocked home").
    }
    _respawn();
    if (scoreAttack && attackClock <= 0) {
      _gameOver(); // clock ran out mid-celebration (RULES §12)
      return;
    }
    phase = HopperPhase.playing;
    notifyListeners();
  }

  // ---------------------------------------------------------------- death
  void _die(DeathCause cause, String msg) {
    if (phase != HopperPhase.playing || _disposed) return;
    phase = HopperPhase.dying;
    deathCause = cause;
    deathMsg = msg;
    shakeT = cause == DeathCause.squashed ? 0.4 : 0.2;
    banner = msg;
    bannerT = 1.8;
    switch (cause) {
      case DeathCause.squashed:
        _emit(HopperEvent.squishDeath);
        _burst(fx, row.toDouble(), 0xFFE05252, 14);
        break;
      case DeathCause.drowned:
      case DeathCause.dove:
        _emit(HopperEvent.splashDeath);
        _burst(fx, row.toDouble(), 0xFF4DD0E1, 16);
        break;
      case DeathCause.sweptAway:
        _emit(HopperEvent.splashDeath);
        break;
      case DeathCause.timeUp:
      case DeathCause.noHome:
        _emit(HopperEvent.invalid);
        _burst(fx, row.toDouble(), 0xFFFFD43B, 8);
        break;
    }
    _armPhase(const Duration(milliseconds: 1000), _afterDeath);
    notifyListeners();
  }

  void _afterDeath() {
    if (_disposed || paused) return;
    if (scoreAttack) {
      score = max(0, score - 25).toInt(); // RULES §8: deaths cost points, no lives
      _respawn();
      phase = HopperPhase.playing;
    } else {
      lives--;
      if (lives <= 0) {
        _gameOver();
        return;
      }
      _respawn();
      phase = HopperPhase.playing;
    }
    notifyListeners();
  }

  void _respawn({bool fresh = false}) {
    fx = 6;
    row = 12;
    fromX = 6;
    fromRow = 12;
    hopT = 1;
    deathCause = null;
    if (!scoreAttack) timeLeft = timeMax;
    if (fresh) {
      banner = '';
      bannerT = 0;
    }
  }

  void _gameOver() {
    phase = HopperPhase.gameOver;
    _phaseTimer?.cancel();
    _phaseTimer = null;
    _phaseDeadline = null;
    _phaseFn = null;
    _emit(HopperEvent.lose);
    notifyListeners();
  }

  // ------------------------------------------------------------- simulation
  bool get _onRiver => row >= 1 && row <= 5;
  bool get _onRoad => row >= 7 && row <= 11;

  HopperLane _laneOf(int r) => lanes.firstWhere((l) => l.row == r);

  void _update(double dt) {
    if (_disposed || paused || over) return;
    time += dt;
    hopT = min(1.0, hopT + dt * 7).toDouble();
    bannerT = max(0.0, bannerT - dt).toDouble();
    shakeT = max(0.0, shakeT - dt).toDouble();
    _updateParticles(dt);
    _updateFloaters(dt);

    final divePeriod = this.divePeriod;
    for (final l in lanes) {
      for (final it in l.items) {
        it.x += l.dir * l.speed * dt;
        if (l.dir > 0 && it.x > hopperCols) it.x -= hopperCols + it.len;
        if (l.dir < 0 && it.x + it.len < 0) it.x += hopperCols + it.len;
      }
      if (l.dive) l.diveT = (l.diveT + dt) % divePeriod;
    }

    if (phase != HopperPhase.playing) {
      notifyListeners(); // keep particles/floaters animating through transitions
      return;
    }

    // Ride platforms.
    if (_onRiver) {
      final l = _laneOf(row);
      final plat = _platformUnder(l);
      final diving = l.dive && l.diveT > divePeriod - diveSubmergeSecs;
      if (plat == null) {
        _die(DeathCause.drowned, 'Splash!');
        return;
      }
      if (diving) {
        _die(DeathCause.dove, 'The turtle dove!');
        return;
      }
      fx += l.dir * l.speed * dt;
      if (fx < -0.6 || fx > hopperCols - 0.4) {
        _die(DeathCause.sweptAway, 'Swept away!');
        return;
      }
    }

    // Car collisions.
    if (_onRoad) {
      final l = _laneOf(row);
      for (final it in l.items) {
        if (fx > it.x - 0.32 && fx < it.x + it.len + 0.32) {
          _die(DeathCause.squashed, 'Squashed!');
          return;
        }
      }
    }

    // Clocks.
    if (scoreAttack) {
      attackClock -= dt;
      final s = attackClock.ceil();
      if (attackClock <= 10.5 && s != _lastTickSecond) {
        _lastTickSecond = s;
        _emit(HopperEvent.tick);
      }
      if (attackClock <= 0) {
        attackClock = 0;
        _emit(HopperEvent.win);
        _gameOver();
        return;
      }
    } else if (!endless) {
      timeLeft -= dt;
      final s = timeLeft.ceil();
      if (timeLeft <= 10.5 && s != _lastTickSecond) {
        _lastTickSecond = s;
        _emit(HopperEvent.tick);
      }
      if (timeLeft <= 0) {
        timeLeft = 0;
        _die(DeathCause.timeUp, 'Out of time!');
        return;
      }
    }
    notifyListeners();
  }

  LaneItem? _platformUnder(HopperLane l) {
    for (final it in l.items) {
      if (fx >= it.x - 0.1 && fx <= it.x + it.len + 0.1) return it;
    }
    return null;
  }

  // ----------------------------------------------------------------- juice
  void _emit(HopperEvent e) {
    try {
      onEvent?.call(e);
    } catch (_) {}
  }

  void _burst(double x, double y, int color, int n) {
    for (int i = 0; i < n; i++) {
      final a = _rand.nextDouble() * 2 * pi;
      final sp = 1.5 + _rand.nextDouble() * 4;
      particles.add(Particle(
        x + 0.5,
        y + 0.5,
        cos(a) * sp,
        sin(a) * sp - 2,
        0.5 + _rand.nextDouble() * 0.4,
        color,
        3 + _rand.nextDouble() * 4,
      ));
    }
  }

  void _dust(double x, double y) {
    for (int i = 0; i < 5; i++) {
      final a = pi + (_rand.nextDouble() - 0.5) * 1.2;
      particles.add(Particle(
        x + 0.5,
        y + 0.8,
        cos(a) * 1.2,
        sin(a) * 1.2,
        0.35,
        0xAAFFFFFF,
        2.5,
      ));
    }
  }

  void _sparkle(double x, double y) {
    for (int i = 0; i < 18; i++) {
      final a = _rand.nextDouble() * 2 * pi;
      final sp = 1 + _rand.nextDouble() * 3;
      particles.add(Particle(
        x + 0.5,
        y + 0.5,
        cos(a) * sp,
        sin(a) * sp - 1.5,
        0.7 + _rand.nextDouble() * 0.4,
        0xFFFFD43B,
        3 + _rand.nextDouble() * 3,
      ));
    }
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 9 * dt; // gravity
    }
    particles.removeWhere((p) => p.life <= 0);
  }

  void _floater(double x, double y, String text, int color) {
    floaters.add(Floater(x + 0.5, y + 0.2, text, color));
  }

  void _updateFloaters(double dt) {
    for (final f in floaters) {
      f.life -= dt;
      f.y -= dt * 1.2;
    }
    floaters.removeWhere((f) => f.life <= 0);
  }
}
